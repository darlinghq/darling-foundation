// CFLAGS: -framework Foundation
/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * The NSURLSessionTask priority constants and the NSURLSessionWebSocketMessage class, as
 * documented: priorities 0.5 / 0.25 / 0.75, and a message that holds either data or a string.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL: %s (line %d)\n", #c, __LINE__); failures++; } } while (0)

int main(void)
{
	@autoreleasepool {
		CHECK(NSURLSessionTaskPriorityDefault == 0.5f);
		CHECK(NSURLSessionTaskPriorityLow == 0.25f);
		CHECK(NSURLSessionTaskPriorityHigh == 0.75f);

		NSMutableString *source = [NSMutableString stringWithString:@"hello"];
		NSURLSessionWebSocketMessage *text = [[NSURLSessionWebSocketMessage alloc] initWithString:source];
		[source appendString:@" changed"];
		CHECK(text.type == NSURLSessionWebSocketMessageTypeString);
		CHECK([text.string isEqualToString:@"hello"]);
		CHECK(text.data == nil);

		NSMutableData *bytes = [NSMutableData dataWithBytes:"ab\0c" length:4];
		NSURLSessionWebSocketMessage *binary = [[NSURLSessionWebSocketMessage alloc] initWithData:bytes];
		[bytes appendBytes:"x" length:1];
		CHECK(binary.type == NSURLSessionWebSocketMessageTypeData);
		CHECK(binary.data.length == 4);
		CHECK(binary.string == nil);

		CHECK(NSURLSessionWebSocketMessageTypeData == 0);
		CHECK(NSURLSessionWebSocketMessageTypeString == 1);
	}
	printf(failures ? "FAILED\n" : "PASS\n");
	return failures != 0;
}
