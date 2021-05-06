#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

FOUNDATION_EXPORT NSString * const NSProgressEstimatedTimeRemainingKey;
FOUNDATION_EXPORT NSString * const NSProgressThroughputKey;
FOUNDATION_EXPORT NSString * const NSProgressKindFile;
FOUNDATION_EXPORT NSString * const NSProgressFileOperationKindKey;
FOUNDATION_EXPORT NSString * const NSProgressFileOperationKindDownloading;
FOUNDATION_EXPORT NSString * const NSProgressFileOperationKindDecompressingAfterDownloading;
FOUNDATION_EXPORT NSString * const NSProgressFileOperationKindReceiving;
FOUNDATION_EXPORT NSString * const NSProgressFileOperationKindCopying;
FOUNDATION_EXPORT NSString * const NSProgressFileURLKey;
FOUNDATION_EXPORT NSString * const NSProgressFileTotalCountKey;
FOUNDATION_EXPORT NSString * const NSProgressFileCompletedCountKey;
FOUNDATION_EXPORT NSString * const NSProgressFileAnimationImageKey;
FOUNDATION_EXPORT NSString * const NSProgressFileAnimationImageOriginalRectKey;
FOUNDATION_EXPORT NSString * const NSProgressFileIconKey;

@interface NSProgress : NSObject {
	void (^_cancellationHandler)(void);
	void (^_pausingHandler)(void);
	void (^_resumingHandler)(void);
	int64_t _completedUnitCount;
	int64_t _totalUnitCount;
	BOOL _cancelled;
	BOOL _paused;
	BOOL _cancellable;
	BOOL _pausable;
}

+ (instancetype)currentProgress;
+ (instancetype)progressWithTotalUnitCount:(int64_t)unitCount;
+ (instancetype)discreteProgressWithTotalUnitCount: (int64_t)unitCount;

- (instancetype)initWithParent: (NSProgress*)parent userInfo: (NSDictionary<NSString*, id>*)userInfo;

@property(readonly, getter=isCancelled) BOOL cancelled;
@property(readonly, getter=isPaused) BOOL paused;
@property(getter=isCancellable) BOOL cancellable;
@property(getter=isPausable) BOOL pausable;
@property int64_t completedUnitCount;
@property int64_t totalUnitCount;

@property(copy) void (^cancellationHandler)(void);
@property(copy) void (^pausingHandler)(void);
@property(copy) void (^resumingHandler)(void);

- (void)cancel;
- (void)pause;
- (void)resume;

@end
