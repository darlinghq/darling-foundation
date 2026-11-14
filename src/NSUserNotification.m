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

#import <Foundation/NSUserNotification.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSUUID.h>
#import <Foundation/NSCoder.h>

#include <xpc/xpc.h>
#include <dispatch/dispatch.h>

#define USERNOTED_MACH_SERVICE "com.apple.usernoted"
#define USERNOTED_SERVICE_ENV "__USERNOTED_SERVICE_NAME"

#define UN_KEY_OP "darling-op"
#define UN_KEY_ERR "err"
#define UN_KEY_BUNDLE_ID "bundle-id"
#define UN_KEY_BUNDLE_PATH "bundle-path"
#define UN_KEY_EXEC_PATH "exec-path"
#define UN_KEY_NOTIFICATION_ID "notification-id"
#define UN_KEY_TITLE "title"
#define UN_KEY_SUBTITLE "subtitle"
#define UN_KEY_BODY "body"
#define UN_KEY_ACTIONS "actions"
#define UN_KEY_SOUND_FILE "sound-file"
#define UN_KEY_IS_NSUSER "is-nsuser"
#define UN_KEY_TRIGGER_TYPE "trigger-type"
#define UN_KEY_FIRE_DATE "fire-date"
#define UN_KEY_ACTION_KEY "action-key"
#define UN_KEY_IDENTIFIERS "identifiers"

#define UN_OP_CHECKIN "checkin"
#define UN_OP_POST "post"
#define UN_OP_REMOVE_DELIVERED "remove-delivered"
#define UN_OP_REMOVE_ALL_DELIVERED "remove-all-delivered"
#define UN_OP_REMOVE_PENDING "remove-pending"
#define UN_OP_ACTION_INVOKED "action-invoked"

@implementation NSUserNotification

@synthesize identifier = _identifier;
@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize informativeText = _informativeText;
@synthesize actionButtonTitle = _actionButtonTitle;
@synthesize otherButtonTitle = _otherButtonTitle;
@synthesize soundName = _soundName;
@synthesize userInfo = _userInfo;
@synthesize deliveryDate = _deliveryDate;
@synthesize actualDeliveryDate = _actualDeliveryDate;
@synthesize hasActionButton = _hasActionButton;
@synthesize hasReplyButton = _hasReplyButton;
@synthesize presented = _presented;
@synthesize remote = _remote;
@synthesize activationType = _activationType;
@synthesize additionalActivationAction = _additionalActivationAction;
@synthesize additionalActions = _additionalActions;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _hasActionButton = YES;
        _actionButtonTitle = [@"Show" retain];
        _otherButtonTitle = [@"Close" retain];
    }
    return self;
}

- (void)dealloc {
    [_identifier release];
    [_title release];
    [_subtitle release];
    [_informativeText release];
    [_actionButtonTitle release];
    [_otherButtonTitle release];
    [_soundName release];
    [_userInfo release];
    [_deliveryDate release];
    [_actualDeliveryDate release];
    [_additionalActivationAction release];
    [_additionalActions release];
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
    copy.deliveryDate = self.deliveryDate;
    copy.actualDeliveryDate = self.actualDeliveryDate;
    copy.hasActionButton = self.hasActionButton;
    copy.hasReplyButton = self.hasReplyButton;
    copy->_presented = self.presented;
    copy->_remote = self.remote;
    copy->_activationType = self.activationType;
    copy->_additionalActivationAction = [self.additionalActivationAction copyWithZone:zone];
    copy.additionalActions = self.additionalActions;
    return copy;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_title forKey:@"title"];
    [coder encodeObject:_subtitle forKey:@"subtitle"];
    [coder encodeObject:_informativeText forKey:@"informativeText"];
    [coder encodeObject:_actionButtonTitle forKey:@"actionButtonTitle"];
    [coder encodeObject:_otherButtonTitle forKey:@"otherButtonTitle"];
    [coder encodeObject:_soundName forKey:@"soundName"];
    [coder encodeObject:_deliveryDate forKey:@"deliveryDate"];
    [coder encodeObject:_actualDeliveryDate forKey:@"actualDeliveryDate"];
    [coder encodeObject:_additionalActions forKey:@"additionalActions"];
    [coder encodeBool:_hasActionButton forKey:@"hasActionButton"];
    [coder encodeBool:_hasReplyButton forKey:@"hasReplyButton"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _identifier = [[coder decodeObjectForKey:@"identifier"] copy];
        _title = [[coder decodeObjectForKey:@"title"] copy];
        _subtitle = [[coder decodeObjectForKey:@"subtitle"] copy];
        _informativeText = [[coder decodeObjectForKey:@"informativeText"] copy];
        _actionButtonTitle = [[coder decodeObjectForKey:@"actionButtonTitle"] copy];
        _otherButtonTitle = [[coder decodeObjectForKey:@"otherButtonTitle"] copy];
        _soundName = [[coder decodeObjectForKey:@"soundName"] copy];
        _deliveryDate = [[coder decodeObjectForKey:@"deliveryDate"] copy];
        _actualDeliveryDate = [[coder decodeObjectForKey:@"actualDeliveryDate"] copy];
        _additionalActions = [[coder decodeObjectForKey:@"additionalActions"] copy];
        _hasActionButton = [coder decodeBoolForKey:@"hasActionButton"];
        _hasReplyButton = [coder decodeBoolForKey:@"hasReplyButton"];
    }
    return self;
}

@end

@implementation NSUserNotificationAction

@synthesize identifier = _identifier;
@synthesize title = _title;

+ (instancetype)actionWithIdentifier:(NSString *)identifier title:(NSString *)title
{
    NSUserNotificationAction *action = [[[self alloc] init] autorelease];
    action->_identifier = [identifier copy];
    action->_title = [title copy];
    return action;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_identifier forKey:@"identifier"];
    [coder encodeObject:_title forKey:@"title"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _identifier = [[coder decodeObjectForKey:@"identifier"] copy];
        _title = [[coder decodeObjectForKey:@"title"] copy];
    }
    return self;
}

- (void)dealloc
{
    [_identifier release];
    [_title release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSUserNotificationAction *copy = [[[self class] allocWithZone:zone] init];
    copy->_identifier = [self.identifier copyWithZone:zone];
    copy->_title = [self.title copyWithZone:zone];
    return copy;
}

@end

@implementation NSUserNotificationCenter

static NSUserNotificationCenter *_defaultUserNotificationCenter = nil;
static xpc_connection_t s_foundation_usernoted_conn = NULL;
static dispatch_once_t s_foundation_conn_once;

@synthesize delegate = _delegate;

static void handle_foundation_daemon_message(xpc_object_t msg)
{
    const char *op = xpc_dictionary_get_string(msg, UN_KEY_OP);
    if (!op || strcmp(op, UN_OP_ACTION_INVOKED) != 0)
        return;

    const char *ident = xpc_dictionary_get_string(msg, UN_KEY_NOTIFICATION_ID);
    const char *action_key = xpc_dictionary_get_string(msg, UN_KEY_ACTION_KEY);
    const char *title = xpc_dictionary_get_string(msg, UN_KEY_TITLE);
    const char *subtitle = xpc_dictionary_get_string(msg, UN_KEY_SUBTITLE);
    const char *body = xpc_dictionary_get_string(msg, UN_KEY_BODY);

    NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
    NSString *notification_id = ident ? [NSString stringWithUTF8String:ident] : @"";

    NSUserNotification *found = nil;
    @synchronized (center) {
        for (NSUserNotification *n in center->_deliveredNotifications) {
            if ([n.identifier isEqualToString:notification_id]) {
                found = [[n copy] autorelease];
                break;
            }
        }
    }

    if (!found) {
        found = [[[NSUserNotification alloc] init] autorelease];
        found.identifier = notification_id;
        if (title) found.title = [NSString stringWithUTF8String:title];
        if (subtitle) found.subtitle = [NSString stringWithUTF8String:subtitle];
        if (body) found.informativeText = [NSString stringWithUTF8String:body];
    }

    if (!action_key || strcmp(action_key, "default") == 0) {
        found->_activationType = NSUserNotificationActivationTypeContentsClicked;
    } else if (found.actionButtonTitle && [found.actionButtonTitle isEqualToString:[NSString stringWithUTF8String:action_key]]) {
        found->_activationType = NSUserNotificationActivationTypeActionButtonClicked;
    } else {
        found->_activationType = NSUserNotificationActivationTypeAdditionalActionClicked;
        found->_additionalActivationAction = [[NSUserNotificationAction actionWithIdentifier:[NSString stringWithUTF8String:action_key]
                                                                                       title:[NSString stringWithUTF8String:action_key]] retain];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        id<NSUserNotificationCenterDelegate> del = center.delegate;
        if ([del respondsToSelector:@selector(userNotificationCenter:didActivateNotification:)]) {
            [del userNotificationCenter:center didActivateNotification:found];
        }
    });
}

static xpc_connection_t get_foundation_usernoted_conn(void)
{
    dispatch_once(&s_foundation_conn_once, ^{
        const char *service_name = getenv(USERNOTED_SERVICE_ENV);
        if (!service_name)
            service_name = USERNOTED_MACH_SERVICE;

        s_foundation_usernoted_conn = xpc_connection_create_mach_service(service_name,
            NULL, 0);

        xpc_connection_set_event_handler(s_foundation_usernoted_conn, ^(xpc_object_t event) {
            if (xpc_get_type(event) == XPC_TYPE_DICTIONARY) {
                handle_foundation_daemon_message(event);
            }
        });
        xpc_connection_resume(s_foundation_usernoted_conn);

        NSBundle *bundle = [NSBundle mainBundle];
        NSString *bid = [bundle bundleIdentifier] ? [bundle bundleIdentifier] : [[NSProcessInfo processInfo] processName];
        NSString *bpath = [bundle bundlePath];
        NSString *epath = [bundle executablePath];

        xpc_object_t checkin = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(checkin, UN_KEY_OP, UN_OP_CHECKIN);
        if (bid) xpc_dictionary_set_string(checkin, UN_KEY_BUNDLE_ID, [bid UTF8String]);
        if (bpath) xpc_dictionary_set_string(checkin, UN_KEY_BUNDLE_PATH, [bpath UTF8String]);
        if (epath) xpc_dictionary_set_string(checkin, UN_KEY_EXEC_PATH, [epath UTF8String]);

        xpc_connection_send_message(s_foundation_usernoted_conn, checkin);
        xpc_release(checkin);
    });

    return s_foundation_usernoted_conn;
}

+ (NSUserNotificationCenter *)defaultUserNotificationCenter {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_defaultUserNotificationCenter = [[NSUserNotificationCenter alloc] init];
	});
	return _defaultUserNotificationCenter;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		_deliveredNotifications = [[NSMutableArray alloc] init];
		_scheduledNotifications = [[NSMutableArray alloc] init];
		get_foundation_usernoted_conn();
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
	if (!notification)
		return;

	if (!notification.identifier) {
		notification.identifier = [[NSUUID UUID] UUIDString];
	}
	notification->_actualDeliveryDate = [[NSDate date] retain];
	notification->_presented = YES;

	@synchronized (self) {
		[_deliveredNotifications addObject:notification];
	}

	xpc_connection_t conn = get_foundation_usernoted_conn();
	xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_string(msg, UN_KEY_OP, UN_OP_POST);
	xpc_dictionary_set_bool(msg, UN_KEY_IS_NSUSER, true);

	NSBundle *bundle = [NSBundle mainBundle];
	NSString *bid = [bundle bundleIdentifier] ? [bundle bundleIdentifier] : [[NSProcessInfo processInfo] processName];
	if (bid) xpc_dictionary_set_string(msg, UN_KEY_BUNDLE_ID, [bid UTF8String]);
	if (notification.identifier) xpc_dictionary_set_string(msg, UN_KEY_NOTIFICATION_ID, [notification.identifier UTF8String]);
	if (notification.title) xpc_dictionary_set_string(msg, UN_KEY_TITLE, [notification.title UTF8String]);
	if (notification.subtitle) xpc_dictionary_set_string(msg, UN_KEY_SUBTITLE, [notification.subtitle UTF8String]);
	if (notification.informativeText) xpc_dictionary_set_string(msg, UN_KEY_BODY, [notification.informativeText UTF8String]);
	if (notification.soundName) xpc_dictionary_set_string(msg, UN_KEY_SOUND_FILE, [notification.soundName UTF8String]);

	if (notification.hasActionButton && notification.actionButtonTitle) {
		xpc_object_t act_arr = xpc_array_create(NULL, 0);
		xpc_array_set_string(act_arr, XPC_ARRAY_APPEND, [notification.actionButtonTitle UTF8String]);
		xpc_array_set_string(act_arr, XPC_ARRAY_APPEND, [notification.actionButtonTitle UTF8String]);

		for (NSUserNotificationAction *act in notification.additionalActions) {
			xpc_array_set_string(act_arr, XPC_ARRAY_APPEND, [act.identifier UTF8String]);
			xpc_array_set_string(act_arr, XPC_ARRAY_APPEND, [act.title UTF8String]);
		}
		xpc_dictionary_set_value(msg, UN_KEY_ACTIONS, act_arr);
		xpc_release(act_arr);
	}

	xpc_dictionary_set_int64(msg, UN_KEY_TRIGGER_TYPE, 0);

	xpc_connection_send_message_with_reply(conn, msg, dispatch_get_main_queue(), ^(xpc_object_t reply) {
		id<NSUserNotificationCenterDelegate> del = self.delegate;
		if ([del respondsToSelector:@selector(userNotificationCenter:didDeliverNotification:)]) {
			[del userNotificationCenter:self didDeliverNotification:notification];
		}
	});
	xpc_release(msg);
}

- (void)removeDeliveredNotification:(NSUserNotification *)notification {
	if (!notification)
		return;

	@synchronized (self) {
		[_deliveredNotifications removeObject:notification];
	}

	xpc_connection_t conn = get_foundation_usernoted_conn();
	xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_string(msg, UN_KEY_OP, UN_OP_REMOVE_DELIVERED);

	NSBundle *bundle = [NSBundle mainBundle];
	NSString *bid = [bundle bundleIdentifier] ? [bundle bundleIdentifier] : [[NSProcessInfo processInfo] processName];
	if (bid) xpc_dictionary_set_string(msg, UN_KEY_BUNDLE_ID, [bid UTF8String]);

	if (notification.identifier) {
		xpc_object_t arr = xpc_array_create(NULL, 0);
		xpc_array_set_string(arr, XPC_ARRAY_APPEND, [notification.identifier UTF8String]);
		xpc_dictionary_set_value(msg, UN_KEY_IDENTIFIERS, arr);
		xpc_release(arr);
	}

	xpc_connection_send_message(conn, msg);
	xpc_release(msg);
}

- (void)removeAllDeliveredNotifications {
	@synchronized (self) {
		[_deliveredNotifications removeAllObjects];
	}

	xpc_connection_t conn = get_foundation_usernoted_conn();
	xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_string(msg, UN_KEY_OP, UN_OP_REMOVE_ALL_DELIVERED);

	NSBundle *bundle = [NSBundle mainBundle];
	NSString *bid = [bundle bundleIdentifier] ? [bundle bundleIdentifier] : [[NSProcessInfo processInfo] processName];
	if (bid) xpc_dictionary_set_string(msg, UN_KEY_BUNDLE_ID, [bid UTF8String]);

	xpc_connection_send_message(conn, msg);
	xpc_release(msg);
}

- (void)scheduleNotification:(NSUserNotification *)notification {
	if (!notification)
		return;

	if (!notification.identifier) {
		notification.identifier = [[NSUUID UUID] UUIDString];
	}

	@synchronized (self) {
		[_scheduledNotifications addObject:notification];
	}

	xpc_connection_t conn = get_foundation_usernoted_conn();
	xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_string(msg, UN_KEY_OP, UN_OP_POST);
	xpc_dictionary_set_bool(msg, UN_KEY_IS_NSUSER, true);

	NSBundle *bundle = [NSBundle mainBundle];
	NSString *bid = [bundle bundleIdentifier] ? [bundle bundleIdentifier] : [[NSProcessInfo processInfo] processName];
	if (bid) xpc_dictionary_set_string(msg, UN_KEY_BUNDLE_ID, [bid UTF8String]);
	if (notification.identifier) xpc_dictionary_set_string(msg, UN_KEY_NOTIFICATION_ID, [notification.identifier UTF8String]);
	if (notification.title) xpc_dictionary_set_string(msg, UN_KEY_TITLE, [notification.title UTF8String]);
	if (notification.subtitle) xpc_dictionary_set_string(msg, UN_KEY_SUBTITLE, [notification.subtitle UTF8String]);
	if (notification.informativeText) xpc_dictionary_set_string(msg, UN_KEY_BODY, [notification.informativeText UTF8String]);
	if (notification.soundName) xpc_dictionary_set_string(msg, UN_KEY_SOUND_FILE, [notification.soundName UTF8String]);

	xpc_dictionary_set_int64(msg, UN_KEY_TRIGGER_TYPE, 1);
	if (notification.deliveryDate) {
		xpc_dictionary_set_double(msg, UN_KEY_FIRE_DATE, [notification.deliveryDate timeIntervalSince1970]);
	}

	xpc_connection_send_message(conn, msg);
	xpc_release(msg);
}

- (void)removeScheduledNotification:(NSUserNotification *)notification {
	if (!notification)
		return;

	@synchronized (self) {
		[_scheduledNotifications removeObject:notification];
	}

	xpc_connection_t conn = get_foundation_usernoted_conn();
	xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_string(msg, UN_KEY_OP, UN_OP_REMOVE_PENDING);

	NSBundle *bundle = [NSBundle mainBundle];
	NSString *bid = [bundle bundleIdentifier] ? [bundle bundleIdentifier] : [[NSProcessInfo processInfo] processName];
	if (bid) xpc_dictionary_set_string(msg, UN_KEY_BUNDLE_ID, [bid UTF8String]);

	if (notification.identifier) {
		xpc_object_t arr = xpc_array_create(NULL, 0);
		xpc_array_set_string(arr, XPC_ARRAY_APPEND, [notification.identifier UTF8String]);
		xpc_dictionary_set_value(msg, UN_KEY_IDENTIFIERS, arr);
		xpc_release(arr);
	}

	xpc_connection_send_message(conn, msg);
	xpc_release(msg);
}

@end

NSString * const NSUserNotificationDefaultSoundName = @"DefaultSoundName";
