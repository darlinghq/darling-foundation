/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSTask must not close file handles supplied by the caller (including the
 * standard I/O singletons), must launch repeatedly with them, and must close
 * only the child's end of an NSPipe so that readers see EOF.
 *
 * Build: clang -target <arch>-apple-macos... -framework Foundation
 *        -lobjc nstask_stdio_handles.m
 */

#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

static int failures;

static void expect(BOOL ok, const char* what)
{
	printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
	if (!ok)
		failures++;
}

static BOOL fdIsOpen(int fd)
{
	return fcntl(fd, F_GETFD) != -1;
}

int main(void)
{
	@autoreleasepool {
		/* launch twice with the standard I/O singletons */
		for (int i = 0; i < 2; i++) {
			NSTask* task = [[NSTask alloc] init];
			task.launchPath = @"/bin/echo";
			task.arguments = @[@"x"];
			task.standardOutput = [NSFileHandle fileHandleWithStandardOutput];
			task.standardError = [NSFileHandle fileHandleWithStandardError];
			task.standardInput = [NSFileHandle fileHandleWithStandardInput];
			BOOL threw = NO;
			@try {
				[task launch];
				[task waitUntilExit];
			} @catch (NSException* e) {
				threw = YES;
			}
			expect(!threw && task.terminationStatus == 0, "launch with standard I/O singletons");
			[task release];
		}
		expect(fdIsOpen(0) && fdIsOpen(1) && fdIsOpen(2), "standard descriptors remain open");

		/* a caller-supplied file handle stays open after launch */
		char path[] = "/tmp/nstask_stdio_handles.XXXXXX";
		int tfd = mkstemp(path);
		NSFileHandle* fh = [[NSFileHandle alloc] initWithFileDescriptor:tfd closeOnDealloc:YES];
		NSTask* task = [[NSTask alloc] init];
		task.launchPath = @"/bin/echo";
		task.arguments = @[@"to-file"];
		task.standardOutput = fh;
		[task launch];
		[task waitUntilExit];
		expect(fdIsOpen(tfd), "caller file handle descriptor open after launch");
		BOOL threw = NO;
		@try {
			[fh writeData:[@"more\n" dataUsingEncoding:NSUTF8StringEncoding]];
		} @catch (NSException* e) {
			threw = YES;
		}
		expect(!threw, "parent can still write to the caller file handle");
		[task release];
		[fh release];
		unlink(path);

		/* NSPipe: reader sees EOF once the child exits */
		NSPipe* pipe = [NSPipe pipe];
		task = [[NSTask alloc] init];
		task.launchPath = @"/bin/echo";
		task.arguments = @[@"hello"];
		task.standardOutput = pipe;
		[task launch];
		NSData* data = [[pipe fileHandleForReading] readDataToEndOfFile];
		[task waitUntilExit];
		NSString* s = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		expect([s isEqualToString:@"hello\n"], "NSPipe output read to EOF");
		[task release];

		/* launch failure reports the posix_spawn error */
		task = [[NSTask alloc] init];
		task.executableURL = [NSURL fileURLWithPath:@"/nonexistent/nstask-probe"];
		NSError* err = nil;
		BOOL ok = [task launchAndReturnError:&err];
		expect(!ok && err != nil, "launching a missing executable fails with an error");
		[task release];
	}
	printf("%s\n", failures ? "FAILED" : "ALL PASSED");
	return failures ? 1 : 0;
}
