//
//  NSProgress.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//
//  Progress trees, unit-count fractions and current-progress handling are an Objective-C port of
//  swift-corelibs-foundation's Progress.swift and ProgressFraction.swift:
//  Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
//  Licensed under Apache License v2.0 with Runtime Library Exception
//  See http://swift.org/LICENSE.txt for license information
//  See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#import <Foundation/NSProgress.h>
#import <Foundation/NSException.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSKeyValueObserving.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <math.h>
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

typedef struct {
    int64_t completed;
    int64_t total;
    BOOL overflowed;
} NSProgressFraction;

static NSProgressFraction fraction(int64_t completed, int64_t total)
{
    return (NSProgressFraction){ completed, total, NO };
}

static BOOL fractionIsIndeterminate(NSProgressFraction f)
{
    return f.completed < 0 || f.total < 0 || (f.completed == 0 && f.total == 0);
}

static BOOL fractionIsFinished(NSProgressFraction f)
{
    return (f.completed >= f.total && f.completed > 0 && f.total > 0) || (f.completed > 0 && f.total == 0);
}

static double fractionValue(NSProgressFraction f)
{
    if (fractionIsIndeterminate(f)) {
        return 0.0;
    }
    if (f.total == 0) {
        return 1.0;
    }
    return (double)f.completed / (double)f.total;
}

// Once exact arithmetic overflows, the fraction is approximated in 1/131072ths.
static NSProgressFraction fractionFromDouble(double value)
{
    const int64_t denominator = 131072;
    return (NSProgressFraction){ (int64_t)(value * denominator), denominator, YES };
}

static int64_t greatestCommonDivisor(int64_t a, int64_t b)
{
    do {
        int64_t tmp = b;
        b = a % b;
        a = tmp;
    } while (b != 0);
    return a;
}

static NSProgressFraction fractionSimplified(NSProgressFraction f)
{
    if (f.total == 0) {
        return f;
    }
    int64_t gcd = greatestCommonDivisor(f.completed, f.total);
    return fraction(f.completed / gcd, f.total / gcd);
}

// A zero-total fraction is weightless: adding or subtracting it leaves the other operand unchanged.
static NSProgressFraction fractionAddOrSubtract(NSProgressFraction lhs, NSProgressFraction rhs, BOOL subtract)
{
    if (lhs.total == 0) {
        return rhs;
    }
    if (rhs.total == 0) {
        return lhs;
    }

    double approximate = subtract ? fractionValue(lhs) - fractionValue(rhs) : fractionValue(lhs) + fractionValue(rhs);
    if (lhs.overflowed || rhs.overflowed) {
        return fractionFromDouble(approximate);
    }

    for (int attempt = 0; attempt < 2; attempt++) {
        NSProgressFraction l = attempt ? fractionSimplified(lhs) : lhs;
        NSProgressFraction r = attempt ? fractionSimplified(rhs) : rhs;
        int64_t lcm, left, right, result;
        if (__builtin_mul_overflow(l.total / greatestCommonDivisor(l.total, r.total), r.total, &lcm) ||
            __builtin_mul_overflow(l.completed, lcm / l.total, &left) ||
            __builtin_mul_overflow(r.completed, lcm / r.total, &right)) {
            continue;
        }
        if (subtract ? __builtin_sub_overflow(left, right, &result) : __builtin_add_overflow(left, right, &result)) {
            continue;
        }
        return fraction(result, lcm);
    }
    return fractionFromDouble(approximate);
}

static NSProgressFraction fractionMultiply(NSProgressFraction lhs, NSProgressFraction rhs)
{
    if (!lhs.overflowed && !rhs.overflowed) {
        for (int attempt = 0; attempt < 2; attempt++) {
            NSProgressFraction l = attempt ? fractionSimplified(lhs) : lhs;
            NSProgressFraction r = attempt ? fractionSimplified(rhs) : rhs;
            int64_t completed, total;
            if (!__builtin_mul_overflow(l.completed, r.completed, &completed) &&
                !__builtin_mul_overflow(l.total, r.total, &total)) {
                return fraction(completed, total);
            }
        }
    }
    return fractionFromDouble(fractionValue(lhs) * fractionValue(rhs));
}

// Zero-total fractions are never equal, so a child's first report always reaches its parent.
static BOOL fractionEqual(NSProgressFraction lhs, NSProgressFraction rhs)
{
    if (lhs.total == 0 || rhs.total == 0) {
        return NO;
    }
    if (lhs.total == rhs.total) {
        return lhs.completed == rhs.completed;
    }
    if (lhs.completed == 0 && rhs.completed == 0) {
        return YES;
    }
    if (lhs.completed == lhs.total && rhs.completed == rhs.total) {
        return YES;
    }
    if ((lhs.completed == 0) != (rhs.completed == 0)) {
        return NO;
    }
    for (int attempt = 0; attempt < 2; attempt++) {
        NSProgressFraction l = attempt ? fractionSimplified(lhs) : lhs;
        NSProgressFraction r = attempt ? fractionSimplified(rhs) : rhs;
        int64_t left, right;
        if (!__builtin_mul_overflow(l.completed, r.total, &left) && !__builtin_mul_overflow(l.total, r.completed, &right)) {
            return left == right;
        }
    }
    return fractionValue(lhs) == fractionValue(rhs);
}

static NSString * const NSProgressCurrentKey = @"NSProgressCurrentKey";

// One entry of the per-thread stack that becomeCurrentWithPendingUnitCount: pushes.
@interface _NSProgressCurrentEntry : NSObject {
@public
    NSProgress *_progress;
    _NSProgressCurrentEntry *_next;
    int64_t _pendingUnitCount;
    BOOL _childAttached;
}
@end

@implementation _NSProgressCurrentEntry

- (void)dealloc
{
    [_progress release];
    [_next release];
    [super dealloc];
}

@end

static _NSProgressCurrentEntry *currentEntry(void)
{
    return [[[NSThread currentThread] threadDictionary] objectForKey: NSProgressCurrentKey];
}

// A single recursive lock for every progress object: updates travel up the tree while cancellation
// travels down, so per-object locks would deadlock.
static NSObject *progressTreeLock;

@implementation NSProgress {
    NSProgress *_parent; // weak, accessed with objc_loadWeak/objc_storeWeak
    NSMutableSet *_children;
    NSProgressFraction _selfFraction;
    NSProgressFraction _childFraction;
    int64_t _portionOfParent;
    NSMutableDictionary *_userInfo;
    NSProgressKind _kind;
    NSString *_localizedDescription;
    NSString *_localizedAdditionalDescription;
    void (^_cancellationHandler)(void);
    void (^_pausingHandler)(void);
    void (^_resumingHandler)(void);
    BOOL _cancelled;
    BOOL _paused;
    BOOL _cancellable;
    BOOL _pausable;
}

@synthesize kind = _kind;

+ (void)initialize
{
    if (self == [NSProgress class]) {
        progressTreeLock = [NSObject new];
    }
}

+ (BOOL)automaticallyNotifiesObserversForKey: (NSString *)key
{
    if ([key isEqualToString: @"completedUnitCount"] || [key isEqualToString: @"totalUnitCount"]) {
        return NO;
    }
    return [super automaticallyNotifiesObserversForKey: key];
}

+ (NSSet *)keyPathsForValuesAffectingLocalizedDescription
{
    return [NSSet setWithObject: @"fractionCompleted"];
}

+ (NSSet *)keyPathsForValuesAffectingLocalizedAdditionalDescription
{
    return [NSSet setWithObjects: @"completedUnitCount", @"totalUnitCount", nil];
}

+ (NSProgress *)currentProgress
{
    _NSProgressCurrentEntry *entry = currentEntry();
    return entry ? entry->_progress : nil;
}

+ (NSProgress *)progressWithTotalUnitCount: (int64_t)unitCount
{
    NSProgress *progress = [[[self alloc] initWithParent: [NSProgress currentProgress] userInfo: nil] autorelease];
    progress.totalUnitCount = unitCount;
    return progress;
}

+ (NSProgress *)discreteProgressWithTotalUnitCount: (int64_t)unitCount
{
    NSProgress *progress = [[[self alloc] initWithParent: nil userInfo: nil] autorelease];
    progress.totalUnitCount = unitCount;
    return progress;
}

+ (NSProgress *)progressWithTotalUnitCount: (int64_t)unitCount parent: (NSProgress *)parent pendingUnitCount: (int64_t)portionOfParentTotalUnitCount
{
    NSProgress *progress = [self discreteProgressWithTotalUnitCount: unitCount];
    [parent addChild: progress withPendingUnitCount: portionOfParentTotalUnitCount];
    return progress;
}

- (instancetype)init
{
    return [self initWithParent: nil userInfo: nil];
}

- (instancetype)initWithParent: (NSProgress *)parent userInfo: (NSDictionary *)userInfo
{
    self = [super init];
    if (!self) {
        return nil;
    }

    _children = [NSMutableSet new];
    _selfFraction = fraction(0, 0);
    // The child fraction's units are irrelevant as long as the total is non-zero.
    _childFraction = fraction(0, 1);
    _userInfo = userInfo ? [userInfo mutableCopy] : [NSMutableDictionary new];

    if (parent) {
        _NSProgressCurrentEntry *entry = currentEntry();
        if (!entry || entry->_progress != parent) {
            [self release];
            [NSException raise: NSInvalidArgumentException format: @"The parent of an NSProgress must be the current progress"];
        }
        // Only the first progress created while the parent is current becomes its implicit child.
        if (!entry->_childAttached) {
            entry->_childAttached = YES;
            [parent addChild: self withPendingUnitCount: entry->_pendingUnitCount];
        }
    }
    return self;
}

- (void)dealloc
{
    objc_storeWeak((id *)&_parent, nil);
    [_children release];
    [_userInfo release];
    [_kind release];
    [_localizedDescription release];
    [_localizedAdditionalDescription release];
    [_cancellationHandler release];
    [_pausingHandler release];
    [_resumingHandler release];
    [super dealloc];
}

- (void)becomeCurrentWithPendingUnitCount: (int64_t)unitCount
{
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    _NSProgressCurrentEntry *previous = [threadDictionary objectForKey: NSProgressCurrentKey];
    if (previous && previous->_progress == self) {
        [NSException raise: NSInternalInconsistencyException format: @"This NSProgress is already current on this thread"];
    }

    _NSProgressCurrentEntry *entry = [_NSProgressCurrentEntry new];
    entry->_progress = [self retain];
    entry->_next = [previous retain];
    entry->_pendingUnitCount = unitCount;
    [threadDictionary setObject: entry forKey: NSProgressCurrentKey];
    [entry release];
}

- (void)resignCurrent
{
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    _NSProgressCurrentEntry *entry = [threadDictionary objectForKey: NSProgressCurrentKey];
    if (!entry || entry->_progress != self) {
        [NSException raise: NSInternalInconsistencyException format: @"This NSProgress is not the current progress on this thread"];
    }

    if (!entry->_childAttached) {
        [self _addCompletedUnitCount: entry->_pendingUnitCount];
    }

    if (entry->_next) {
        [threadDictionary setObject: entry->_next forKey: NSProgressCurrentKey];
    } else {
        [threadDictionary removeObjectForKey: NSProgressCurrentKey];
    }
}

- (void)addChild: (NSProgress *)child withPendingUnitCount: (int64_t)unitCount
{
    @synchronized (progressTreeLock) {
        if (objc_loadWeak((id *)&child->_parent) != nil) {
            [NSException raise: NSInvalidArgumentException format: @"The NSProgress is already the child of another progress"];
        }

        [_children addObject: child];
        objc_storeWeak((id *)&child->_parent, self);
        child->_portionOfParent = unitCount;
        // Report the child's current state; its previous state is "no contribution" (0/0).
        [self _updateChild: child from: fraction(0, 0) to: [child _overallFraction] portion: unitCount];

        if (_cancelled) {
            [child cancel];
        }
        if (_paused) {
            [child pause];
        }
    }
}

- (NSProgressFraction)_overallFraction
{
    return fractionAddOrSubtract(_selfFraction, _childFraction, NO);
}

- (void)_reportChangeFrom: (NSProgressFraction)previous
{
    NSProgressFraction next = [self _overallFraction];
    if (!fractionEqual(previous, next)) {
        [objc_loadWeak((id *)&_parent) _updateChild: self from: previous to: next portion: _portionOfParent];
    }
}

- (void)_updateChild: (NSProgress *)child from: (NSProgressFraction)previous to: (NSProgressFraction)next portion: (int64_t)portion
{
    BOOL finished = fractionIsFinished(next);
    BOOL addsCompletedUnits = finished && portion != 0;

    [self willChangeValueForKey: @"fractionCompleted"];
    if (addsCompletedUnits) {
        [self willChangeValueForKey: @"completedUnitCount"];
    }

    NSProgressFraction overall = [self _overallFraction];
    NSProgressFraction multiple = fraction(portion, _selfFraction.total);

    // Replace the child's previous contribution with its new one; indeterminate states count as zero.
    if (!fractionIsIndeterminate(previous)) {
        _childFraction = fractionAddOrSubtract(_childFraction, fractionMultiply(previous, multiple), YES);
    }
    if (!fractionIsIndeterminate(next)) {
        _childFraction = fractionAddOrSubtract(_childFraction, fractionMultiply(next, multiple), NO);
    }

    if (finished) {
        [[child retain] autorelease];
        [_children removeObject: child];
        if (portion != 0) {
            // A finished child's share moves from the child fraction into our own completed units.
            _selfFraction.completed += portion;
            _childFraction = fractionAddOrSubtract(_childFraction, fractionMultiply(multiple, next), YES);
        }
    }

    [self _reportChangeFrom: overall];

    if (addsCompletedUnits) {
        [self didChangeValueForKey: @"completedUnitCount"];
    }
    [self didChangeValueForKey: @"fractionCompleted"];
}

- (void)_addCompletedUnitCount: (int64_t)unitCount
{
    @synchronized (progressTreeLock) {
        [self setCompletedUnitCount: _selfFraction.completed + unitCount];
    }
}

- (int64_t)totalUnitCount
{
    @synchronized (progressTreeLock) {
        return _selfFraction.total;
    }
}

- (void)setTotalUnitCount: (int64_t)unitCount
{
    @synchronized (progressTreeLock) {
        [self willChangeValueForKey: @"totalUnitCount"];
        [self willChangeValueForKey: @"fractionCompleted"];

        NSProgressFraction previous = [self _overallFraction];
        // Children's shares are measured against our total, so rescale them to the new one.
        if (_selfFraction.total != unitCount && _selfFraction.total > 0 && unitCount > 0) {
            _childFraction = fractionMultiply(_childFraction, fraction(_selfFraction.total, unitCount));
        }
        _selfFraction.total = unitCount;
        [self _reportChangeFrom: previous];

        [self didChangeValueForKey: @"fractionCompleted"];
        [self didChangeValueForKey: @"totalUnitCount"];
    }
}

- (int64_t)completedUnitCount
{
    @synchronized (progressTreeLock) {
        return _selfFraction.completed;
    }
}

- (void)setCompletedUnitCount: (int64_t)unitCount
{
    @synchronized (progressTreeLock) {
        [self willChangeValueForKey: @"completedUnitCount"];
        [self willChangeValueForKey: @"fractionCompleted"];

        NSProgressFraction previous = [self _overallFraction];
        _selfFraction.completed = unitCount;
        [self _reportChangeFrom: previous];

        [self didChangeValueForKey: @"fractionCompleted"];
        [self didChangeValueForKey: @"completedUnitCount"];
    }
}

- (double)fractionCompleted
{
    @synchronized (progressTreeLock) {
        // With no total of our own, children do not count.
        if (_selfFraction.total <= 0) {
            return fractionValue(_selfFraction);
        }
        return fractionValue([self _overallFraction]);
    }
}

- (BOOL)isIndeterminate
{
    @synchronized (progressTreeLock) {
        return fractionIsIndeterminate(_selfFraction);
    }
}

- (BOOL)isFinished
{
    @synchronized (progressTreeLock) {
        return fractionIsFinished(_selfFraction);
    }
}

- (NSString *)localizedDescription
{
    @synchronized (progressTreeLock) {
        if (_localizedDescription) {
            return [[_localizedDescription retain] autorelease];
        }
        if (fractionIsIndeterminate(_selfFraction)) {
            return @"";
        }
        return [NSString stringWithFormat: @"%ld%% completed", lround(self.fractionCompleted * 100.0)];
    }
}

- (void)setLocalizedDescription: (NSString *)description
{
    @synchronized (progressTreeLock) {
        NSString *old = _localizedDescription;
        _localizedDescription = [description copy];
        [old release];
    }
}

- (NSString *)localizedAdditionalDescription
{
    @synchronized (progressTreeLock) {
        if (_localizedAdditionalDescription) {
            return [[_localizedAdditionalDescription retain] autorelease];
        }
        if (fractionIsIndeterminate(_selfFraction)) {
            return @"";
        }
        return [NSString stringWithFormat: @"%lld of %lld", (long long)_selfFraction.completed, (long long)_selfFraction.total];
    }
}

- (void)setLocalizedAdditionalDescription: (NSString *)description
{
    @synchronized (progressTreeLock) {
        NSString *old = _localizedAdditionalDescription;
        _localizedAdditionalDescription = [description copy];
        [old release];
    }
}

- (BOOL)isCancellable
{
    @synchronized (progressTreeLock) {
        return _cancellable;
    }
}

- (void)setCancellable: (BOOL)cancellable
{
    @synchronized (progressTreeLock) {
        _cancellable = cancellable;
    }
}

- (BOOL)isPausable
{
    @synchronized (progressTreeLock) {
        return _pausable;
    }
}

- (void)setPausable: (BOOL)pausable
{
    @synchronized (progressTreeLock) {
        _pausable = pausable;
    }
}

- (BOOL)isCancelled
{
    @synchronized (progressTreeLock) {
        return _cancelled;
    }
}

- (BOOL)isPaused
{
    @synchronized (progressTreeLock) {
        return _paused;
    }
}

static void runHandler(void (^handler)(void))
{
    if (handler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), handler);
    }
}

- (void (^)(void))cancellationHandler
{
    @synchronized (progressTreeLock) {
        return [[_cancellationHandler retain] autorelease];
    }
}

- (void)setCancellationHandler: (void (^)(void))handler
{
    @synchronized (progressTreeLock) {
        [_cancellationHandler release];
        _cancellationHandler = [handler copy];
        // A handler set after cancellation still runs.
        if (_cancelled) {
            runHandler(_cancellationHandler);
        }
    }
}

- (void (^)(void))pausingHandler
{
    @synchronized (progressTreeLock) {
        return [[_pausingHandler retain] autorelease];
    }
}

- (void)setPausingHandler: (void (^)(void))handler
{
    @synchronized (progressTreeLock) {
        [_pausingHandler release];
        _pausingHandler = [handler copy];
        if (_paused) {
            runHandler(_pausingHandler);
        }
    }
}

- (void (^)(void))resumingHandler
{
    @synchronized (progressTreeLock) {
        return [[_resumingHandler retain] autorelease];
    }
}

- (void)setResumingHandler: (void (^)(void))handler
{
    @synchronized (progressTreeLock) {
        [_resumingHandler release];
        _resumingHandler = [handler copy];
    }
}

- (void)cancel
{
    @synchronized (progressTreeLock) {
        if (_cancelled) {
            return;
        }
        [self willChangeValueForKey: @"cancelled"];
        _cancelled = YES;
        [self didChangeValueForKey: @"cancelled"];
        runHandler(_cancellationHandler);
        for (NSProgress *child in [_children allObjects]) {
            [child cancel];
        }
    }
}

- (void)pause
{
    @synchronized (progressTreeLock) {
        if (_paused) {
            return;
        }
        [self willChangeValueForKey: @"paused"];
        _paused = YES;
        [self didChangeValueForKey: @"paused"];
        runHandler(_pausingHandler);
        for (NSProgress *child in [_children allObjects]) {
            [child pause];
        }
    }
}

- (void)resume
{
    @synchronized (progressTreeLock) {
        if (!_paused) {
            return;
        }
        [self willChangeValueForKey: @"paused"];
        _paused = NO;
        [self didChangeValueForKey: @"paused"];
        runHandler(_resumingHandler);
        for (NSProgress *child in [_children allObjects]) {
            [child resume];
        }
    }
}

- (NSDictionary *)userInfo
{
    @synchronized (progressTreeLock) {
        return [[_userInfo copy] autorelease];
    }
}

- (void)setUserInfoObject: (id)object forKey: (NSProgressUserInfoKey)key
{
    @synchronized (progressTreeLock) {
        [self willChangeValueForKey: @"userInfo"];
        if (object) {
            [_userInfo setObject: object forKey: key];
        } else {
            [_userInfo removeObjectForKey: key];
        }
        [self didChangeValueForKey: @"userInfo"];
    }
}

- (NSNumber *)estimatedTimeRemaining
{
    return [[self userInfo] objectForKey: NSProgressEstimatedTimeRemainingKey];
}

- (void)setEstimatedTimeRemaining: (NSNumber *)value
{
    [self setUserInfoObject: value forKey: NSProgressEstimatedTimeRemainingKey];
}

- (NSNumber *)throughput
{
    return [[self userInfo] objectForKey: NSProgressThroughputKey];
}

- (void)setThroughput: (NSNumber *)value
{
    [self setUserInfoObject: value forKey: NSProgressThroughputKey];
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
