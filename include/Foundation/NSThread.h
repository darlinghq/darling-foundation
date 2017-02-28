#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
#import <pthread.h>

@class NSArray, NSMutableDictionary, NSDate, NSMutableArray;

FOUNDATION_EXPORT NSString * const NSWillBecomeMultiThreadedNotification;
FOUNDATION_EXPORT NSString * const NSDidBecomeSingleThreadedNotification;
FOUNDATION_EXPORT NSString * const NSThreadWillExitNotification;

typedef enum {
    NSThreadCreated,
    NSThreadStarted,
    NSThreadRunning,
    NSThreadCancelling,
    NSThreadEnding,
    NSThreadFinished
} NSThreadState;

@interface NSThread : NSObject
{
@package
    pthread_t _thread;
    pthread_attr_t _attr;
    NSString *_name;
    NSMutableDictionary *_threadDictionary;
    NSThreadState _state;
    NSMutableArray *_performers;
    id _target;
    SEL _selector;
    id _argument;
}

+ (NSThread *)currentThread;
+ (void)detachNewThreadSelector:(SEL)selector toTarget:(id)target withObject:(id)argument;
+ (BOOL)isMultiThreaded;
+ (void)sleepUntilDate:(NSDate *)date;
+ (void)sleepForTimeInterval:(NSTimeInterval)ti;
+ (void)exit;
+ (double)threadPriority;
+ (BOOL)setThreadPriority:(double)p;
+ (NSArray *)callStackReturnAddresses;
+ (NSArray *)callStackSymbols;
+ (BOOL)isMainThread;
+ (NSThread *)mainThread;
- (id)init;
- (id)initWithTarget:(id)target selector:(SEL)selector object:(id)argument;
- (NSMutableDictionary *)threadDictionary;
- (double)threadPriority;
- (void)setThreadPriority:(double)p;
- (void)setName:(NSString *)n;
- (NSString *)name;
- (NSUInteger)stackSize;
- (void)setStackSize:(NSUInteger)s;
- (BOOL)isMainThread;
- (BOOL)isExecuting;
- (BOOL)isFinished;
- (BOOL)isCancelled;
- (void)cancel;
- (void)start;
- (void)main;

@end

@interface NSObject (NSThreadPerformAdditions)

- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(id)arg waitUntilDone:(BOOL)wait modes:(NSArray *)array;
- (void)performSelectorOnMainThread:(SEL)aSelector withObject:(id)arg waitUntilDone:(BOOL)wait;
- (void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait modes:(NSArray *)array;
- (void)performSelector:(SEL)aSelector onThread:(NSThread *)thr withObject:(id)arg waitUntilDone:(BOOL)wait;
- (void)performSelectorInBackground:(SEL)aSelector withObject:(id)arg;

@end
