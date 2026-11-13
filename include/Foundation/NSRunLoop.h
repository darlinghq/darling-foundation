#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
#import <CoreFoundation/CFRunLoop.h>

@class NSTimer, NSPort, NSArray<ObjectType>;

// NS_TYPED_EXTENSIBLE_ENUM as in the macOS SDK. Without the wrapper this is a plain String
// typealias in Swift, so the nested RunLoop.Mode has nowhere to carry .default and .common.
typedef NSString *NSRunLoopMode NS_TYPED_EXTENSIBLE_ENUM;

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

@property (class, readonly, retain) NSRunLoop * _Nonnull currentRunLoop;
@property (class, readonly, retain) NSRunLoop * _Nonnull mainRunLoop;

@property (readonly, copy) NSRunLoopMode _Nullable currentMode;
// NSRunLoop owns this run loop; callers receive a borrowed reference.
- (CFRunLoopRef) getCFRunLoop CF_RETURNS_NOT_RETAINED;

- (void) addTimer: (NSTimer *) timer forMode: (NSRunLoopMode) mode;

- (void) addPort: (NSPort *) aPort forMode: (NSRunLoopMode) mode;
- (void) removePort: (NSPort *) aPort forMode: (NSRunLoopMode) mode;

- (NSDate *) limitDateForMode: (NSRunLoopMode) mode;
- (void) acceptInputForMode: (NSRunLoopMode) mode beforeDate: (NSDate *) limitDate;

@end

@interface NSRunLoop (NSRunLoopConveniences)

- (void) run;

- (void) runUntilDate: (NSDate *) limitDate;
- (BOOL) runMode: (NSRunLoopMode _Nonnull) mode beforeDate: (NSDate * _Nonnull) limitDate NS_SWIFT_NAME(run(mode:before:));

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
- (void)performInModes:(NSArray<NSRunLoopMode> * _Nonnull)modes block:(void (^ _Nonnull)(void))block;
- (void)performBlock:(void (^ _Nonnull)(void))block;

@end
