/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel
 Copyright (C) 2026 Darling developers

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
#import <Foundation/NSDate.h>

typedef NS_ENUM(NSInteger, NSUserNotificationActivationType) {
    NSUserNotificationActivationTypeNone = 0,
    NSUserNotificationActivationTypeContentsClicked = 1,
    NSUserNotificationActivationTypeActionButtonClicked = 2,
    NSUserNotificationActivationTypeReplied = 3,
    NSUserNotificationActivationTypeAdditionalActionClicked = 4
};

@class NSUserNotificationAction;

@interface NSUserNotification : NSObject <NSCopying, NSSecureCoding> {
@package
    NSString *_identifier;
    NSString *_title;
    NSString *_subtitle;
    NSString *_informativeText;
    NSString *_actionButtonTitle;
    NSString *_otherButtonTitle;
    NSString *_soundName;
    NSDictionary *_userInfo;
    NSDate *_deliveryDate;
    NSDate *_actualDeliveryDate;
    BOOL _hasActionButton;
    BOOL _hasReplyButton;
    BOOL _presented;
    BOOL _remote;
    NSUserNotificationActivationType _activationType;
    NSUserNotificationAction *_additionalActivationAction;
    NSArray<NSUserNotificationAction *> *_additionalActions;
}

@property (copy) NSString *identifier;
@property (copy) NSString *title;
@property (copy) NSString *subtitle;
@property (copy) NSString *informativeText;
@property (copy) NSString *actionButtonTitle;
@property (copy) NSString *otherButtonTitle;
@property (copy) NSString *soundName;
@property (copy) NSDictionary *userInfo;
@property (copy) NSDate *deliveryDate;
@property (copy) NSDate *actualDeliveryDate;
@property BOOL hasActionButton;
@property BOOL hasReplyButton;
@property (readonly, getter=isPresented) BOOL presented;
@property (readonly, getter=isRemote) BOOL remote;
@property (readonly) NSUserNotificationActivationType activationType;
@property (readonly, copy) NSUserNotificationAction *additionalActivationAction;
@property (copy) NSArray<NSUserNotificationAction *> *additionalActions;

@end

@interface NSUserNotificationAction : NSObject <NSCopying, NSSecureCoding> {
@package
    NSString *_identifier;
    NSString *_title;
}

+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title;

@property (readonly, copy) NSString *identifier;
@property (readonly, copy) NSString *title;

@end

@class NSUserNotificationCenter;

@protocol NSUserNotificationCenterDelegate <NSObject>
@optional
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification;
- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification;
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification;
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
