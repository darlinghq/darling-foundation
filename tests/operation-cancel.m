#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

@interface CountingOperation : NSOperation { @public NSUInteger runs; }
@end
@implementation CountingOperation
- (void)main { ++runs; }
@end

int main(void)
{
    @autoreleasepool {
        CountingOperation *cancelled = [[CountingOperation alloc] init];
        [cancelled cancel];
        [cancelled start];
        assert(cancelled->runs == 0);
        assert([cancelled isCancelled] && [cancelled isFinished]);
        assert(![cancelled isExecuting]);
        [cancelled waitUntilFinished];
        [cancelled release];
        CountingOperation *ordinary = [[CountingOperation alloc] init];
        [ordinary start];
        assert(ordinary->runs == 1);
        assert([ordinary isFinished] && ![ordinary isExecuting]);
        [ordinary release];
    }
    puts("PASS: cancelled operation skips main and reaches finished");
    return 0;
}
