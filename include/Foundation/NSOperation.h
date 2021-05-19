#import <Foundation/NSObject.h>
#import <pthread.h>
#import <dispatch/dispatch.h>

@class NSArray, NSSet;

typedef NS_ENUM(NSInteger, NSOperationQueuePriority) {
    NSOperationQueuePriorityVeryLow = -8L,
    NSOperationQueuePriorityLow = -4L,
    NSOperationQueuePriorityNormal = 0,
    NSOperationQueuePriorityHigh = 4,
    NSOperationQueuePriorityVeryHigh = 8
};

enum {
    NSOperationQueueDefaultMaxConcurrentOperationCount = -1
};

FOUNDATION_EXPORT NSString * const NSInvocationOperationVoidResultException;
FOUNDATION_EXPORT NSString * const NSInvocationOperationCancelledException;

@class _NSOperationInternal;
@interface NSOperation : NSObject
{
    _NSOperationInternal *_internal;
}

@property NSQualityOfService qualityOfService;

- (id)init;
- (void)start;
- (void)main;
- (BOOL)isCancelled;
- (void)cancel;
- (BOOL)isExecuting;
- (BOOL)isFinished;
- (BOOL)isConcurrent;
- (BOOL)isReady;
- (void)addDependency:(NSOperation *)op;
- (void)removeDependency:(NSOperation *)op;
- (NSArray *)dependencies;
- (NSOperationQueuePriority)queuePriority;
- (void)setQueuePriority:(NSOperationQueuePriority)p;
#if NS_BLOCKS_AVAILABLE
- (void (^)(void))completionBlock;
- (void)setCompletionBlock:(void (^)(void))block;
#endif
- (void)waitUntilFinished;
- (double)threadPriority;
- (void)setThreadPriority:(double)p;

@end

@class NSMutableArray;
@interface NSBlockOperation : NSOperation
{
    dispatch_block_t _block;
    NSMutableArray *_blocks;
}

#if NS_BLOCKS_AVAILABLE
+ (id)blockOperationWithBlock:(void (^)(void))block;
- (void)addExecutionBlock:(void (^)(void))block;
- (NSArray *)executionBlocks;
#endif

@end

@interface NSInvocationOperation : NSOperation
{
    NSInvocation *_inv;
}

- (id)initWithTarget:(id)target selector:(SEL)sel object:(id)arg;
- (id)initWithInvocation:(NSInvocation *)inv;
- (NSInvocation *)invocation;
- (id)result;

@end

@class NSMutableArray, _NSOperationQueueInternal;

@interface NSOperationQueue : NSObject
{
    BOOL _suspended;
    NSString *_name;
    NSInteger _maxConcurrentOperationCount;
    pthread_mutex_t _queuelock;
    pthread_mutexattr_t _mta;

    NSMutableArray *_pendingOperations;
    NSMutableArray *_operations;
    NSMutableArray *_operationsToStart;

    _NSOperationQueueInternal *_internal;

    BOOL _isMainQueue;
    NSQualityOfService _qualityOfService;
}

@property NSQualityOfService qualityOfService;

+ (id)currentQueue;
+ (id)mainQueue;
- (void)addOperation:(NSOperation *)op;
- (void)addOperations:(NSArray *)ops waitUntilFinished:(BOOL)wait;
#if NS_BLOCKS_AVAILABLE
- (void)addOperationWithBlock:(void (^)(void))block;
#endif
- (NSArray *)operations;
- (NSUInteger)operationCount;
- (NSInteger)maxConcurrentOperationCount;
- (void)setMaxConcurrentOperationCount:(NSInteger)cnt;
- (void)setSuspended:(BOOL)b;
- (BOOL)isSuspended;
- (void)setName:(NSString *)n;
- (NSString *)name;
- (void)cancelAllOperations;
- (void)waitUntilAllOperationsAreFinished;

@end
