#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
#import <CoreFoundation/CFRunLoop.h>

@class NSTimer, NSPort, NSArray;

typedef NSString *NSRunLoopMode;

FOUNDATION_EXPORT const NSRunLoopMode NSDefaultRunLoopMode;
FOUNDATION_EXPORT const NSRunLoopMode NSRunLoopCommonModes;

@interface NSRunLoop : NSObject {
@public
    CFRunLoopRef _rl;
    id _dperf;
    id _perft;
    id _info;
    id _ports;
    void *_reserved[6];
}

@end

@interface NSRunLoop (NSRunLoop)

+ (NSRunLoop *)currentRunLoop;
+ (NSRunLoop *)mainRunLoop;

- (NSRunLoopMode) currentMode;
- (CFRunLoopRef) getCFRunLoop;

- (void) addTimer: (NSTimer *) timer forMode: (NSRunLoopMode) mode;

- (void) addPort: (NSPort *) aPort forMode: (NSRunLoopMode) mode;
- (void) removePort: (NSPort *) aPort forMode: (NSRunLoopMode) mode;

- (NSDate *) limitDateForMode: (NSRunLoopMode) mode;
- (void) acceptInputForMode: (NSRunLoopMode) mode beforeDate: (NSDate *) limitDate;

@end

@interface NSRunLoop (NSRunLoopConveniences)

- (void) run;

- (void) runUntilDate: (NSDate *) limitDate;
- (BOOL) runMode: (NSRunLoopMode) mode beforeDate: (NSDate *) limitDate;

@end

@interface NSObject (NSDelayedPerforming)

- (void)performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(NSTimeInterval)delay inModes:(NSArray *)modes;
- (void)performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(NSTimeInterval)delay;
+ (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument;
+ (void)cancelPreviousPerformRequestsWithTarget:(id)aTarget;

@end

@interface NSRunLoop (NSOrderedPerform)

- (void)performSelector:(SEL)aSelector target:(id)target argument:(id)arg order:(NSUInteger)order modes:(NSArray *)modes;
- (void)cancelPerformSelector:(SEL)aSelector target:(id)target argument:(id)arg;
- (void)cancelPerformSelectorsWithTarget:(id)target;

@end
