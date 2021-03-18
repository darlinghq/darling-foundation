#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDate.h>

#include <stdlib.h>
#include <dispatch/dispatch.h>

#import "logging.h"

// by default, we log things message manually to a file because launchd's stdout redirection cuts off parts of our output for some reason
#ifndef LOG_TO_FILE
	#define LOG_TO_FILE 1
#endif
#ifndef LOGFILE
	#define LOGFILE "/var/log/fcdaemon.log"
#endif
#ifndef LOGFILE_DELIMITER
	#define LOGFILE_DELIMITER "---\n"
#endif

void _FCDLog(const char* file, size_t line, NSString* format, ...) {
	va_list args;
	va_start(args, format);
	_FCDLogv(file, line, format, args);
	va_end(args);
};

void _FCDLogv(const char* file, size_t line, NSString* format, va_list args) {
#if LOG_TO_FILE
	static dispatch_once_t onceToken;
	static int logHandle = -1;
	dispatch_once(&onceToken, ^{
		logHandle = open(LOGFILE, O_WRONLY | O_APPEND);
		write(logHandle, LOGFILE_DELIMITER, sizeof(LOGFILE_DELIMITER));
	});

	NSString* formatWithExtraInfo = [NSString stringWithFormat: @"[%@] %s:%zu: %@\n", [NSDate date], file, line, format];
	NSString* message = [[[NSString alloc] initWithFormat: formatWithExtraInfo arguments: args] autorelease];
	write(logHandle, [message UTF8String], [message lengthOfBytesUsingEncoding: NSUTF8StringEncoding]);
#else
	NSLogv([NSString stringWithFormat: @"%s:%zu: %@", file, line, format], args);
#endif
};

void _FCDAssertionFailed(const char* expression, const char* file, size_t line) {
	_FCDLog(file, line, @"Assertion failed: %s", expression);
	abort();
};

BOOL _FCDDebugLogEnabled(void) {
	static BOOL enabled = NO;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		const char* envVar = getenv("FCD_DEBUG");
		if (envVar != NULL) {
			enabled = [NSString stringWithUTF8String: envVar].boolValue;
		}
	});

	return enabled;
};
