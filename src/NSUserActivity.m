/*
 This file is part of Darling.

 Copyright (C) 2025 Darling Developers

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

#import <Foundation/NSUserActivity.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSException.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import <Foundation/FoundationErrors.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>

NSString * const NSUserActivityTypeBrowsingWeb = @"NSUserActivityTypeBrowsingWeb";

// The process-wide current activity; guarded by @synchronized([NSUserActivity class]).
static NSUserActivity *currentActivity = nil;

@implementation NSUserActivity

@synthesize activityType = _activityType;
@synthesize title = _title;
@synthesize userInfo = _userInfo;
@synthesize requiredUserInfoKeys = _requiredUserInfoKeys;
@synthesize webpageURL = _webpageURL;
@synthesize referrerURL = _referrerURL;
@synthesize expirationDate = _expirationDate;
@synthesize keywords = _keywords;
@synthesize supportsContinuationStreams = _supportsContinuationStreams;
@synthesize targetContentIdentifier = _targetContentIdentifier;
@synthesize persistentIdentifier = _persistentIdentifier;
@synthesize eligibleForHandoff = _eligibleForHandoff;
@synthesize eligibleForSearch = _eligibleForSearch;
@synthesize eligibleForPublicIndexing = _eligibleForPublicIndexing;
@synthesize eligibleForPrediction = _eligibleForPrediction;

- (instancetype)initWithActivityType:(NSString *)activityType
{
    if (activityType == nil)
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"-[NSUserActivity initWithActivityType:] requires a non-nil activity type"];
    }
    self = [super init];
    if (self != nil)
    {
        _activityType = [activityType copy];
        _keywords = [[NSSet alloc] init];
        _eligibleForHandoff = YES;
    }
    return self;
}

// Documented to use the first entry of the main bundle's NSUserActivityTypes.
- (instancetype)init
{
    id types = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSUserActivityTypes"];
    if (![types isKindOfClass:[NSArray class]] || [types count] == 0 || ![[types objectAtIndex:0] isKindOfClass:[NSString class]])
    {
        [self release];
        [NSException raise:NSInternalInconsistencyException format:@"-[NSUserActivity init] requires an NSUserActivityTypes array in the main bundle's Info.plist; use -initWithActivityType:"];
    }
    return [self initWithActivityType:[types objectAtIndex:0]];
}

- (void)dealloc
{
    objc_storeWeak(&_delegate, nil);
    [_activityType release];
    [_title release];
    [_userInfo release];
    [_requiredUserInfoKeys release];
    [_webpageURL release];
    [_referrerURL release];
    [_expirationDate release];
    [_keywords release];
    [_targetContentIdentifier release];
    [_persistentIdentifier release];
    [super dealloc];
}

- (void)addUserInfoEntriesFromDictionary:(NSDictionary *)otherDictionary
{
    @synchronized(self)
    {
        NSMutableDictionary *merged = [_userInfo mutableCopy] ?: [[NSMutableDictionary alloc] init];
        [merged addEntriesFromDictionary:otherDictionary];
        [_userInfo release];
        _userInfo = [merged copy];
        [merged release];
    }
}

- (id<NSUserActivityDelegate>)delegate
{
    return objc_loadWeak(&_delegate);
}

- (void)setDelegate:(id<NSUserActivityDelegate>)delegate
{
    objc_storeWeak(&_delegate, delegate);
}

- (BOOL)needsSave
{
    @synchronized(self)
    {
        return _needsSave;
    }
}

- (void)setNeedsSave:(BOOL)needsSave
{
    @synchronized(self)
    {
        _needsSave = needsSave;
    }
    if (needsSave)
        [self _scheduleSaveIfCurrent];
}

- (BOOL)_isCurrent
{
    @synchronized([NSUserActivity class])
    {
        return currentActivity == self;
    }
}

// Repeated needsSave requests coalesce into one save on the main queue.
- (void)_scheduleSaveIfCurrent
{
    @synchronized(self)
    {
        if (!_needsSave || _invalidated || _saveScheduled || ![self _isCurrent])
            return;
        _saveScheduled = YES;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _save];
    });
}

- (void)_save
{
    @synchronized(self)
    {
        _saveScheduled = NO;
        if (!_needsSave || _invalidated || ![self _isCurrent])
            return;
    }
    @autoreleasepool
    {
        id<NSUserActivityDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(userActivityWillSave:)])
            [delegate userActivityWillSave:self];
    }
    self.needsSave = NO;
}

- (void)becomeCurrent
{
    NSUserActivity *previous;
    @synchronized(self)
    {
        if (_invalidated)
            return;
        @synchronized([NSUserActivity class])
        {
            previous = currentActivity;
            currentActivity = [self retain];
        }
    }
    [previous release];
    [self _scheduleSaveIfCurrent];
}

- (void)resignCurrent
{
    BOOL wasCurrent = NO;
    @synchronized([NSUserActivity class])
    {
        if (currentActivity == self)
        {
            currentActivity = nil;
            wasCurrent = YES;
        }
    }
    if (wasCurrent)
        [self release];
}

- (void)invalidate
{
    @synchronized(self)
    {
        _invalidated = YES;
    }
    [self resignCurrent];
}

// Darling has no Handoff service, so no activity is ever continued from another device.
- (void)getContinuationStreamsWithCompletionHandler:(void (^)(NSInputStream *, NSOutputStream *, NSError *))completionHandler
{
    NSDictionary *info = @{ NSLocalizedDescriptionKey: @"Continuation streams are unavailable: Handoff is not supported on this system." };
    NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFeatureUnsupportedError userInfo:info];
    completionHandler(nil, nil, error);
}

@end
