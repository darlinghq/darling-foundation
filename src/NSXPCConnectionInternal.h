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
	// Required to be present on all messages
	NSXPCConnectionMessageOptionsRequired                  = 1 << 0,

	// doesn't seem to be used
	//NSXPCConnectionMessageOptionsUnknownOption1            = 1 << 1,

	NSXPCConnectionMessageOptionsNoninvocation             = 1 << 2,
	NSXPCConnectionMessageOptionsDesistProxy               = 1 << 3,
	NSXPCConnectionMessageOptionsProgressMessage           = 1 << 4,
	NSXPCConnectionMessageOptionsExpectsReply              = 1 << 5,
	NSXPCConnectionMessageOptionsTracksProgress            = 1 << 6,
	NSXPCConnectionMessageOptionsInitiatesProgressTracking = 1 << 7,
	NSXPCConnectionMessageOptionsCancelProgress            = 1 << 16,
	NSXPCConnectionMessageOptionsPauseProgress             = 1 << 17,
	NSXPCConnectionMessageOptionsResumeProgress            = 1 << 18,
};

@class NSXPCInterface, NSDictionary, NSProgress, NSMutableDictionary, NSNumber, NSXPCEncoder, _NSXPCDistantObject;

CF_PRIVATE
@interface _NSXPCConnectionExportInfo : NSObject {
	id _exportedObject;
	NSXPCInterface* _exportedInterface;

	// strangely enough, it seems that this is never incremented
	NSUInteger _exportCount;
}

@property(nonatomic, retain) id exportedObject;
@property(nonatomic, retain) NSXPCInterface* exportedInterface;
@property(nonatomic) NSUInteger exportCount;

@end

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

CF_PRIVATE
@interface _NSXPCConnectionImportInfo : NSObject {
	// since we just want to hold counters, it's honestly just easier to use a CFDictionary with NULL key and value callbacks
	CFMutableDictionaryRef _imports;
}

- (void)addProxy: (_NSXPCDistantObject*)proxy;
- (BOOL)removeProxy: (_NSXPCDistantObject*)proxy;

@end

@interface NSXPCConnection (Internal)

@property(readonly) NSUInteger _generationCount;

- (instancetype)_initWithPeerConnection: (xpc_connection_t)connection name: (NSString*)serviceName options: (NSUInteger)options;

- (id)_exportedObjectForProxyNumber: (NSUInteger)proxyNumber;
- (NSXPCInterface*)_interfaceForProxyNumber: (NSUInteger)proxyNumber;
- (NSUInteger)proxyNumberForExportedObject: (id)object interface: (NSXPCInterface*)interface;

- (void)_decodeAndInvokeReplyBlockWithEvent: (xpc_object_t)event sequence: (NSUInteger)sequence replyInfo: (_NSXPCConnectionExpectedReplyInfo*)replyInfo;
- (void)_decodeAndInvokeMessageWithEvent: (xpc_object_t)event flags: (NSXPCConnectionMessageOptions)flags;

- (void)_beginTransactionForSequence: (NSUInteger)sequence reply: (xpc_object_t)object withProgress: (NSProgress*)progress;

- (void)_sendProgressMessage: (xpc_object_t)message forSequence: (NSUInteger)sequence;
- (void)_cancelProgress: (NSUInteger)sequence;
- (void)_pauseProgress: (NSUInteger)sequence;
- (void)_resumeProgress: (NSUInteger)sequence;

- (void)receivedReleaseForProxyNumber: (NSUInteger)proxyNumber userQueue: (dispatch_queue_t)queue;
- (void)_decodeProgressMessageWithData: (xpc_object_t)data flags: (NSXPCConnectionMessageOptions)flags;

- (void)releaseExportedObject: (NSUInteger)proxyNumber;

- (void)incrementOutstandingReplyCount;
- (void)decrementOutstandingReplyCount;

- (id)replacementObjectForEncoder: (NSXPCEncoder*)encoder object: (id)object;

@end

@interface NSXPCListener (Internal)

- (instancetype)initAsAnonymousListener;
- (instancetype)_initShared;

@end

CF_PRIVATE
os_log_t nsxpc_get_log(void);
