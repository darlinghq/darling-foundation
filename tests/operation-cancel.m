#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
#import <dispatch/dispatch.h>

@interface StateObserver : NSObject { @public NSUInteger finished; NSUInteger executing; }
@end
@implementation StateObserver
- (void)observeValueForKeyPath:(NSString *)key ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([key isEqual:@"isFinished"]) { assert([object isFinished]); ++finished; }
    if ([key isEqual:@"isExecuting"]) ++executing;
}
@end

@interface CountingOperation : NSOperation { @public NSUInteger runs; }
@end
@implementation CountingOperation
- (void)main { ++runs; }
@end

int main(void)
{
    @autoreleasepool {
        CountingOperation *cancelled = [[CountingOperation alloc] init];
        StateObserver *observer = [[StateObserver alloc] init];
        [cancelled addObserver:observer forKeyPath:@"isFinished" options:0 context:NULL];
        [cancelled addObserver:observer forKeyPath:@"isExecuting" options:0 context:NULL];
        [cancelled cancel];
        [cancelled start];
        assert(cancelled->runs == 0);
        assert([cancelled isCancelled] && [cancelled isFinished]);
        assert(![cancelled isExecuting]);
        [cancelled waitUntilFinished];
        assert(observer->finished == 1 && observer->executing == 0);
        [cancelled removeObserver:observer forKeyPath:@"isFinished"];
        [cancelled removeObserver:observer forKeyPath:@"isExecuting"];
        [observer release];
        [cancelled release];
        CountingOperation *ordinary = [[CountingOperation alloc] init];
        [ordinary start];
        assert(ordinary->runs == 1);
        assert([ordinary isFinished] && ![ordinary isExecuting]);
        [ordinary release];
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue setSuspended:YES];
        CountingOperation *queued = [[CountingOperation alloc] init];
        dispatch_semaphore_t completion = dispatch_semaphore_create(0);
        [queued setCompletionBlock:^{ dispatch_semaphore_signal(completion); }];
        [queue addOperation:queued];
        [queued cancel];
        [queue setSuspended:NO];
        assert(dispatch_semaphore_wait(completion, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0);
        [queue waitUntilAllOperationsAreFinished];
        assert(queued->runs == 0 && [queued isFinished] && ![queued isExecuting]);
        [queued release];
        [queue release];
        dispatch_release(completion);
    }
    puts("PASS: cancelled operation skips main and reaches finished");
    return 0;
}
