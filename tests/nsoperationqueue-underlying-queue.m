// Copyright (C) 2026 Lubos Dolezel
//
// -[NSOperationQueue underlyingQueue], as observed on macOS 26.7.3 and Mac OS
// X 10.14.4 (the program builds and runs there too):
//  - a new queue has none, and the main operation queue's is the main
//    dispatch queue;
//  - operations run on the dispatch queue set, also a concurrent one, and
//    setting nil goes back to none;
//  - it cannot change while the queue has operations (it raises
//    NSInvalidArgumentException);
//  - setting it on the main operation queue changes nothing.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static int failures;

static void expect(BOOL ok, const char *what)
{
    if (!ok) {
        fprintf(stderr, "FAIL: %s\n", what);
        failures++;
    }
}

int main(void)
{
    @autoreleasepool {
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        expect(queue.underlyingQueue == NULL, "a new queue has no underlying queue");
        expect([NSOperationQueue mainQueue].underlyingQueue == dispatch_get_main_queue(),
               "the main queue's is the main dispatch queue");

        dispatch_queue_t serial = dispatch_queue_create("org.darlinghq.test.underlying", DISPATCH_QUEUE_SERIAL);
        queue.underlyingQueue = serial;
        expect(queue.underlyingQueue == serial, "the queue set reads back");
        __block const char *label = NULL;
        [queue addOperationWithBlock:^{
            label = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
        }];
        [queue waitUntilAllOperationsAreFinished];
        expect(label != NULL && strcmp(label, "org.darlinghq.test.underlying") == 0, "operations run on the queue set");

        queue.underlyingQueue = NULL;
        expect(queue.underlyingQueue == NULL, "nil goes back to none");

        queue.suspended = YES;
        [queue addOperationWithBlock:^{}];
        BOOL raised = NO;
        @try {
            queue.underlyingQueue = serial;
        } @catch (NSException *exception) {
            raised = [exception.name isEqualToString:NSInvalidArgumentException];
        }
        expect(raised, "it cannot change while the queue has operations");
        expect(queue.underlyingQueue == NULL, "a refused change leaves it as it was");
        queue.suspended = NO;
        [queue waitUntilAllOperationsAreFinished];

        queue.maxConcurrentOperationCount = 3;
        queue.underlyingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        __block int ran = 0;
        for (int i = 0; i < 5; i++)
            [queue addOperationWithBlock:^{ __sync_fetch_and_add(&ran, 1); }];
        [queue waitUntilAllOperationsAreFinished];
        expect(ran == 5, "operations run on a concurrent queue");

        [NSOperationQueue mainQueue].underlyingQueue = serial;
        expect([NSOperationQueue mainQueue].underlyingQueue == dispatch_get_main_queue(),
               "quirk: the main queue keeps the main dispatch queue");

        [queue release];
        dispatch_release(serial);
    }

    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures != 0;
}
