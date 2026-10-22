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

#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>

@interface NSUserNotification : NSObject <NSCopying> {
@package
    NSString *_identifier;
    NSString *_title;
    NSString *_subtitle;
    NSString *_informativeText;
    NSString *_actionButtonTitle;
    NSString *_otherButtonTitle;
    NSString *_soundName;
    NSDictionary *_userInfo;
    BOOL _hasActionButton;
    BOOL _hasReplyButton;
}

@property (copy) NSString *identifier;
@property (copy) NSString *title;
@property (copy) NSString *subtitle;
@property (copy) NSString *informativeText;
@property (copy) NSString *actionButtonTitle;
@property (copy) NSString *otherButtonTitle;
@property (copy) NSString *soundName;
@property (copy) NSDictionary *userInfo;
@property BOOL hasActionButton;
@property BOOL hasReplyButton;

@end

@interface NSUserNotificationAction : NSObject <NSCopying>
@end

@protocol NSUserNotificationCenterDelegate <NSObject>
@end

@interface NSUserNotificationCenter : NSObject {
    id<NSUserNotificationCenterDelegate> _delegate;
    NSMutableArray<NSUserNotification *> *_deliveredNotifications;
    NSMutableArray<NSUserNotification *> *_scheduledNotifications;
}

@property(class, readonly, strong) NSUserNotificationCenter *defaultUserNotificationCenter;
@property(assign) id<NSUserNotificationCenterDelegate> delegate;
@property(readonly, copy) NSArray<NSUserNotification *> *deliveredNotifications;
@property(readonly, copy) NSArray<NSUserNotification *> *scheduledNotifications;

- (void)deliverNotification:(NSUserNotification *)notification;
- (void)removeDeliveredNotification:(NSUserNotification *)notification;
- (void)removeAllDeliveredNotifications;
- (void)scheduleNotification:(NSUserNotification *)notification;
- (void)removeScheduledNotification:(NSUserNotification *)notification;

@end

FOUNDATION_EXPORT NSString * const NSUserNotificationDefaultSoundName;
