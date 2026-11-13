/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * -[NSRunLoop performBlock:] and -performInModes:block: run the block on the
 * target run loop, also when queued from another thread while that loop sleeps
 * (a wakeup is required). +mainRunLoop, +currentRunLoop and
 * +[NSNotificationCenter defaultCenter] are available as class properties.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void)
{
	@autoreleasepool {
		int failures = 0;
		__block int ran = 0;
		__block BOOL onMain = NO;

		if (NSRunLoop.mainRunLoop != [NSRunLoop mainRunLoop] || NSRunLoop.currentRunLoop == nil
		    || NSNotificationCenter.defaultCenter == nil) {
			printf("FAIL: class properties\n");
			failures++;
		}

		[NSRunLoop.mainRunLoop performBlock:^{ ran++; onMain = [NSThread isMainThread]; }];
		[NSRunLoop.mainRunLoop performInModes:@[NSDefaultRunLoopMode] block:^{ ran++; }];
		[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
		if (ran != 2 || !onMain) {
			printf("FAIL: blocks ran=%d onMain=%d\n", ran, (int)onMain);
			failures++;
		}

		/* Queue from another thread while the main loop sleeps in a long run. */
		NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
		__block BOOL done = NO;
		dispatch_async(dispatch_get_global_queue(0, 0), ^{
			usleep(200000);
			[NSRunLoop.mainRunLoop performBlock:^{ done = YES; }];
		});
		while (!done && [NSDate timeIntervalSinceReferenceDate] - start < 10)
			[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
		NSTimeInterval took = [NSDate timeIntervalSinceReferenceDate] - start;
		if (!done || took > 3) {
			printf("FAIL: cross-thread block took %.2fs (done=%d)\n", took, (int)done);
			failures++;
		}

		if (failures == 0)
			printf("PASS: runloop perform-block\n");
		return failures != 0;
	}
}
