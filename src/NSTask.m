#import <Foundation/NSTask.h>
#import <Foundation/NSException.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSMutableDictionary.h>
#import <Foundation/NSMutableArray.h>
#import <Foundation/NSError.h>
#import <Foundation/NSPipe.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/FoundationErrors.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSNotificationCenter.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSProcessInfo.h>

#import <CoreFoundation/CFRunLoop.h>

#import <dispatch/dispatch.h>

#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/wait.h>
#include <signal.h>
#include <os/log.h>
#include <pthread/private.h>

#import "NSObjectInternal.h"

extern char*** _NSGetEnviron();

const NSNotificationName NSTaskDidTerminateNotification = @"NSTaskDidTerminateNotification";

static NSString* const kArgs = @"_NSTaskArgumentArray";
static NSString* const kCWD = @"_NSTaskDirectoryPath";
static NSString* const kEnv = @"_NSTaskEnvironmentDictionary";
static NSString* const kExec = @"_NSTaskExecutablePath";
static NSString* const kArchs = @"_NSTaskPreferredArchitectureArray";
static NSString* const kNoProcGroup = @"_NSTaskNoNewProcessGroup";
static NSString* const kStderr = @"_NSTaskDiagnosticFileHandle";
static NSString* const kStdin = @"_NSTaskInputFileHandle";
static NSString* const kStdout = @"_NSTaskOutputFileHandle";
static NSString* const kErrs = @"_NSTaskUseErrorsForRuntimeFailures";

// performs a shallow copy (i.e. duplicates only the array, not the strings).
// if length == SIZE_MAX, the array must have NULL as its last member (and the length will be automatically determined)
static const char** dupStringArray(const char** array, size_t length) {
	const char** result = NULL;

	if (length == SIZE_MAX) {
		length = 0;
		for (const char** ptr = array; *ptr != NULL; ++ptr) {
			++length;
		}
	}

	result = malloc(sizeof(const char*) * (length + 1));
	for (size_t i = 0; i < length; ++i) {
		result[i] = array[i];
	}
	result[length] = NULL;

	return result;
};

static os_log_t nstask_get_log(void) {
	static os_log_t logger = NULL;
	static dispatch_once_t token;
	dispatch_once(&token, ^{
		logger = os_log_create("org.darlinghq.Foundation", "NSTask");
	});
	return logger;
};

@interface NSConcreteTask : NSTask {
	NSMutableDictionary* _launchInfo;
	pid_t _pid;
	NSQualityOfService _qos;
	void (^_terminationHandler)(NSTask*);
	NSTaskTerminationReason _reason;
	int _code;
	NSInteger _suspensionCount;
	BOOL _launched;
	dispatch_source_t _monitor;
	CFRunLoopSourceRef _waiter;
	NSMutableArray* _waitingLoops;
}

@property NSQualityOfService qualityOfService;

@end

@implementation NSConcreteTask

- (void)dealloc
{
	[_launchInfo release];
	[_terminationHandler release];
	[_monitor release];
	if (_waiter != NULL) {
		CFRelease(_waiter);
	}
	[_waitingLoops release];
	[super dealloc];
}

- (id)_getInfoForKey: (NSString*)key
{
	@synchronized(self) {
		return [_launchInfo[key] copy];
	}
}

- (void)_setInfo: (id)info forKey: (NSString*)key copy: (BOOL)copy
{
	@synchronized(self) {
		if (_launched) {
			return;
		}
		if (copy) {
			info = [info copy];
		}
		_launchInfo[key] = info;
	}
}

- (NSArray<NSString*>*)arguments
{
	return [self _getInfoForKey: kArgs];
}

- (void)setArguments: (NSArray<NSString*>*)arguments
{
	[self _setInfo: arguments forKey: kArgs copy: YES];
}

- (NSDictionary<NSString*, NSString*>*)environment
{
	return [self _getInfoForKey: kEnv];
}

- (void)setEnvironment: (NSDictionary<NSString*, NSString*>*)environment
{
	[self _setInfo: environment forKey: kEnv copy: YES];
}

- (NSString*)currentDirectoryPath
{
	return [self _getInfoForKey: kCWD];
}

- (void)setCurrentDirectoryPath: (NSString*)currentDirectoryPath
{
	[self _setInfo: currentDirectoryPath forKey: kCWD copy: YES];
}

- (id)standardInput
{
	return [self _getInfoForKey: kStdin];
}

- (void)setStandardInput: (id)standardInput
{
	[self _setInfo: standardInput forKey: kStdin copy: NO];
}

- (id)standardOutput
{
	return [self _getInfoForKey: kStdout];
}

- (void)setStandardOutput: (id)standardOutput
{
	[self _setInfo: standardOutput forKey: kStdout copy: NO];
}

- (id)standardError
{
	return [self _getInfoForKey: kStderr];
}

- (void)setStandardError: (id)standardError
{
	[self _setInfo: standardError forKey: kStderr copy: NO];
}

- (pid_t)processIdentifier
{
	@synchronized(self) {
		return _pid;
	}
}

- (BOOL)isRunning
{
	@synchronized(self) {
		return _pid != -1 && _reason == 0;
	}
}

- (int)terminationStatus
{
	@synchronized(self) {
		return _code;
	}
}

- (NSTaskTerminationReason)terminationReason
{
	@synchronized(self) {
		return _reason;
	}
}

- (void(^)(NSTask*))terminationHandler
{
	return [[_terminationHandler retain] autorelease];
}

- (void)setTerminationHandler: (void(^)(NSTask*))terminationHandler
{
	void (^oldHandler)(NSTask*) = _terminationHandler;
	_terminationHandler = [terminationHandler copy];
	[oldHandler release];
}

- (NSQualityOfService)qualityOfService
{
	@synchronized(self) {
		return _qos;
	}
}

- (void)setQualityOfService: (NSQualityOfService)qualityOfService
{
	@synchronized(self) {
		if (_launched) {
			return;
		}
		_qos = qualityOfService;
	}
}

- (NSString*)launchPath
{
	return [self _getInfoForKey: kExec];
}

- (void)setLaunchPath: (NSString*)launchPath
{
	[self _setInfo: launchPath forKey: kExec copy: YES];
}

- (BOOL)startsNewProcessGroup
{
	return ![self _getInfoForKey: kNoProcGroup];
}

- (void)setStartsNewProcessGroup: (BOOL)startsNewProcessGroup
{
	[self _setInfo: [NSNumber numberWithBool: !startsNewProcessGroup] forKey: kNoProcGroup copy: YES];
}

- (instancetype)init
{
	if (self = [super init]) {
		_pid = -1;
		_code = -1;
		_launchInfo = [NSMutableDictionary new];
		_waitingLoops = [NSMutableArray new];
	}
	return self;
}

- (void)interrupt
{
	@synchronized(self) {
		if (!self.isRunning) {
			return;
		}
		kill(_pid, SIGINT);
	}
}

- (void)terminate
{
	@synchronized(self) {
		if (!self.isRunning) {
			return;
		}
		kill(_pid, SIGTERM);
	}
}

- (BOOL)suspend
{
	@synchronized(self) {
		if (!self.isRunning || _suspensionCount > 0) {
			return NO;
		}
		if (kill(_pid, SIGSTOP) == 0) {
			++_suspensionCount;
			return YES;
		}
		return NO;
	}
}

- (BOOL)resume
{
	@synchronized(self) {
		if (_suspensionCount < 0) {

		}
		if (!self.isRunning || _suspensionCount == 0) {
			return NO;
		}
		if (kill(_pid, SIGCONT) == 0) {
			--_suspensionCount;
			return YES;
		}
		return NO;
	}
}

- (void)waitUntilExit
{
	@synchronized(self) {
		// if reason is not 0, the task has already exited
		if (_reason != 0) {
			return;
		}

		// if PID is -1, the task has not been launched yet
		if (_pid == -1) {
			[NSException raise: NSInvalidArgumentException format: @"Task has not been launched"];
		}

		CFRunLoopRef runloop = CFRunLoopGetCurrent();
		CFRunLoopAddSource(runloop, _waiter, kCFRunLoopDefaultMode);
		[_waitingLoops addObject: (id)runloop];

		os_log_debug(nstask_get_log(), "going to wait for PID %d with runloop %@", _pid, (id)runloop);
	}

	// the waiter will stop us when ready
	CFRunLoopRun();
}

static void waiterCallback(void* info) {
	// we don't really have anything to do here
	// (in fact, this should never be called)
	os_log_info(nstask_get_log(), "CFRunLoopSource waiter callback fired (this should never happen)");
};

- (BOOL)launchWithDictionary: (NSDictionary*)info error: (NSError**)outError
{
	@synchronized(self) {
		NSMutableDictionary* oldInfo = nil;
		BOOL useErrors = ((NSNumber*)info[kErrs]).boolValue;
		NSString* execPath = nil;
		NSString* cwd = nil;
		NSArray<NSString*>* args = nil;
		NSDictionary<NSString*, NSString*>* env = nil;
		NSFileHandle* stdin = nil;
		NSFileHandle* stdout = nil;
		NSFileHandle* stderr = nil;
		BOOL setProcessGroup = YES;

		const char** cArgs = NULL;
		const char** cEnv = NULL;
		int cStdin = -1;
		int cStdout = -1;
		int cStderr = -1;
		int previousCWD = -1;

		posix_spawn_file_actions_t actions;
		posix_spawnattr_t attrs;
		sigset_t sigmask;

		BOOL spawned = NO;
		int savedErrno = 0;

		CFRunLoopSourceContext waiterContext = {0};

		if (_launched) {
			if (useErrors) {
				if (outError) {
					*outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSExecutableLoadError userInfo: nil];
				}
			} else {
				[NSException raise: NSInvalidArgumentException format: @"Task already launched"];
			}
			return NO;
		}
		_launched = YES;

		// replace the stored launch info with the info that's actually going to be used
		oldInfo = _launchInfo;
		_launchInfo = [info mutableCopy];
		[oldInfo release];

		execPath = ((NSString*)info[kExec]).stringByStandardizingPath;
		cwd = ((NSString*)info[kCWD]).stringByStandardizingPath;
		args = info[kArgs];
		env = info[kEnv];
		stdin = info[kStdin];
		stdout = info[kStdout];
		stderr = info[kStderr];
		setProcessGroup = !((NSNumber*)info[kNoProcGroup]).boolValue;

		if ([stdin isKindOfClass: [NSPipe class]]) {
			stdin = [(NSPipe*)stdin fileHandleForReading];
		}

		if ([stdout isKindOfClass: [NSPipe class]]) {
			stdout = [(NSPipe*)stdout fileHandleForWriting];
		}

		if ([stderr isKindOfClass: [NSPipe class]]) {
			stderr = [(NSPipe*)stderr fileHandleForWriting];
		}

		// make sure the executable can actually be executed
		if (![[NSFileManager defaultManager] isExecutableFileAtPath: execPath]) {
			if (useErrors) {
				if (outError) {
					NSDictionary* info = nil;
					if (execPath) {
						info = @{
							NSFilePathErrorKey: execPath,
						};
					}
					*outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileNoSuchFileError userInfo: info];
				}
			} else {
				[NSException raise: NSInvalidArgumentException format: @"Executable path cannot be executed (permissions/existence error)"];
			}
			return NO;
		}

		// also make sure the working directory exists (if given)
		if (cwd && ![[NSFileManager defaultManager] fileExistsAtPath: cwd]) {
			if (useErrors) {
				if (outError) {
					*outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileNoSuchFileError userInfo: @{
						NSFilePathErrorKey: cwd,
					}];
				}
			} else {
				[NSException raise: NSInvalidArgumentException format: @"Working directory cannot be accessed (permissions/existence error)"];
			}
			return NO;
		}

		// make sure these are file handles (or pipes, which we already converted before)
		if ((stdin && ![stdin isKindOfClass: [NSFileHandle class]]) || (stdout && ![stdout isKindOfClass: [NSFileHandle class]]) || (stderr && ![stderr isKindOfClass: [NSFileHandle class]])) {
			if (useErrors) {
				if (outError) {
					// this is probably the wrong error code
					*outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSFileNoSuchFileError userInfo: nil];
				}
			} else {
				[NSException raise: NSInvalidArgumentException format: @"One or more of stdin, stdout, or stderr was not a file handle or pipe"];
			}
			return NO;
		}

		// convert the arguments into something posix_spawn likes
		if (args) {
			cArgs = malloc(sizeof(const char*) * (args.count + 2));
			size_t index = 1;
			for (NSString* arg in args) {
				// NOTE: this assumes that the string will live long enough for posix_spawn to see it.
				cArgs[index++] = arg.fileSystemRepresentation;
			}
			cArgs[index] = NULL;
		} else {
			cArgs = malloc(sizeof(const char*) * 2);
			cArgs[1] = NULL;
		}
		cArgs[0] = execPath.fileSystemRepresentation;

		// FOR DEBUGGING ONLY
#if 0
		{
			NSMutableDictionary* tmp = [NSProcessInfo processInfo].environment.mutableCopy;
			tmp[@"DYLD_INSERT_LIBRARIES"] = @"/usr/lib/darling/libxtrace.dylib";
			tmp[@"XTRACE_KPRINTF"] = @"1";
			env = tmp;
		}
#endif

		if (env) {
			cEnv = malloc(sizeof(const char*) * (env.count + 1));
			size_t index = 0;
			for (NSString* key in env) {
				// ditto
				cEnv[index++] = [NSString stringWithFormat: @"%@=%@", key, env[key]].fileSystemRepresentation;
			}
			cEnv[index] = NULL;
		} else {
			cEnv = dupStringArray(*_NSGetEnviron(), SIZE_MAX);
		}

		if (stdin) {
			cStdin = stdin.fileDescriptor;
			os_log_debug(nstask_get_log(), "using %d for stdin", cStdin);
		}

		if (stdout) {
			cStdout = stdout.fileDescriptor;
			os_log_debug(nstask_get_log(), "using %d for stdout", cStdout);
		}

		if (stderr) {
			cStderr = stderr.fileDescriptor;
			os_log_debug(nstask_get_log(), "using %d for stderr", cStderr);
		}

		// set everything up to spawn the process

		// FIXME: this part needs more error handling

		posix_spawn_file_actions_init(&actions);

		if (cStdin != -1) {
			posix_spawn_file_actions_addclose(&actions, 0);
			posix_spawn_file_actions_adddup2(&actions, cStdin, 0);
		}

		if (cStdout != -1) {
			posix_spawn_file_actions_addclose(&actions, 1);
			posix_spawn_file_actions_adddup2(&actions, cStdout, 1);
		}

		if (cStderr != -1) {
			posix_spawn_file_actions_addclose(&actions, 2);
			posix_spawn_file_actions_adddup2(&actions, cStderr, 2);
		}

		if (cwd) {
			posix_spawn_file_actions_addchdir_np(&actions, cwd.fileSystemRepresentation);
		}

		posix_spawnattr_init(&attrs);

		sigemptyset(&sigmask);
		posix_spawnattr_setsigmask(&attrs, &sigmask);

		sigfillset(&sigmask);
		posix_spawnattr_setsigdefault(&attrs, &sigmask);

		posix_spawnattr_setpgroup(&attrs, 0);

		posix_spawnattr_setflags(&attrs, POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF | (setProcessGroup ? POSIX_SPAWN_SETPGROUP : 0));

		os_log_debug(nstask_get_log(), "going to spawn process %s", cArgs[0]);

		// alright, it's finally time to start the process
		spawned = posix_spawn(&_pid, cArgs[0], &actions, &attrs, cArgs, cEnv) == 0;
		savedErrno = errno;

		// do some cleanup regardless of whether we failed or not
		[stdin closeFile];
		[stdout closeFile];
		[stderr closeFile];

		posix_spawn_file_actions_destroy(&actions);
		posix_spawnattr_destroy(&attrs);

		free(cArgs);
		free(cEnv);

		// report failure
		if (!spawned) {
			if (useErrors) {
				if (outError) {
					*outError = [NSError errorWithDomain: NSPOSIXErrorDomain code: savedErrno userInfo: nil];
				}
			} else {
				[NSException raise: NSInternalInconsistencyException format: @"Failed to spawn process"];
			}
			return NO;
		}

		// otherwise, everything's good and we need to setup a monitor and a waiter for the process

		os_log_debug(nstask_get_log(), "process successfully spawned with PID %d", _pid);

		// the waiter is used to allow users to wait for the process to exit.
		// it's just a dummy source to force the run loop to go to sleep if it has nothing else to do
		waiterContext.info = nil;
		waiterContext.perform = waiterCallback;
		_waiter = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &waiterContext);

		// the monitor is used to actually monitor the state of the process and get notified by the system when it exits
		_monitor = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, _pid, DISPATCH_PROC_EXIT, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0));

		dispatch_source_set_event_handler(_monitor, ^{
			int status = 0;

			os_log_debug(nstask_get_log(), "libdispatch reported that process with PID %d died", _pid);

			waitpid(_pid, &status, 0);

			@synchronized(self) {
				_code = WEXITSTATUS(status);
				_reason = WIFSIGNALED(status) ? NSTaskTerminationReasonUncaughtSignal : NSTaskTerminationReasonExit;

				// if we have a termination handler, call it
				if (_terminationHandler) {
					dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
						os_log_debug(nstask_get_log(), "calling out to termination handler");
						_terminationHandler(self);
					});
				} else {
					// otherwise, post a notification
					os_log_debug(nstask_get_log(), "posting notification to default notification center");
					[[NSNotificationCenter defaultCenter] postNotificationName: NSTaskDidTerminateNotification object: self];
				}

				// stop everyone that was waiting
				for (id runloop in _waitingLoops) {
					os_log_debug(nstask_get_log(), "waking up/stopping runloop %@", runloop);
					CFRunLoopRemoveSource((CFRunLoopRef)runloop, _waiter, kCFRunLoopDefaultMode);
					CFRunLoopWakeUp((CFRunLoopRef)runloop);
					CFRunLoopStop((CFRunLoopRef)runloop);
				}
				[_waitingLoops removeAllObjects];

				CFRunLoopSourceInvalidate(_waiter);
				dispatch_source_cancel(_monitor);
			}
		});

		dispatch_resume(_monitor);

		return YES;
	}
}

- (BOOL)launchAndReturnError:(out NSError**)error
{
	@synchronized(self) {
		NSMutableDictionary* dict = [_launchInfo mutableCopy];
		dict[kErrs] = [NSNumber numberWithBool: YES];
		return [self launchWithDictionary: dict error: error];
	}
}

- (void)launch
{
	@synchronized(self) {
		[self launchWithDictionary: [_launchInfo copy] error: nil];
	}
}

@end

@implementation NSTask

+ (id)allocWithZone:(NSZone *)zone
{
	Class class = [self class];
	if (class == [NSTask class]) {
		class = [NSConcreteTask class];
	}
	return NSAllocateObject(class, 0, zone);
}

+ (NSTask*)launchedTaskWithExecutableURL: (NSURL*)executableURL arguments: (NSArray<NSString*>*)arguments error: (out NSError**)error terminationHandler: (void (^)(NSTask*))terminationHandler
{
	NSTask* task = [[[NSTask alloc] init] autorelease];

	task.executableURL = executableURL;
	task.arguments = arguments;
	task.terminationHandler = terminationHandler;

	if (![task launchAndReturnError: error]) {
		task = nil;
	}

	return task;
}

+ (NSTask*)launchedTaskWithLaunchPath: (NSString*)launchPath arguments: (NSArray<NSString*>*)arguments
{
	NSTask* task = [[[NSTask alloc] init] autorelease];

	task.launchPath = launchPath;
	task.arguments = arguments;

	[task launch];

	return task;
}

- (instancetype)init
{
	return [super init];
}

- (BOOL)launchAndReturnError: (out NSError**)error
{
	NSRequestConcreteImplementation();
	return NO;
}

- (void)interrupt
{
	NSRequestConcreteImplementation();
}

- (void)terminate
{
	NSRequestConcreteImplementation();
}

- (BOOL)suspend
{
	NSRequestConcreteImplementation();
	return NO;
}

- (BOOL)resume
{
	NSRequestConcreteImplementation();
	return NO;
}

- (void)waitUntilExit
{
	NSRequestConcreteImplementation();
}

- (void)launch
{
	NSRequestConcreteImplementation();
}

- (NSURL*)executableURL
{
	return [NSURL fileURLWithPath: self.launchPath isDirectory: NO];
}

- (void)setExecutableURL: (NSURL*)executableURL
{
	if (!executableURL.isFileURL) {
		[NSException raise: NSInvalidArgumentException format: @"URL (%@) was not a file URL", executableURL];
	}
	self.launchPath = executableURL.standardizedURL.path;
}

- (NSArray<NSString*>*)arguments
{
	NSRequestConcreteImplementation();
	return nil;
}

- (void)setArguments: (NSArray<NSString*>*)arguments
{
	NSRequestConcreteImplementation();
}

- (NSDictionary<NSString*, NSString*>*)environment
{
	NSRequestConcreteImplementation();
	return nil;
}

- (void)setEnvironment: (NSDictionary<NSString*, NSString*>*)environment
{
	NSRequestConcreteImplementation();
}

- (NSString*)currentDirectoryPath
{
	NSRequestConcreteImplementation();
	return nil;
}

- (void)setCurrentDirectoryPath: (NSString*)currentDirectoryPath
{
	NSRequestConcreteImplementation();
}

- (NSURL*)currentDirectoryURL
{
	return [NSURL fileURLWithPath: self.currentDirectoryPath isDirectory: YES];
}

- (void)setCurrentDirectoryURL: (NSURL*)currentDirectoryURL
{
	if (!currentDirectoryURL.isFileURL) {
		[NSException raise: NSInvalidArgumentException format: @"URL (%@) was not a file URL", currentDirectoryURL];
	}
	self.currentDirectoryPath = currentDirectoryURL.standardizedURL.path;
}

- (id)standardInput
{
	NSRequestConcreteImplementation();
	return nil;
}

- (void)setStandardInput: (id)standardInput
{
	NSRequestConcreteImplementation();
}

- (id)standardOutput
{
	NSRequestConcreteImplementation();
	return nil;
}

- (void)setStandardOutput: (id)standardOutput
{
	NSRequestConcreteImplementation();
}

- (id)standardError
{
	NSRequestConcreteImplementation();
	return nil;
}

- (void)setStandardError: (id)standardError
{
	NSRequestConcreteImplementation();
}

- (pid_t)processIdentifier
{
	NSRequestConcreteImplementation();
	return -1;
}

- (BOOL)isRunning
{
	NSRequestConcreteImplementation();
	return NO;
}

- (int)terminationStatus
{
	NSRequestConcreteImplementation();
	return -1;
}

- (NSTaskTerminationReason)terminationReason
{
	NSRequestConcreteImplementation();
	return 0;
}

- (void(^)(NSTask*))terminationHandler
{
	NSRequestConcreteImplementation();
	return nil;
}

- (void)setTerminationHandler: (void(^)(NSTask*))terminationHandler
{
	NSRequestConcreteImplementation();
}

- (NSQualityOfService)qualityOfService
{
	NSRequestConcreteImplementation();
	return NSQualityOfServiceDefault;
}

- (void)setQualityOfService: (NSQualityOfService)qualityOfService
{
	NSRequestConcreteImplementation();
}

- (NSString*)launchPath
{
	NSRequestConcreteImplementation();
	return nil;
}

- (void)setLaunchPath: (NSString*)launchPath
{
	NSRequestConcreteImplementation();
}

@end
