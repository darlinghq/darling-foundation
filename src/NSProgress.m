//
//  NSProgress.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSProgress.h>

NSString * const NSProgressEstimatedTimeRemainingKey = @"NSProgressEstimatedTimeRemainingKey";
NSString * const NSProgressThroughputKey = @"NSProgressThroughputKey";
NSString * const NSProgressKindFile = @"NSProgressKindFile";
NSString * const NSProgressFileOperationKindKey = @"NSProgressFileOperationKindKey";
NSString * const NSProgressFileOperationKindDownloading = @"NSProgressFileOperationKindDownloading";
NSString * const NSProgressFileOperationKindDecompressingAfterDownloading = @"NSProgressFileOperationKindDecompressingAfterDownloading";
NSString * const NSProgressFileOperationKindReceiving = @"NSProgressFileOperationKindReceiving";
NSString * const NSProgressFileOperationKindCopying = @"NSProgressFileOperationKindCopying";
NSString * const NSProgressFileURLKey = @"NSProgressFileURLKey";
NSString * const NSProgressFileTotalCountKey = @"NSProgressFileTotalCountKey";
NSString * const NSProgressFileCompletedCountKey = @"NSProgressFileCompletedCountKey";
NSString * const NSProgressFileAnimationImageKey = @"NSProgressFlyToImageKey";
NSString * const NSProgressFileAnimationImageOriginalRectKey = @"NSProgressFileAnimationImageOriginalRectKey";
NSString * const NSProgressFileIconKey = @"NSProgressFileIconKey";

@implementation NSProgress

+ (id)currentProgress
{
    return nil;
}

+ (id)progressWithTotalUnitCount:(int64_t)unitCount
{
    return nil;
}

- (BOOL)isCancelled
{
    return NO;
}

- (void)setCompletedUnitCount:(int64_t)count
{
}

- (int64_t)completedUnitCount
{
    return 0;
}

@end
