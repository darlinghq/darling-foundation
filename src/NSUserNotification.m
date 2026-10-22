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

@synthesize identifier = _identifier;
@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize informativeText = _informativeText;
@synthesize actionButtonTitle = _actionButtonTitle;
@synthesize otherButtonTitle = _otherButtonTitle;
@synthesize soundName = _soundName;
@synthesize userInfo = _userInfo;
@synthesize hasActionButton = _hasActionButton;
@synthesize hasReplyButton = _hasReplyButton;

- (void)dealloc {
    [_identifier release];
    [_title release];
    [_subtitle release];
    [_informativeText release];
    [_actionButtonTitle release];
    [_otherButtonTitle release];
    [_soundName release];
    [_userInfo release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSUserNotification *copy = [[NSUserNotification allocWithZone:zone] init];
    copy.identifier = self.identifier;
    copy.title = self.title;
    copy.subtitle = self.subtitle;
    copy.informativeText = self.informativeText;
    copy.actionButtonTitle = self.actionButtonTitle;
    copy.otherButtonTitle = self.otherButtonTitle;
    copy.soundName = self.soundName;
    copy.userInfo = self.userInfo;
    copy.hasActionButton = self.hasActionButton;
    copy.hasReplyButton = self.hasReplyButton;
    return copy;
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

- (instancetype)init {
	self = [super init];
	if (self) {
		_deliveredNotifications = [[NSMutableArray alloc] init];
		_scheduledNotifications = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc {
	[_deliveredNotifications release];
	[_scheduledNotifications release];
	[super dealloc];
}

- (NSArray<NSUserNotification *> *)deliveredNotifications {
	@synchronized (self) {
		return [[_deliveredNotifications copy] autorelease];
	}
}

- (NSArray<NSUserNotification *> *)scheduledNotifications {
	@synchronized (self) {
		return [[_scheduledNotifications copy] autorelease];
	}
}

- (void)deliverNotification:(NSUserNotification *)notification {
	NSLog(@"[NSUserNotificationCenter deliverNotification:] Title: '%@' Text: '%@'", [notification title], [notification informativeText]);
	if (notification) {
		@synchronized (self) {
			[_deliveredNotifications addObject:notification];
		}
	}
}

- (void)removeDeliveredNotification:(NSUserNotification *)notification {
	NSLog(@"[NSUserNotificationCenter removeDeliveredNotification:]");
	if (notification) {
		@synchronized (self) {
			[_deliveredNotifications removeObject:notification];
		}
	}
}

- (void)removeAllDeliveredNotifications {
	NSLog(@"[NSUserNotificationCenter removeAllDeliveredNotifications]");
	@synchronized (self) {
		[_deliveredNotifications removeAllObjects];
	}
}

- (void)scheduleNotification:(NSUserNotification *)notification {
	NSLog(@"[NSUserNotificationCenter scheduleNotification:] Title: '%@'", [notification title]);
	if (notification) {
		@synchronized (self) {
			[_scheduledNotifications addObject:notification];
		}
	}
}

- (void)removeScheduledNotification:(NSUserNotification *)notification {
	NSLog(@"[NSUserNotificationCenter removeScheduledNotification:]");
	if (notification) {
		@synchronized (self) {
			[_scheduledNotifications removeObject:notification];
		}
	}
}

@end

NSString * const NSUserNotificationDefaultSoundName = @"DefaultSoundName";
