/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#import <Foundation/NSNotification.h>
#import <Foundation/NSString.h>

typedef NSString * NSDistributedNotificationCenterType NS_EXTENSIBLE_STRING_ENUM;

FOUNDATION_EXPORT NSDistributedNotificationCenterType const NSLocalNotificationCenterType;

typedef NS_ENUM(NSUInteger, NSNotificationSuspensionBehavior) {
    NSNotificationSuspensionBehaviorDrop = 1,
    NSNotificationSuspensionBehaviorCoalesce = 2,
    NSNotificationSuspensionBehaviorHold = 3,
    NSNotificationSuspensionBehaviorDeliverImmediately = 4
};

typedef NS_OPTIONS(NSUInteger, NSDistributedNotificationOptions) {
    NSDistributedNotificationDeliverImmediately = (1UL << 0),
    NSDistributedNotificationPostToAllSessions = (1UL << 1)
};

@interface NSDistributedNotificationCenter : NSNotificationCenter
{
	BOOL _suspended;
}

@property BOOL suspended;

+ (NSDistributedNotificationCenter *)notificationCenterForType:(NSDistributedNotificationCenterType)notificationCenterType;

+ (NSDistributedNotificationCenter *)defaultCenter;

- (void)addObserver:(id)observer
	selector:(SEL)selector
	name:(NSNotificationName)name
	object:(NSString *)object
	suspensionBehavior:(NSNotificationSuspensionBehavior)suspensionBehavior;

- (void)postNotificationName:(NSNotificationName)name
	object:(NSString *)object
	userInfo:(NSDictionary *)userInfo
	deliverImmediately:(BOOL)deliverImmediately;

- (void)postNotificationName:(NSNotificationName)name
	object:(NSString *)object
	userInfo:(NSDictionary *)userInfo
	options:(NSDistributedNotificationOptions)options;

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName object:(NSString *)anObject;

- (void)postNotificationName:(NSNotificationName)aName object:(NSString *)anObject;

- (void)postNotificationName:(NSNotificationName)aName object:(NSString *)anObject userInfo:(NSDictionary *)aUserInfo;

- (void)removeObserver:(id)observer name:(NSNotificationName)aName object:(NSString *)anObject;

@end
