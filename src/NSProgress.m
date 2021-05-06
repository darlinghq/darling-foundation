//
//  NSProgress.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSProgress.h>
#import "NSProgressInternal.h"

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

// TODO: KVO
// (actually, TODO: pretty much all of NSProgress)
// also, the self-synchronization in basically every method is pretty inefficient
@implementation NSProgress

@synthesize cancellationHandler = _cancellationHandler;
@synthesize pausingHandler = _pausingHandler;
@synthesize resumingHandler = _resumingHandler;

+ (instancetype)currentProgress
{
    return nil;
}

+ (instancetype)progressWithTotalUnitCount: (int64_t)unitCount
{
    return nil;
}

+ (instancetype)discreteProgressWithTotalUnitCount: (int64_t)unitCount
{
    return nil;
}

- (void)dealloc
{
    [_cancellationHandler release];
    [_pausingHandler release];
    [_resumingHandler release];
    [super dealloc];
}

- (instancetype)initWithParent: (NSProgress*)parent userInfo: (NSDictionary<NSString*, id>*)userInfo
{
    if (self = [super init]) {

    }
    return self;
}

- (BOOL)isCancelled
{
    @synchronized(self) {
        return _cancelled;
    }
}

- (BOOL)isPaused
{
    @synchronized(self) {
        return _paused;
    }
}

- (BOOL)isCancellable
{
    @synchronized(self) {
        return _cancellable;
    }
}

- (void)setCancellable: (BOOL)cancellable
{
    @synchronized(self) {
        _cancellable = cancellable;
    }
}

- (BOOL)isPausable
{
    @synchronized(self) {
        return _pausable;
    }
}

- (void)setPausable: (BOOL)pausable
{
    @synchronized(self) {
        _pausable = pausable;
    }
}

- (int64_t)completedUnitCount
{
    @synchronized(self) {
        return _completedUnitCount;
    }
}

- (void)setCompletedUnitCount: (int64_t)count
{
    @synchronized(self) {
        _completedUnitCount = count;
    }
}

- (int64_t)totalUnitCount
{
    @synchronized(self) {
        return _totalUnitCount;
    }
}

- (void)setTotalUnitCount: (int64_t)count
{
    @synchronized(self) {
        _totalUnitCount = count;
    }
}

- (void)cancel
{
    @synchronized(self) {
        if (!_cancellable || _cancelled) {
            return;
        }

        _cancelled = YES;
        if (_cancellationHandler) {
            _cancellationHandler();
        }
    }
}

- (void)pause
{
    @synchronized(self) {
        if (!_pausable || _paused) {
            return;
        }

        _paused = YES;
        if (_pausingHandler) {
            _pausingHandler();
        }
    }
}

- (void)resume
{
    @synchronized(self) {
        if (!_paused) {
            return;
        }

        _paused = NO;
        if (_resumingHandler) {
            _resumingHandler();
        }
    }
}

@end

@implementation _NSProgressWithRemoteParent

@synthesize sequence = _sequence;
@synthesize parentConnection = _parentConnection;

- (void)dealloc
{
    [_parentConnection release];
    [super dealloc];
}

@end

@implementation NSProgress (NSProgressUpdateOverXPC)

- (void)_receiveProgressMessage: (xpc_object_t)message forSequence: (NSUInteger)sequence
{

}

@end
