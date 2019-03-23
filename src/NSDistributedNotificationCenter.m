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

#import <NSDistributedNotificationCenter.h>

@implementation NSDistributedNotificationCenter

+ (NSDistributedNotificationCenter *)notificationCenterForType:(NSDistributedNotificationCenterType)notificationCenterType
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
	return nil;
}

+ (NSDistributedNotificationCenter *)defaultCenter
{
	return nil;
}

- (void)addObserver:(id)observer
	selector:(SEL)selector
	name:(NSNotificationName)name
	object:(NSString *)object
	suspensionBehavior:(NSNotificationSuspensionBehavior)suspensionBehavior
{
	NSLog(@"-[NSDistributedNotificationCenter addObserver:selector:name:object:suspensionBehavior:");
}

- (void)postNotificationName:(NSNotificationName)name
	object:(NSString *)object
	userInfo:(NSDictionary *)userInfo
	deliverImmediately:(BOOL)deliverImmediately
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)postNotificationName:(NSNotificationName)name
	object:(NSString *)object
	userInfo:(NSDictionary *)userInfo
	options:(NSDistributedNotificationOptions)options
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
}


- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName object:(NSString *)anObject
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)postNotificationName:(NSNotificationName)aName object:(NSString *)anObject
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)postNotificationName:(NSNotificationName)aName object:(NSString *)anObject userInfo:(NSDictionary *)aUserInfo
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)removeObserver:(id)observer name:(NSNotificationName)aName object:(NSString *)anObject
{
	NSLog(@"%s", __PRETTY_FUNCTION__);
}

@end
