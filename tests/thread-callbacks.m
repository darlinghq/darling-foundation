#import <Foundation/Foundation.h>
#include <pthread.h>
#include <dispatch/dispatch.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

@interface CallbackThread : NSThread {
@public pthread_t nativeThread; dispatch_semaphore_t entered; BOOL identityMatches;
}
@end
@implementation CallbackThread
- (void)main {
    nativeThread = pthread_self();
    identityMatches = [NSThread currentThread] == self;
    dispatch_semaphore_signal(entered);
}
@end

@interface ExitObserver : NSObject { @public NSUInteger exits; }
@end
@implementation ExitObserver
- (void)threadExited:(NSNotification *)notification { ++exits; }
@end

int main(void) {
    @autoreleasepool {
        ExitObserver *observer = [[ExitObserver alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:observer
            selector:@selector(threadExited:) name:NSThreadWillExitNotification object:nil];
        for (NSUInteger i = 0; i < 16; ++i) {
            CallbackThread *thread = [[CallbackThread alloc] init];
            thread->entered = dispatch_semaphore_create(0);
            [thread start];
            assert(dispatch_semaphore_wait(thread->entered,
                dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0);
            assert(pthread_join(thread->nativeThread, NULL) == 0);
            assert(thread->identityMatches);
            assert([thread isFinished]);
            assert(observer->exits == i + 1);
            dispatch_release(thread->entered);
            [thread release];
        }
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
        [observer release];
    }
    puts("PASS: NSThread entry and pthread TLS exit callbacks");
    return 0;
}
