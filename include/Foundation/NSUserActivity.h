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

#import <Foundation/NSObject.h>

@class NSString, NSDictionary, NSSet<ObjectType>, NSURL, NSDate, NSError, NSInputStream, NSOutputStream;
@protocol NSUserActivityDelegate;

NS_ASSUME_NONNULL_BEGIN

typedef NSString *NSUserActivityPersistentIdentifier;

FOUNDATION_EXPORT NSString * const NSUserActivityTypeBrowsingWeb;

@interface NSUserActivity : NSObject
{
    NSString *_activityType;
    NSString *_title;
    NSDictionary *_userInfo;
    NSSet *_requiredUserInfoKeys;
    NSURL *_webpageURL;
    NSURL *_referrerURL;
    NSDate *_expirationDate;
    NSSet *_keywords;
    BOOL _supportsContinuationStreams;
    id _delegate;
    NSString *_targetContentIdentifier;
    NSUserActivityPersistentIdentifier _persistentIdentifier;
    BOOL _eligibleForHandoff;
    BOOL _eligibleForSearch;
    BOOL _eligibleForPublicIndexing;
    BOOL _eligibleForPrediction;
    BOOL _needsSave;
    BOOL _invalidated;
    BOOL _saveScheduled;
}

- (instancetype)initWithActivityType:(NSString *)activityType NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

@property (readonly, copy) NSString *activityType;
@property (nullable, copy) NSString *title;
@property (nullable, copy) NSDictionary *userInfo;
- (void)addUserInfoEntriesFromDictionary:(NSDictionary *)otherDictionary;
@property (nullable, copy) NSSet<NSString *> *requiredUserInfoKeys;
@property BOOL needsSave;
@property (nullable, copy) NSURL *webpageURL;
@property (nullable, copy) NSURL *referrerURL;
@property (nullable, copy) NSDate *expirationDate;
@property (copy) NSSet<NSString *> *keywords;
@property BOOL supportsContinuationStreams;
@property (nullable, weak) id<NSUserActivityDelegate> delegate;
@property (nullable, copy) NSString *targetContentIdentifier;
@property (nullable, copy) NSUserActivityPersistentIdentifier persistentIdentifier;

@property (getter=isEligibleForHandoff) BOOL eligibleForHandoff;
@property (getter=isEligibleForSearch) BOOL eligibleForSearch;
@property (getter=isEligibleForPublicIndexing) BOOL eligibleForPublicIndexing;
@property (getter=isEligibleForPrediction) BOOL eligibleForPrediction;

- (void)becomeCurrent;
- (void)resignCurrent;
- (void)invalidate;

- (void)getContinuationStreamsWithCompletionHandler:(void (^)(NSInputStream * _Nullable inputStream, NSOutputStream * _Nullable outputStream, NSError * _Nullable error))completionHandler;

@end

@protocol NSUserActivityDelegate <NSObject>
@optional

- (void)userActivityWillSave:(NSUserActivity *)userActivity;
- (void)userActivityWasContinued:(NSUserActivity *)userActivity;
- (void)userActivity:(NSUserActivity *)userActivity didReceiveInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream;

@end

NS_ASSUME_NONNULL_END
