#import <Foundation/NSTask.h>
#import <Foundation/NSException.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/wait.h>

const NSNotificationName NSTaskDidTerminateNotification = @"NSTaskDidTerminateNotification";

@implementation NSTask

@synthesize executableURL = _executableURL;
@synthesize arguments = _arguments;
@synthesize environment = _environment;
@synthesize currentDirectoryURL = _currentDirectoryURL;
@synthesize standardInput = _standardInput;
@synthesize standardOutput = _standardOutput;
@synthesize standardError = _standardError;
@synthesize processIdentifier = _processIdentifier;
@synthesize running = _running;
@synthesize terminationStatus = _terminationStatus;
@synthesize terminationReason = _terminationReason;
@synthesize terminationHandler = _terminationHandler;
@synthesize qualityOfService = _qualityOfService;
@synthesize launchPath = _launchPath;
@synthesize currentDirectoryPath = _currentDirectoryPath;

- (instancetype)init
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return [super init];
}

- (BOOL)launchAndReturnError:(out NSError **_Nullable)error
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return NO;
}

- (void)interrupt
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
}

- (void)terminate
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
}

- (BOOL)suspend
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return NO;
}

- (BOOL)resume
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return NO;
}

+ (nullable NSTask *)launchedTaskWithExecutableURL:(NSURL *)url
	arguments:(NSArray<NSString *> *)arguments
	error:(out NSError ** _Nullable)error
	terminationHandler:(void (^_Nullable)(NSTask *))terminationHandler
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return nil;
}

- (void)waitUntilExit
{
	int status;
	printf("waitUntilExit called\n");
	wait(&status);
	if (WIFEXITED(status))
	{
		_terminationStatus = WEXITSTATUS(status);
	}
}

- (void)launch
{
	int i;
	char *path;
	char **to_free, **print_next, **argv;
	pid_t pid;
	NSException *argumentInvalid = [NSException
		exceptionWithName: @"NSInvalidArgumentException"
			   reason: @"need a dictionary"
			 userInfo: nil];

	if ([self launchPath] == nil)
	{
		@throw argumentInvalid;
	}

	/* Create a char* array for exec */
	// FIXME: The argv doesn't have the file name as argv[0], it’s missing.
	argv = calloc([[self arguments] count] + 1, sizeof(char*));
	for (i = 0; i < [[self arguments] count]; i++)
	{
		argv[i] = malloc([[[self arguments] objectAtIndex: i] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
		strcpy(argv[i], [[[self arguments] objectAtIndex: i] UTF8String]);
	}
	/* NULL terminated argv */
	argv[i + 1] = NULL;

	path = malloc([[self launchPath] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
	strcpy(path, [[self launchPath] UTF8String]);

	/* Fork and exec */
	pid = fork();
	if (pid > 0)
	{
		_processIdentifier = pid;
		to_free = argv;
		while (*to_free != NULL)
			free(*to_free++);
		free(argv);
		free(path);
		[argumentInvalid release];
	}
	else
	{
		execv(path, argv);
		/* Should never return */
		/* @throw exceptionInvalid; Make parent process throw this */
		printf("Failed to exec: path: %s args:", path);
		print_next = argv;
		while (*print_next != NULL) printf(" %s", *print_next++);
		printf("\n");
		exit(-1);
	}
}

+ (NSTask *)launchedTaskWithLaunchPath:(NSString *)path arguments:(NSArray<NSString *> *)arguments
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return nil;
}

@end
