#import <Foundation/NSNotification.h>

@class NSString, NSDictionary;

NS_ASSUME_NONNULL_BEGIN

typedef NSString * NSDistributedNotificationCenterType NS_EXTENSIBLE_STRING_ENUM;

FOUNDATION_EXPORT NSDistributedNotificationCenterType const NSLocalNotificationCenterType;

typedef NS_ENUM(NSUInteger, NSNotificationSuspensionBehavior) {
    NSNotificationSuspensionBehaviorDrop = 1,
    NSNotificationSuspensionBehaviorCoalesce = 2,
    NSNotificationSuspensionBehaviorHold = 3,
    NSNotificationSuspensionBehaviorDeliverImmediately = 4
};

typedef NS_OPTIONS(NSUInteger, NSDistributedNotificationOptions) {
    NSDistributedNotificationDeliverImmediately = (1UL << 0),
    NSDistributedNotificationPostToAllSessions = (1UL << 1)
};
static const NSDistributedNotificationOptions NSNotificationDeliverImmediately = NSDistributedNotificationDeliverImmediately;
static const NSDistributedNotificationOptions NSNotificationPostToAllSessions = NSDistributedNotificationPostToAllSessions;

@interface NSDistributedNotificationCenter : NSNotificationCenter

+ (NSDistributedNotificationCenter *)notificationCenterForType:(NSDistributedNotificationCenterType)notificationCenterType;

+ (NSDistributedNotificationCenter *)defaultCenter;

- (void)addObserver:(id)observer selector:(SEL)selector name:(nullable NSNotificationName)name object:(nullable NSString *)object suspensionBehavior:(NSNotificationSuspensionBehavior)suspensionBehavior;

- (void)postNotificationName:(NSNotificationName)name object:(nullable NSString *)object userInfo:(nullable NSDictionary *)userInfo deliverImmediately:(BOOL)deliverImmediately;

- (void)postNotificationName:(NSNotificationName)name object:(nullable NSString *)object userInfo:(nullable NSDictionary *)userInfo options:(NSDistributedNotificationOptions)options;

@property BOOL suspended;

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(nullable NSNotificationName)aName object:(nullable NSString *)anObject;

- (void)postNotificationName:(NSNotificationName)aName object:(nullable NSString *)anObject;
- (void)postNotificationName:(NSNotificationName)aName object:(nullable NSString *)anObject userInfo:(nullable NSDictionary *)aUserInfo;
- (void)removeObserver:(id)observer name:(nullable NSNotificationName)aName object:(nullable NSString *)anObject;

@end

NS_ASSUME_NONNULL_END

