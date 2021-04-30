/**
 * This file is part of Darling.
 *
 * Copyright (C) 2021 Darling developers
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSXPCConnection.h>
#import <xpc/xpc.h>
#import <xpc/connection.h>
#import <os/log.h>

typedef NS_OPTIONS(NSUInteger, NSXPCConnectionMessageOptions) {
	NSXPCConnectionMessageOptionsInvocation                = 1 << 0,
	NSXPCConnectionMessageOptionsExpectsReply              = 1 << 5,
	NSXPCConnectionMessageOptionsTracksProgress            = 1 << 6,
	NSXPCConnectionMessageOptionsInitiatesProgressTracking = 1 << 7,
};

@class NSXPCInterface, NSDictionary, NSProgress, NSMutableDictionary, NSNumber;

CF_PRIVATE
@interface _NSXPCConnectionExpectedReplyInfo : NSObject {
	id _replyBlock;
	void (^_errorBlock)(NSError* error);
	void (^_cleanupBlock)(void);
	SEL _selector;
	NSXPCInterface* _interface;
	NSDictionary* _userInfo;
	NSUInteger _proxyNumber;
}

@property(copy) id replyBlock;
@property(copy) void (^errorBlock)(NSError* error);
@property(copy) void (^cleanupBlock)(void);
@property(assign) SEL selector;
@property(retain) NSXPCInterface* interface;
@property(retain) NSDictionary* userInfo;
@property(assign) NSUInteger proxyNumber;

@end

CF_PRIVATE
@interface _NSXPCConnectionExpectedReplies : NSObject {
	NSUInteger _sequence;
	NSMutableDictionary<NSNumber*, NSProgress*>* _progressesBySequence;
}

- (NSUInteger)sequenceForProgress: (NSProgress*)progress;
- (NSProgress*)progressForSequence: (NSUInteger)sequence;
- (void)removeProgressSequence: (NSUInteger)sequence;

@end

@interface NSXPCConnection (Internal)

- (instancetype)_initWithPeerConnection: (xpc_connection_t)connection name: (NSString*)serviceName options: (NSUInteger)options;

- (id)_exportedObjectForProxyNumber: (NSUInteger)proxyNumber;
- (NSXPCInterface*)_interfaceForProxyNumber: (NSUInteger)proxyNumber;

- (void)_decodeAndInvokeReplyBlockWithEvent: (xpc_object_t)event sequence: (NSUInteger)sequence replyInfo: (_NSXPCConnectionExpectedReplyInfo*)replyInfo;
- (void)_decodeAndInvokeMessageWithEvent: (xpc_object_t)event flags: (NSXPCConnectionMessageOptions)flags;

- (void)_beginTransactionForSequence: (NSUInteger)sequence reply: (xpc_object_t)object withProgress: (NSProgress*)progress;

@end

@interface NSXPCListener (Internal)

- (instancetype)initAsAnonymousListener;

@end

CF_PRIVATE
os_log_t nsxpc_get_log(void);
