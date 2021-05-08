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

/**
 * All messages sent across the connection must carry a uint64 for the "f" key (assumed to be short for "flags") which contains these options, describing the contents of the message.
 *
 * Note: to see details the serialization format of invocations, checkout `NSXPCEncoder.m`, `NSXPCSerialization.c`, and `NSXPCSerializationObjC.m`.
 */
typedef NS_OPTIONS(NSUInteger, NSXPCConnectionMessageOptions) {
	/**
	 * Required to be present on all messages.
	 */
	NSXPCConnectionMessageOptionsRequired                  = 1 << 0,

	// doesn't seem to be used
	//NSXPCConnectionMessageOptionsUnknownOption1            = 1 << 1,

	/**
	 * Set on messages that aren't invocations.
	 */
	NSXPCConnectionMessageOptionsNoninvocation             = 1 << 2,

	/**
	 * Set on messages that indicate the sender has released all references to the proxy specified by the message.
	 *
	 * Messages of this kind must carry a uint64 for the "proxynum" key to identify the proxy that has been released by the message sender.
	 */
	NSXPCConnectionMessageOptionsDesistProxy               = 1 << 3,

	/**
	 * Set on messages that contain NSProgress state updates.
	 *
	 * Messages of this kind must carry a uint64 for the "sequence" key, which is associated on both ends with an NSProgress instance that track progress for the sequence.
	 */
	NSXPCConnectionMessageOptionsProgressMessage           = 1 << 4,

	/**
	 * Set on invocation messages to indicate that they expect a reply.
	 * Only set on plain invocations, not replies (NSXPC does not support replying to a reply; the C API for XPC does support this).
	 *
	 * Messages of this kind must carry a string for the "replysig" key, which contains the signature of the sender's reply block.
	 * Messages of this kind must also carry a uint64 for the "sequence" key, which identifies the reply sequence being started.
	 */
	NSXPCConnectionMessageOptionsExpectsReply              = 1 << 5,

	/**
	 * Set on invocation messages that incorporate NSProgress tracking across processes.
	 *
	 * NSProgress tracking can be triggered in one of two ways:
	 *   1. Directly, by invoking a protocol method that returns NSProgress AND accepts a reply block.
	 *      NSProgress tracking triggered in this way returns a detached NSProgress object (i.e. it will not be associated with the "current" NSProgress instance).
	 *   2. Indirectly, by having a "current" NSProgress instance active when you invoke a protocol method.
	 *      NSProgress tracking triggered in this way WILL be associated with the "current" NSProgress instance.
	 *
	 * If both conditions are satisfied when a method is invoked, the first (i.e. the "Direct" case) will be preferred and that is the behavior exhibited.
	 */
	NSXPCConnectionMessageOptionsTracksProgress            = 1 << 6,

	/**
	 * Set on invocation messages that trigger the "direct" case of NSProgress tracking.
	 *
	 * @see NSXPCConnectionMessageOptionsTracksProgress
	 */
	NSXPCConnectionMessageOptionsInitiatesProgressTracking = 1 << 7,

	/**
	 * Set on NSProgress state update messages that indicate the sender's NSProgress was cancelled.
	 */
	NSXPCConnectionMessageOptionsCancelProgress            = 1 << 16,

	/**
	 * Set on NSProgress state update messages that indicate the sender's NSProgress was paused.
	 */
	NSXPCConnectionMessageOptionsPauseProgress             = 1 << 17,

	/**
	 * Set on NSProgress state update messages that indicate the sender's NSProgress was resumed.
	 */
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

/**
 * Returns a new sequence number for the given NSProgress instance.
 */
- (NSUInteger)sequenceForProgress: (NSProgress*)progress;

/**
 * Returns the NSProgress instance associated with the given sequence, or `nil` if none is associated with it.
 */
- (NSProgress*)progressForSequence: (NSUInteger)sequence;

/**
 * Dissociates the given sequence number from its NSProgress instance.
 */
- (void)removeProgressSequence: (NSUInteger)sequence;

@end

/**
 * Used to track imported proxies. The proxies are not retained by this class.
 */
CF_PRIVATE
@interface _NSXPCConnectionImportInfo : NSObject {
	// since we just want to hold counters, it's honestly just easier to use a CFDictionary with NULL key and value callbacks
	CFMutableDictionaryRef _imports;
}

/**
 * Increment the given proxy's reference count in the internal table.
 *
 * If the proxy is not already present in the table, it is assigned an initial reference count of 1.
 */
- (void)addProxy: (_NSXPCDistantObject*)proxy;

/**
 * Decrement the given proxy's reference count in the internal table.
 *
 * If the reference count for the proxy has dropped to 0 (i.e. nobody references it now), returns YES. Otherwise, returns NO.
 * If the proxy is not present in the table, returns NO.
 */
- (BOOL)removeProxy: (_NSXPCDistantObject*)proxy;

@end

@interface NSXPCConnection (Internal)

@property(readonly) NSUInteger _generationCount;

/**
 * Initializes the connection with the given XPC connection, service name, and options.
 */
- (instancetype)_initWithPeerConnection: (xpc_connection_t)connection name: (NSString*)serviceName options: (NSUInteger)options;

/**
 * Returns the exported object for the given proxy number, or `nil` if none is associated with it.
 */
- (id)_exportedObjectForProxyNumber: (NSUInteger)proxyNumber;

/**
 * Returns the exported interface for the given proxy number, or `nil` if none is associated with it.
 */
- (NSXPCInterface*)_interfaceForProxyNumber: (NSUInteger)proxyNumber;

/**
 * Generates and returns a new proxy number for the given object and interface.
 * Both the object and interface are retained by the connection until all peers have released them.
 */
- (NSUInteger)proxyNumberForExportedObject: (id)object interface: (NSXPCInterface*)interface;

/**
 * Decodes the given XPC message into an invocation and invokes it with the reply block attached to the given reply info as its target.
 */
- (void)_decodeAndInvokeReplyBlockWithEvent: (xpc_object_t)event sequence: (NSUInteger)sequence replyInfo: (_NSXPCConnectionExpectedReplyInfo*)replyInfo;

/**
 * Decodes the given XPC message into an invocation and invokes it with the connection's primary exported object (i.e. the one with proxy number 1) as its target.
 */
- (void)_decodeAndInvokeMessageWithEvent: (xpc_object_t)event flags: (NSXPCConnectionMessageOptions)flags;

/**
 * Informs the XPC runtime that the connection has started processing an incoming message.
 */
- (void)_beginTransactionForSequence: (NSUInteger)sequence reply: (xpc_object_t)object withProgress: (NSProgress*)progress;

/**
 * Informs the XPC runtime that the connection has finished processing an incoming message.
 */
- (void)_endTransactionForSequence: (NSUInteger)sequence completionHandler: (void(^)(void))handler;

/**
 * Fills in the appropriate information for an NSProgress state update message for the given sequence into the given message dictionary and sends it.
 */
- (void)_sendProgressMessage: (xpc_object_t)message forSequence: (NSUInteger)sequence;

/**
 * Informs the peer that the sender has cancelled the NSProgress instance for the given sequence.
 */
- (void)_cancelProgress: (NSUInteger)sequence;

/**
 * Informs the peer that the sender has paused the NSProgress instance for the given sequence.
 */
- (void)_pauseProgress: (NSUInteger)sequence;

/**
 * Informs the peer that the sender has resumed the NSProgress instance for the given sequence.
 */
- (void)_resumeProgress: (NSUInteger)sequence;

/**
 * Processes an incoming proxy desist message on the given queue.
 */
- (void)receivedReleaseForProxyNumber: (NSUInteger)proxyNumber userQueue: (dispatch_queue_t)queue;

/**
 * Decodes the given NSProgress state update message and updates the local NSProgress instance associated with the sequence provided in the message using the information provided in the message.
 */
- (void)_decodeProgressMessageWithData: (xpc_object_t)data flags: (NSXPCConnectionMessageOptions)flags;

/**
 * Decrements the external reference count on the proxy with the given proxy number.
 *
 * Does this by invoking `-[_NSXPCConnectionImportInfo removeProxy:]`, so if the proxy now has no external references, it will be released.
 */
- (void)releaseExportedObject: (NSUInteger)proxyNumber;

/**
 * Indicates that the connection is waiting for an asynchronous reply. Must be balanced with a subsequent call to `decrementOutstandingReplyCount`.
 */
- (void)incrementOutstandingReplyCount;

/**
 * Indicates that the connection has finished waiting for an asynchronous reply. Must be balanced with a previous call to `incrementOutstandingReplyCount`.
 */
- (void)decrementOutstandingReplyCount;

/**
 * Tries to look for an object to replace the given decoded object. Returns the same object if none was found.
 */
- (id)replacementObjectForEncoder: (NSXPCEncoder*)encoder object: (id)object;

/**
 * Encodes the given invocation (sent to the given proxy, with the given selector and signature) into a message and sends it.
 * If the invoked method expects a reply, it will perform the necessary actions to wait for a reply, either synchronously or asynchronously (as determined by the given proxy).
 *
 * The `arguments` and `argumentsCount` parameters are an alternative to passing an invocation.
 * They're used as an optimization for simple methods that accept a maximum of 4 object arguments.
 * If `invocation` is non-nil, `arguments` and argumentsCount` are ignored.
 */
- (void)_sendInvocation: (NSInvocation*)invocation
            orArguments: (id*)arguments
                  count: (NSUInteger)argumentsCount
        methodSignature: (NSMethodSignature*)signature
               selector: (SEL)selector
              withProxy: (_NSXPCDistantObject*)proxy;

/**
 * Calls `_sendInvocation:orArguments:count:methodSignature:selector:withProxy:` using information from the given invocation and proxy.
 */
- (void)_sendInvocation: (NSInvocation*)invocation withProxy: (_NSXPCDistantObject*)proxy;

/**
 * Increments the internal reference count on the given proxy.
 */
- (void) _addImportedProxy: (_NSXPCDistantObject *) proxy;

/**
 * Decrements the internal reference count on the given proxy. If the proxy now has no internal references, sends a proxy desist message to the peer.
 */
- (void) _removeImportedProxy: (_NSXPCDistantObject *) proxy;

/**
 * Try to replace the given object with a proxy of the given interface. If the object is already a proxy or the interface is `nil`, it does not replace the object.
 *
 * @returns A new autoreleased proxy if the given object was replaced with a proxy, `nil` if it was not replaced.
 */
- (id)tryReplacingWithProxy: (id)objectToReplace interface: (NSXPCInterface*)interface;

@end

@interface NSXPCListener (Internal)

/**
 * Initializes the listener as an anonymous listener.
 */
- (instancetype)initAsAnonymousListener;

/**
 * Initializes the listener as the shared service listener.
 */
- (instancetype)_initShared;

@end

CF_PRIVATE
os_log_t nsxpc_get_log(void);
