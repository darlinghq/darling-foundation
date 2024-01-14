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

#import <Foundation/NSUserNotification.h>

@implementation NSUserNotification

- (id)copyWithZone:(NSZone *)zone
{
	NSLog(@"[NSUserNotification copyWithZone:]");
	return nil;
}

@end

@implementation NSUserNotificationAction

- (id)copyWithZone:(NSZone *)zone
{
	NSLog(@"[NSUserNotificationAction copyWithZone:]");
	return nil;
}

@end

@implementation NSUserNotificationCenter

static NSUserNotificationCenter *_defaultUserNotificationCenter = nil;

@synthesize delegate = _delegate;

+ (NSUserNotificationCenter *)defaultUserNotificationCenter {
	if (_defaultUserNotificationCenter == nil) {
		_defaultUserNotificationCenter = [[NSUserNotificationCenter alloc] init];
	}

	return _defaultUserNotificationCenter;
}

- (void)deliverNotification:(NSUserNotification *)notification {
	NSLog(@"[NSUserNotificationCenter deliverNotification:]");
}

- (void)removeDeliveredNotification:(NSUserNotification *)notification {
	NSLog(@"[NSUserNotificationCenter removeDeliveredNotification:]");
}

@end

NSString * const NSUserNotificationDefaultSoundName = @"DefaultSoundName";
