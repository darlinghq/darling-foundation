// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: NSOperationQueue's documented properties (maxConcurrentOperationCount, suspended, name,
// operationCount, operations) used with dot syntax, which compiles only when the header declares them as
// properties, and their behaviour on a queue that has no work.
#import <Foundation/Foundation.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

int main(void)
{
    @autoreleasepool {
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        report("default maxConcurrentOperationCount", queue.maxConcurrentOperationCount == NSOperationQueueDefaultMaxConcurrentOperationCount);
        queue.maxConcurrentOperationCount = 1;
        report("maxConcurrentOperationCount round trip", queue.maxConcurrentOperationCount == 1);
        report("not suspended by default", !queue.suspended && !queue.isSuspended);
        queue.suspended = YES;
        report("suspended setter", queue.isSuspended);
        queue.name = @"queue-under-test";
        report("name round trip", [queue.name isEqualToString:@"queue-under-test"]);
        report("empty queue has no operations", queue.operationCount == 0 && queue.operations.count == 0);

        __block BOOL ran = NO;
        [queue addOperationWithBlock:^{ ran = YES; }];
        report("a suspended queue holds its operation", queue.operationCount == 1 && queue.operations.count == 1 && !ran);
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];
        report("the operation runs once the queue is resumed", ran && queue.operationCount == 0);
    }
    return failures ? 1 : 0;
}
