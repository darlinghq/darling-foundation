// Copyright (C) 2026 Lubos Dolezel
// Behaviour of +detachNewThreadWithBlock: and -initWithBlock: (macOS 10.12+).
#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        // detachNewThreadWithBlock: runs the block exactly once, on another thread.
        NSConditionLock *lock = [[NSConditionLock alloc] initWithCondition:0];
        __block int runs = 0;
        __block BOOL onMain = YES, isMainThreadClass = YES, mainFlag = YES;
        __block NSThread *seen = nil;
        [NSThread detachNewThreadWithBlock:^{
            runs++;
            onMain = [[NSThread currentThread] isMainThread];
            isMainThreadClass = [NSThread isMainThread];
            seen = [NSThread currentThread];
            mainFlag = [seen isMainThread];
            [lock lock];
            [lock unlockWithCondition:1];
        }];
        [lock lockWhenCondition:1];
        [lock unlock];
        [NSThread sleepForTimeInterval:0.2];
        assert(runs == 1);
        assert(!onMain && !isMainThreadClass && !mainFlag);
        assert([seen isEqual:[NSThread mainThread]] == NO);

        // initWithBlock: does not run until -start; name is settable and visible
        // from the block; the thread is not main and runs the block once.
        NSConditionLock *lock2 = [[NSConditionLock alloc] initWithCondition:0];
        __block int runs2 = 0;
        __block NSString *name = nil;
        __block BOOL main2 = YES;
        NSThread *thread = [[NSThread alloc] initWithBlock:^{
            runs2++;
            name = [[[NSThread currentThread] name] copy];
            main2 = [[NSThread currentThread] isMainThread];
            [lock2 lock];
            [lock2 unlockWithCondition:1];
        }];
        assert(thread != nil);
        [thread setName:@"block-thread"];
        assert(![thread isMainThread]);
        assert(![thread isExecuting] && ![thread isFinished]);
        [NSThread sleepForTimeInterval:0.1];
        assert(runs2 == 0);
        [thread start];
        [lock2 lockWhenCondition:1];
        [lock2 unlock];
        [NSThread sleepForTimeInterval:0.2];
        assert(runs2 == 1);
        assert([name isEqualToString:@"block-thread"]);
        assert(!main2);
        assert([thread isFinished]);
        printf("PASS\n");
    }
    return 0;
}
