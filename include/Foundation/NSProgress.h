#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

@class NSNumber;

typedef NSString * NSProgressKind NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString * NSProgressUserInfoKey NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString * NSProgressFileOperationKind NS_TYPED_EXTENSIBLE_ENUM;

NS_ASSUME_NONNULL_BEGIN

@interface NSProgress : NSObject

+ (nullable NSProgress *)currentProgress;
+ (NSProgress *)progressWithTotalUnitCount:(int64_t)unitCount;
+ (NSProgress *)discreteProgressWithTotalUnitCount:(int64_t)unitCount;
+ (NSProgress *)progressWithTotalUnitCount:(int64_t)unitCount parent:(NSProgress *)parent pendingUnitCount:(int64_t)portionOfParentTotalUnitCount;

- (instancetype)initWithParent:(nullable NSProgress *)parentProgressOrNil userInfo:(nullable NSDictionary<NSProgressUserInfoKey, id> *)userInfoOrNil NS_DESIGNATED_INITIALIZER;

- (void)becomeCurrentWithPendingUnitCount:(int64_t)unitCount;
- (void)resignCurrent;
- (void)addChild:(NSProgress *)child withPendingUnitCount:(int64_t)inUnitCount;

@property int64_t totalUnitCount;
@property int64_t completedUnitCount;

@property (null_resettable, copy) NSString *localizedDescription;
@property (null_resettable, copy) NSString *localizedAdditionalDescription;

@property (getter=isCancellable) BOOL cancellable;
@property (getter=isPausable) BOOL pausable;
@property (readonly, getter=isCancelled) BOOL cancelled;
@property (readonly, getter=isPaused) BOOL paused;

@property (nullable, copy) void (^cancellationHandler)(void);
@property (nullable, copy) void (^pausingHandler)(void);
@property (nullable, copy) void (^resumingHandler)(void);

- (void)setUserInfoObject:(nullable id)objectOrNil forKey:(NSProgressUserInfoKey)key;

@property (readonly, getter=isIndeterminate) BOOL indeterminate;
@property (readonly) double fractionCompleted;
@property (readonly, getter=isFinished) BOOL finished;

- (void)cancel;
- (void)pause;
- (void)resume;

@property (readonly, copy) NSDictionary<NSProgressUserInfoKey, id> *userInfo;
@property (nullable, copy) NSProgressKind kind;
@property (nullable, copy) NSNumber *estimatedTimeRemaining;
@property (nullable, copy) NSNumber *throughput;

@end

FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressEstimatedTimeRemainingKey;
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressThroughputKey;
FOUNDATION_EXPORT NSProgressKind const NSProgressKindFile;
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileOperationKindKey;
FOUNDATION_EXPORT NSProgressFileOperationKind const NSProgressFileOperationKindDownloading;
FOUNDATION_EXPORT NSProgressFileOperationKind const NSProgressFileOperationKindDecompressingAfterDownloading;
FOUNDATION_EXPORT NSProgressFileOperationKind const NSProgressFileOperationKindReceiving;
FOUNDATION_EXPORT NSProgressFileOperationKind const NSProgressFileOperationKindCopying;
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileURLKey;
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileTotalCountKey;
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileCompletedCountKey;
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileAnimationImageKey;
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileAnimationImageOriginalRectKey;
FOUNDATION_EXPORT NSProgressUserInfoKey const NSProgressFileIconKey;

NS_ASSUME_NONNULL_END
