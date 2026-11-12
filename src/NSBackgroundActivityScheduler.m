/*
 This file is part of Darling.

 Copyright (C) 2026 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/NSBackgroundActivityScheduler.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <dispatch/dispatch.h>

// The activity is run from a dispatch timer. A run is due one interval after
// scheduling (and after each completed run), and may happen anywhere within
// the tolerance before or after that nominal time.
//
// All mutable state is guarded by @synchronized(self); the user's block runs
// on a private serial queue outside the lock.
@implementation NSBackgroundActivityScheduler

static qos_class_t QOSClassForQualityOfService(NSQualityOfService qos)
{
    switch (qos)
    {
        case NSQualityOfServiceUserInteractive: return QOS_CLASS_USER_INTERACTIVE;
        case NSQualityOfServiceUserInitiated: return QOS_CLASS_USER_INITIATED;
        case NSQualityOfServiceUtility: return QOS_CLASS_UTILITY;
        case NSQualityOfServiceBackground: return QOS_CLASS_BACKGROUND;
        default: return QOS_CLASS_DEFAULT;
    }
}

// Plain -init is refused (the identifier is mandatory), so it does not delegate
// to the designated initializer.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init
{
    [self release];
    [NSException raise:NSInvalidArgumentException format:@"Use -initWithIdentifier:"];
    return nil;
}
#pragma clang diagnostic pop

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    if (![identifier isKindOfClass:[NSString class]] || [identifier length] == 0)
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"The identifier should be a reverse-DNS style string, for example com.mycompany.myapp.activity_name"];
        return nil;
    }
    self = [super init];
    if (self)
    {
        _identifier = [identifier copy];
        _qualityOfService = NSQualityOfServiceBackground;
    }
    return self;
}

- (void)dealloc
{
    if (_timer != NULL)
    {
        dispatch_source_cancel(_timer);
        dispatch_release(_timer);
    }
    if (_queue != NULL)
    {
        dispatch_release(_queue);
    }
    [_block release];
    [_identifier release];
    [super dealloc];
}

- (NSString *)identifier
{
    return [[_identifier retain] autorelease];
}

- (NSQualityOfService)qualityOfService
{
    @synchronized (self) { return _qualityOfService; }
}

- (void)setQualityOfService:(NSQualityOfService)qualityOfService
{
    @synchronized (self) { _qualityOfService = qualityOfService; }
}

- (BOOL)repeats
{
    @synchronized (self) { return _repeats; }
}

- (void)setRepeats:(BOOL)repeats
{
    @synchronized (self) { _repeats = repeats; }
}

- (NSTimeInterval)interval
{
    @synchronized (self) { return _interval; }
}

- (void)setInterval:(NSTimeInterval)interval
{
    if (!(interval >= 1))
    {
        [NSException raise:NSInvalidArgumentException format:@"%@: Invalid value for interval (%f). The value must be >= 1.", self, interval];
    }
    @synchronized (self) { _interval = interval; }
}

- (NSTimeInterval)tolerance
{
    @synchronized (self) { return _tolerance; }
}

- (void)setTolerance:(NSTimeInterval)tolerance
{
    if (!(tolerance >= 0))
    {
        [NSException raise:NSInvalidArgumentException format:@"%@: Invalid value for tolerance (%f). The value must be >= 0.", self, tolerance];
    }
    @synchronized (self) { _tolerance = tolerance; }
}

- (BOOL)shouldDefer
{
    BOOL executing;
    @synchronized (self) { executing = _executing; }
    if (!executing)
    {
        [NSException raise:NSRangeException format:@"*** -[NSBackgroundActivityScheduler shouldDefer]: This method may only be called during the invocation of the activity block or asynchronous activity"];
    }
    // No system conditions (power source, thermal state) are tracked, so deferral is never recommended.
    return NO;
}

- (void)invalidate
{
    dispatch_source_t timer;
    @synchronized (self)
    {
        _generation++;
        timer = _timer;
        _timer = NULL;
        [_block release];
        _block = nil;
    }
    if (timer != NULL)
    {
        dispatch_source_cancel(timer);
        dispatch_release(timer);
    }
}

// Arms a one-shot timer for the next run. Called with the lock held.
- (void)_armTimerForGeneration:(NSUInteger)generation
{
    if (_timer != NULL)
    {
        dispatch_source_cancel(_timer);
        dispatch_release(_timer);
        _timer = NULL;
    }

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
    dispatch_source_set_event_handler(timer, ^{
        [self _fireForGeneration:generation];
    });

    // A run may happen from tolerance before the nominal time to tolerance after it.
    NSTimeInterval earliest = _interval - _tolerance;
    if (earliest < 0)
    {
        earliest = 0;
    }
    dispatch_source_set_timer(timer,
                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(earliest * NSEC_PER_SEC)),
                              DISPATCH_TIME_FOREVER,
                              (uint64_t)(_tolerance * 2 * NSEC_PER_SEC));
    _timer = timer;
    dispatch_resume(timer);
}

- (void)_fireForGeneration:(NSUInteger)generation
{
    void (^block)(NSBackgroundActivityCompletionHandler);
    @synchronized (self)
    {
        if (generation != _generation || _block == nil)
        {
            return;
        }
        block = [_block retain];
        _executing = YES;
    }

    __block BOOL completed = NO;
    NSBackgroundActivityCompletionHandler completion = ^(NSBackgroundActivityResult result) {
        @synchronized (self)
        {
            if (completed)
            {
                return;
            }
            completed = YES;
            _executing = NO;
            if (generation != _generation)
            {
                return; // invalidated or rescheduled while the activity ran
            }
            if (result == NSBackgroundActivityResultDeferred || _repeats)
            {
                [self _armTimerForGeneration:generation];
            }
        }
    };
    completion = [[completion copy] autorelease];

    block(completion);
    [block release];
}

- (void)scheduleWithBlock:(void (^)(NSBackgroundActivityCompletionHandler))block
{
    if (block == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"*** -[NSBackgroundActivityScheduler scheduleWithBlock:]: block is nil"];
    }

    NSTimeInterval interval = [self interval];
    NSTimeInterval tolerance = [self tolerance];
    // QUIRK: with an interval set, a tolerance that comes closer than half a
    // second to the interval is refused when scheduling, with
    // NSInvalidArgumentException; setting the tolerance itself is accepted.
    // Not documented. Evidence: black-box observation on macOS 27 (tier 2),
    // accepted up to interval-0.5 inclusive (10/9.5, 100/99.5) and refused
    // beyond it (10/9.51, 2/1.9, 1/0.51); an unset interval is never checked.
    // Probe: vd-upstream/mac-probes/v400-bgactivity-validation.m
    // Test: test_quirk_tolerance_must_leave_half_second in tests/nsbackgroundactivityscheduler.m
    if (interval > 0 && tolerance > interval - 0.5)
    {
        [NSException raise:NSInvalidArgumentException format:@"%@: Invalid value for tolerance (%f). The value must be less than the interval.", self, tolerance];
    }

    block = [[block copy] autorelease];
    dispatch_source_t oldTimer;
    @synchronized (self)
    {
        oldTimer = _timer;
        _timer = NULL;
        _generation++;
        [_block release];
        _block = [block retain];
        if (_queue != NULL)
        {
            dispatch_release(_queue);
        }
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOSClassForQualityOfService(_qualityOfService), 0);
        _queue = dispatch_queue_create([[@"org.darlinghq.Foundation.NSBackgroundActivityScheduler." stringByAppendingString:_identifier] UTF8String], attr);
        [self _armTimerForGeneration:_generation];
    }
    if (oldTimer != NULL)
    {
        dispatch_source_cancel(oldTimer);
        dispatch_release(oldTimer);
    }
}

@end
