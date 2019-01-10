#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

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

@interface NSProgress : NSObject

+ (id)currentProgress;
+ (id)progressWithTotalUnitCount:(int64_t)unitCount;

@property(readonly, getter=isCancelled) BOOL cancelled;
@property int64_t completedUnitCount;

@end
