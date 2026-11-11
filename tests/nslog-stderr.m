/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSLog writes its line to standard error and nothing to standard output.
 *
 * Build: clang -target <arch>-apple-macos... -framework Foundation
 *        -lobjc nslog_stderr.m
 */

#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int failures;

static void expect(int ok, const char* what)
{
	printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
	if (!ok)
		failures++;
}

/* Reads whatever is available on the pipe without blocking forever: the
 * write end has been restored to the original descriptor by then. */
static size_t drain(int fd, char* buf, size_t cap)
{
	size_t n = 0;
	ssize_t r;
	while (n < cap - 1 && (r = read(fd, buf + n, cap - 1 - n)) > 0)
		n += (size_t)r;
	buf[n] = 0;
	return n;
}

int main(void)
{
	@autoreleasepool {
		int outPipe[2], errPipe[2];
		pipe(outPipe);
		pipe(errPipe);
		fflush(stdout);
		int savedOut = dup(1), savedErr = dup(2);
		dup2(outPipe[1], 1);
		dup2(errPipe[1], 2);

		NSLog(@"nslog-marker %d", 42);

		fflush(stdout);
		dup2(savedOut, 1);
		dup2(savedErr, 2);
		close(outPipe[1]);
		close(errPipe[1]);

		char outBuf[1024], errBuf[1024];
		size_t outLen = drain(outPipe[0], outBuf, sizeof outBuf);
		size_t errLen = drain(errPipe[0], errBuf, sizeof errBuf);

		expect(strstr(errBuf, "nslog-marker 42") != NULL, "NSLog text appears on fd 2");
		expect(errLen > 0 && errBuf[errLen - 1] == '\n', "NSLog line is newline-terminated");
		expect(outLen == 0, "NSLog writes nothing to fd 1");
	}
	printf("%s\n", failures ? "FAILED" : "ALL PASSED");
	return failures ? 1 : 0;
}
