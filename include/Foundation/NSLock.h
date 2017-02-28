#import <Foundation/NSObject.h>
#import <pthread.h>

@class NSDate;

@protocol NSLocking

- (void)lock;
- (void)unlock;

@end

@interface NSLock : NSObject <NSLocking>
{
    pthread_t _thread;
    pthread_mutex_t _lock;
    NSString *_name;
    BOOL _isInitialized;
}

- (BOOL)tryLock;
- (BOOL)lockBeforeDate:(NSDate *)limit;
- (void)setName:(NSString *)n;
- (NSString *)name;

@end

@class NSCondition;
@interface NSConditionLock : NSObject <NSLocking>
{
    NSCondition *_cond;
    NSInteger _value;
    pthread_t _thread;
    BOOL _locked;
}

- (id)initWithCondition:(NSInteger)condition;
- (NSInteger)condition;
- (void)lockWhenCondition:(NSInteger)condition;
- (BOOL)tryLock;
- (BOOL)tryLockWhenCondition:(NSInteger)condition;
- (void)unlockWithCondition:(NSInteger)condition;
- (BOOL)lockBeforeDate:(NSDate *)limit;
- (BOOL)lockWhenCondition:(NSInteger)condition beforeDate:(NSDate *)limit;
- (void)setName:(NSString *)n;
- (NSString *)name;

@end

@interface NSRecursiveLock : NSObject <NSLocking>
{
    pthread_mutex_t _lock;
    pthread_mutexattr_t _attrs;
    pthread_t _thread;
    int _locks;
    NSString *_name;
    BOOL _lockIsInitialized;
    BOOL _mutexAttrsInitialized;
}

- (BOOL)tryLock;
- (BOOL)lockBeforeDate:(NSDate *)limit;
- (void)setName:(NSString *)n;
- (NSString *)name;

@end

@interface NSCondition : NSObject <NSLocking>
{
    pthread_mutex_t _lock;
    pthread_mutexattr_t _attrs;
    pthread_cond_t _cond;
    pthread_condattr_t _condAttrs;
    pthread_t _thread;
    NSString *_name;
    BOOL _isInitialized;
}

- (void)wait;
- (BOOL)waitUntilDate:(NSDate *)limit;
- (void)signal;
- (void)broadcast;
- (void)setName:(NSString *)n;
- (NSString *)name;

@end
