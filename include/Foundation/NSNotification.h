#import <Foundation/NSObject.h>
#import <pthread.h>

typedef NSString *NSNotificationName NS_EXTENSIBLE_STRING_ENUM;

@class NSString, NSDictionary, NSOperationQueue, NSMutableArray;

@interface NSNotification : NSObject <NSCopying, NSCoding>

- (NSNotificationName _Nonnull)name;
- (id _Nullable)object;
- (NSDictionary * _Nullable)userInfo;

@end

@interface NSNotification (NSNotificationCreation)

+ (instancetype _Nonnull)notificationWithName:(NSNotificationName _Nonnull)aName object:(id _Nullable)anObject;
+ (instancetype _Nonnull)notificationWithName:(NSNotificationName _Nonnull)aName object:(id _Nullable)anObject userInfo:(NSDictionary * _Nullable)aUserInfo;

@end

@interface NSNotificationCenter : NSObject
{
    NSMutableArray *_observers;
    pthread_mutex_t _observersLock;
}

@property (class, readonly, retain) NSNotificationCenter * _Nonnull defaultCenter;
- (void)addObserver:(id _Nonnull)observer selector:(SEL _Nonnull)aSelector name:(NSNotificationName _Nullable)aName object:(id _Nullable)anObject;
- (void)postNotification:(NSNotification * _Nonnull)notification;
- (void)postNotificationName:(NSNotificationName _Nonnull)aName object:(id _Nullable)anObject;
- (void)postNotificationName:(NSNotificationName _Nonnull)aName object:(id _Nullable)anObject userInfo:(NSDictionary * _Nullable)aUserInfo;
- (void)removeObserver:(id _Nonnull)observer;
- (void)removeObserver:(id _Nonnull)observer name:(NSNotificationName _Nullable)aName object:(id _Nullable)anObject;
#if NS_BLOCKS_AVAILABLE
- (id <NSObject> _Nonnull)addObserverForName:(NSNotificationName _Nullable)name object:(id _Nullable)obj queue:(NSOperationQueue * _Nullable)queue usingBlock:(void (^ _Nonnull)(NSNotification * _Nonnull note))block NS_AVAILABLE(10_6, 4_0);
#endif

@end
