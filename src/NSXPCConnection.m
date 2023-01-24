/*
 This file is part of Darling.

 Copyright (C) 2020 Lubos Dolezel

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

#import <Foundation/NSXPCConnection.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSException.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSXPCInterface.h>
#import <Foundation/NSMutableDictionary.h>
#import "NSXPCEncoder.h"
#import "NSXPCDecoder.h"
#import "_NSXPCDistantObject.h"
#import "NSXPCConnectionInternal.h"
#import "NSCFTSDKeys.h"
#import <Foundation/NSBlockInvocation.h>
#import <Block_private.h>
#import <os/log.h>
#import <objc/runtime.h>
#import <Foundation/NSXPCConnection_Private.h>
#import "NSXPCInterfaceInternal.h"
#import <Foundation/NSMapTable.h>
#import <Foundation/NSProgress.h>
#import "NSProgressInternal.h"
#import "NSXPCCoderInternal.h"

CF_PRIVATE
os_log_t nsxpc_get_log(void) {
    static os_log_t logger = NULL;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        logger = os_log_create("org.darlinghq.Foundation", "NSXPC");
    });
    return logger;
};

@implementation _NSXPCConnectionExportInfo
@synthesize exportedObject = _exportedObject;
@synthesize exportedInterface = _exportedInterface;
@synthesize exportCount = _exportCount;

- (void) dealloc {
    [_exportedObject release];
    [_exportedInterface release];
    [super dealloc];
}
@end

@implementation _NSXPCConnectionExpectedReplyInfo

@synthesize replyBlock = _replyBlock;
@synthesize errorBlock = _errorBlock;
@synthesize cleanupBlock = _cleanupBlock;
@synthesize selector = _selector;
@synthesize interface = _interface;
@synthesize userInfo = _userInfo;
@synthesize proxyNumber = _proxyNumber;

- (void)dealloc
{
    [_replyBlock release];
    [_errorBlock release];
    [_cleanupBlock release];
    [_interface release];
    [_userInfo release];
    [super dealloc];
}

@end

@implementation _NSXPCConnectionExpectedReplies

- (instancetype)init
{
    if (self = [super init]) {
        _progressesBySequence = [NSMutableDictionary new];
    }
    return self;
}

- (void)dealloc
{
    [_progressesBySequence release];
    [super dealloc];
}

- (NSUInteger)sequenceForProgress: (NSProgress*)progress
{
    @synchronized(self) {
        if (progress) {
            [_progressesBySequence setObject: progress forKey: [NSNumber numberWithUnsignedInteger: _sequence]];
        }
        return _sequence++;
    }
}

- (NSProgress*)progressForSequence: (NSUInteger)sequence
{
    @synchronized(self) {
        return [_progressesBySequence objectForKey: [NSNumber numberWithUnsignedInteger: sequence]];
    }
}

- (void)removeProgressSequence: (NSUInteger)sequence
{
    @synchronized(self) {
        [_progressesBySequence removeObjectForKey: [NSNumber numberWithUnsignedInteger: sequence]];
    }
}

@end

@implementation _NSXPCConnectionImportInfo

- (instancetype)init
{
    if (self = [super init]) {
        _imports = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    }
    return self;
}

- (void)addProxy: (_NSXPCDistantObject*)proxy
{
    @synchronized(self) {
        void* value = 0;
        CFDictionaryGetValueIfPresent(_imports, (void*)proxy._proxyNumber, &value);
        value = (void*)((uintptr_t)value + 1);
        CFDictionarySetValue(_imports, (void*)proxy._proxyNumber, value);
    }
}

- (BOOL)removeProxy: (_NSXPCDistantObject*)proxy
{
    @synchronized(self) {
        void* value = 0;
        if (CFDictionaryGetValueIfPresent(_imports, (void*)proxy._proxyNumber, &value)) {
            value = (void*)((uintptr_t)value - 1);
            if (value == 0) {
                CFDictionaryRemoveValue(_imports, (void*)proxy._proxyNumber);
                return YES;
            } else {
                CFDictionarySetValue(_imports, (void*)proxy._proxyNumber, value);
            }
        }
    }
    return NO;
}

- (void)dealloc
{
    if (_imports != NULL) {
        CFRelease(_imports);
    }
    [super dealloc];
}

@end

@implementation NSXPCConnection

@synthesize serviceName = _serviceName;
@synthesize endpoint = _endpoint;
@synthesize invalidationHandler = _invalidationHandler;
@synthesize interruptionHandler = _interruptionHandler;
@synthesize remoteObjectInterface = _remoteObjectInterface;

+ (NSXPCConnection*)currentConnection
{
    return [[(NSXPCConnection*)_CFGetTSD(__CFTSDKeyNSXPCCurrentConnection) retain] autorelease];
}

- (instancetype) init {
    _importInfo = [_NSXPCConnectionImportInfo new];
    _exported = [NSMutableDictionary new];
    _expectedReplies = [_NSXPCConnectionExpectedReplies new];
    _nextExportNumber = 2;
    _outstandingRepliesGroup = dispatch_group_create();
    return self;
}

- (instancetype) initWithServiceName: (NSString *) serviceName {
    return [self initWithServiceName: serviceName options: 0];
}

- (void)_createQueueForService: (NSString*)serviceName
{
    _queue = dispatch_queue_create([@"org.darlinghq.Foundation.NSXPCConnection." stringByAppendingString: serviceName].UTF8String, dispatch_queue_attr_make_with_autorelease_frequency(NULL, DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM));
}

- (void)_setupConnection
{
    if (!_xpcConnection) {
        [NSException raise: NSInvalidArgumentException format: @"Unable to connect to %@", _serviceName];
    }
    xpc_connection_set_event_handler(_xpcConnection, ^(xpc_object_t message) {
        xpc_type_t type = xpc_get_type(message);

        os_log_debug(nsxpc_get_log(), "Received message from peer: %@", message);

        if (type == XPC_TYPE_DICTIONARY) {
            NSXPCConnectionMessageOptions flags = xpc_dictionary_get_uint64(message, "f");

            if (!(flags & NSXPCConnectionMessageOptionsNoninvocation)) {
                // "not non-invocation" means it's an invocation, so handle it
                [self _decodeAndInvokeMessageWithEvent: message flags: flags];
            } else if (flags & NSXPCConnectionMessageOptionsDesistProxy) {
                [self receivedReleaseForProxyNumber: xpc_dictionary_get_uint64(message,"proxynum") userQueue: _queue];
            } else if (flags & NSXPCConnectionMessageOptionsProgressMessage) {
                [self _decodeProgressMessageWithData: message flags: flags];
            } else {
                os_log_fault(nsxpc_get_log(), "Unexpected message flags (%#lx) received on XPC connection", (long)flags);
                // this is weird, but we're not supposed to invalidate the connection for it
            }
        } else if (type == XPC_TYPE_ERROR) {
            if (message == XPC_ERROR_CONNECTION_INTERRUPTED) {
                os_log_debug(nsxpc_get_log(), "Connection %@ was interrupted", self);

                ++_generationCount;

                if (self.interruptionHandler) {
                    self.interruptionHandler();
                }
            } else if (message == XPC_ERROR_CONNECTION_INVALID) {
                os_log_debug(nsxpc_get_log(), "Connection %@ was invalidated", self);

                [self invalidate];
                if (self.invalidationHandler) {
                    self.invalidationHandler();
                }

                self.interruptionHandler = nil;
                self.invalidationHandler = nil;
                self.exportedObject = nil;
            }
        } else {
            // something's up; ditch the connection
            os_log_fault(nsxpc_get_log(), "Unexpected message type received on XPC connection");
            [self invalidate];
        }
    });
}

- (instancetype)_initWithPeerConnection: (xpc_connection_t)connection name: (NSString*)serviceName options: (NSUInteger)options
{
    if (self = [self init]) {
        _serviceName = [serviceName copy];
        [self _createQueueForService: _serviceName];
        _xpcConnection = xpc_retain(connection);
        [self _setupConnection];
    }
    return self;
}

- (instancetype) initWithServiceName: (NSString *) serviceName
                             options: (NSXPCConnectionOptions) options
{
    if (self = [self init]) {
        _serviceName = [serviceName copy];
        [self _createQueueForService: _serviceName];
        _xpcConnection = xpc_connection_create(_serviceName.UTF8String, _queue);
        [self _setupConnection];
    }
    return self;
}

- (instancetype) initWithMachServiceName: (NSString *)serviceName
                                 options: (NSXPCConnectionOptions)options
{
    if (self = [self init]) {
        _serviceName = [serviceName copy];
        [self _createQueueForService: _serviceName];
        _xpcConnection = xpc_connection_create_mach_service(_serviceName.UTF8String, _queue, (options & NSXPCConnectionPrivileged) ? XPC_CONNECTION_MACH_SERVICE_PRIVILEGED : 0);
        [self _setupConnection];
    }
    return self;
}

- (instancetype) initWithMachServiceName: (NSString *) serviceName {
    return [self initWithMachServiceName: serviceName options: 0];
}

- (instancetype) initWithListenerEndpoint: (NSXPCListenerEndpoint *) endpoint
{
    if (!endpoint._endpoint) {
        [NSException raise: NSInvalidArgumentException format: @"Given endpoint object does not actually contain an endpoint"];
    }
    if (self = [self init]) {
        [self _createQueueForService: @"anonymous"];
        _endpoint = [endpoint retain];
        _xpcConnection = xpc_connection_create_from_endpoint(_endpoint._endpoint);
        [self _setupConnection];
    }
    return self;
}

- (pid_t) processIdentifier {
    return xpc_connection_get_pid(_xpcConnection);
}

- (uid_t)effectiveUserIdentifier
{
    return xpc_connection_get_euid(_xpcConnection);
}

- (gid_t)effectiveGroupIdentifier
{
    return xpc_connection_get_egid(_xpcConnection);
}

- (au_asid_t)auditSessionIdentifier
{
    return xpc_connection_get_asid(_xpcConnection);
}

- (id) exportedObject {
    @synchronized (_exported) {
        return [_exported[@1] exportedObject];
    }
}

- (void) setExportedObject: (id) object {
    @synchronized (_exported) {
        _NSXPCConnectionExportInfo* info = _exported[@1];
        if (!info) {
            _exported[@1] = info = [[_NSXPCConnectionExportInfo new] autorelease];
        }
        info.exportedObject = object;
    }
}

- (NSXPCInterface*)exportedInterface {
    @synchronized (_exported) {
        return [_exported[@1] exportedObject];
    }
}

- (void)setExportedInterface: (NSXPCInterface*)interface {
    @synchronized (_exported) {
        _NSXPCConnectionExportInfo* info = _exported[@1];
        if (!info) {
            _exported[@1] = info = [[_NSXPCConnectionExportInfo new] autorelease];
        }
        info.exportedInterface = interface;
    }
}

- (void)invalidate
{
    xpc_connection_cancel(_xpcConnection);
}

- (void) resume {
    xpc_connection_resume(_xpcConnection);
}

- (void)suspend
{
    xpc_connection_suspend(_xpcConnection);
}

- (void)_sendProgressMessage: (xpc_object_t)message forSequence: (NSUInteger)sequence
{
    xpc_dictionary_set_uint64(message, "f", NSXPCConnectionMessageOptionsRequired | NSXPCConnectionMessageOptionsNoninvocation | NSXPCConnectionMessageOptionsProgressMessage);
    xpc_dictionary_set_uint64(message, "sequence", sequence);
    xpc_connection_send_message(_xpcConnection, message);
}

- (void)_cancelProgress: (NSUInteger)sequence
{
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);

    xpc_dictionary_set_uint64(message, "f", NSXPCConnectionMessageOptionsRequired | NSXPCConnectionMessageOptionsNoninvocation | NSXPCConnectionMessageOptionsProgressMessage | NSXPCConnectionMessageOptionsCancelProgress);
    xpc_dictionary_set_uint64(message, "sequence", sequence);

    xpc_connection_send_message(_xpcConnection, message);
    xpc_release(message);
}

- (void)_pauseProgress: (NSUInteger)sequence
{
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);

    xpc_dictionary_set_uint64(message, "f", NSXPCConnectionMessageOptionsRequired | NSXPCConnectionMessageOptionsNoninvocation | NSXPCConnectionMessageOptionsProgressMessage | NSXPCConnectionMessageOptionsPauseProgress);
    xpc_dictionary_set_uint64(message, "sequence", sequence);

    xpc_connection_send_message(_xpcConnection, message);
    xpc_release(message);
}

- (void)_resumeProgress: (NSUInteger)sequence
{
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);

    xpc_dictionary_set_uint64(message, "f", NSXPCConnectionMessageOptionsRequired | NSXPCConnectionMessageOptionsNoninvocation | NSXPCConnectionMessageOptionsProgressMessage | NSXPCConnectionMessageOptionsResumeProgress);
    xpc_dictionary_set_uint64(message, "sequence", sequence);

    xpc_connection_send_message(_xpcConnection, message);
    xpc_release(message);
}

- (void) _sendDesistForProxy: (_NSXPCDistantObject *) proxy {
    xpc_object_t message = NULL;

    // the root proxy cannot be desisted
    // AND
    // the generation counts must match
    if (proxy._proxyNumber == 1 || proxy._generationCount != _generationCount) {
        return;
    }

    message = xpc_dictionary_create(NULL, NULL, 0);

    xpc_dictionary_set_uint64(message, "f", NSXPCConnectionMessageOptionsRequired | NSXPCConnectionMessageOptionsNoninvocation | NSXPCConnectionMessageOptionsDesistProxy);
    xpc_dictionary_set_uint64(message, "proxynum", proxy._proxyNumber);

    os_log_debug(nsxpc_get_log(), "sending desist for proxy #%lu", (long unsigned)proxy._proxyNumber);

    // TODO: send a notification instead of a message
    xpc_connection_send_message(_xpcConnection, message);
    xpc_release(message);
}

- (void) _addImportedProxy: (_NSXPCDistantObject *) proxy {
    [_importInfo addProxy: proxy];
}

- (void) _removeImportedProxy: (_NSXPCDistantObject *) proxy {
    if ([_importInfo removeProxy: proxy]) {
        [self _sendDesistForProxy: proxy];
    }
}

- (Class) _remoteObjectInterfaceClass {
    if (_remoteObjectInterface == nil) {
        return [_NSXPCDistantObject class];
    }
    return [_remoteObjectInterface _distantObjectClass];
}

- (id) remoteObjectProxy {
    return [self remoteObjectProxyWithErrorHandler: nil];
}

- (id)_exportedObjectForProxyNumber: (NSUInteger)proxyNumber
{
    @synchronized(_exported) {
        NSNumber* key = [NSNumber numberWithUnsignedInteger: proxyNumber];
        return [[_exported[key].exportedObject retain] autorelease];
    }
}

- (NSXPCInterface*)_interfaceForProxyNumber: (NSUInteger)proxyNumber
{
    @synchronized(_exported) {
        NSNumber* key = [NSNumber numberWithUnsignedInteger: proxyNumber];
        return [[_exported[key].exportedInterface retain] autorelease];
    }
}

- (NSUInteger)proxyNumberForExportedObject: (id)object interface: (NSXPCInterface*)interface
{
    @synchronized(_exported) {
        NSUInteger proxyNumber = _nextExportNumber++;
        NSNumber* key = [NSNumber numberWithUnsignedInteger: proxyNumber];
        _NSXPCConnectionExportInfo* info = _exported[key];
        if (!info) {
            _exported[key] = info = [[_NSXPCConnectionExportInfo new] autorelease];
        }
        info.exportedObject = object;
        info.exportedInterface = interface;
        return proxyNumber;
    }
}

- (id) remoteObjectProxyWithErrorHandler: (void (^)(NSError *error)) handler {
    id proxy = [[self _remoteObjectInterfaceClass] alloc];
    proxy = [proxy _initWithConnection: self
                           proxyNumber: 1
                       generationCount: 0
                             interface: _remoteObjectInterface
                               options: 0
                                 error: handler];
    return [proxy autorelease];
}

- (id) synchronousRemoteObjectProxyWithErrorHandler: (void (^)(NSError *error)) handler {
    id proxy = [[self _remoteObjectInterfaceClass] alloc];
    proxy = [proxy _initWithConnection: self
                           proxyNumber: 1
                       generationCount: 0
                             interface: _remoteObjectInterface
                               options: NSXPCDistantObjectFlagSync
                                 error: handler];
    return [proxy autorelease];
}

- (void)  _sendInvocation: (NSInvocation *) invocation
                withProxy: (_NSXPCDistantObject *) proxy
{
    [self _sendInvocation: invocation
              orArguments: NULL
                    count: 0
          methodSignature: [invocation methodSignature]
                 selector: [invocation selector]
                withProxy: proxy];
}

static xpc_object_t __NSXPCCONNECTION_IS_WAITING_FOR_A_SYNCHRONOUS_REPLY__
(xpc_connection_t connection, xpc_object_t message) {
    return xpc_connection_send_message_with_reply_sync(connection, message);
}

static void __NSXPCCONNECTION_IS_CALLING_OUT_TO_ERROR_BLOCK__(void (^errorBlock)(NSError*), NSError* error) {
    errorBlock(error);
};

static void __NSXPCCONNECTION_IS_CALLING_OUT_TO_REPLY_BLOCK__(NSInvocation* invocation) {
    [invocation invoke];
};

- (id)tryReplacingWithProxy: (id)objectToReplace interface: (NSXPCInterface*)interface
{
    BOOL isProxy = [objectToReplace isKindOfClass: [_NSXPCDistantObject class]];

    if (!objectToReplace) {
        // nil should be sent as nil, not as a proxy, so do nothing
        return nil;
    }

    if (interface) {
        // we're expecting a proxy object for this argument;
        // if it's not already a proxy, make it into one
        if (!isProxy) {
            return [[[_NSXPCDistantObject alloc] _initWithConnection: self exportedObject: objectToReplace interface: interface] autorelease];
        }
    } else if (isProxy) {
        // we're NOT expecting a proxy object for this argument;
        // if it's a proxy, throw something
        [NSException raise: NSInvalidArgumentException format: @"Received a proxy object as an argument for a parameter that did not expect one"];
    }

    return nil;
}

- (void) _sendInvocation: (NSInvocation *) invocation
             orArguments: (id *) arguments
                   count: (NSUInteger) argumentsCount
         methodSignature: (NSMethodSignature *) signature
                selector: (SEL) selector
               withProxy: (_NSXPCDistantObject *) proxy
{
    xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
    NSXPCConnectionMessageOptions options = NSXPCConnectionMessageOptionsRequired;
    NSUInteger parameterCount = signature.numberOfArguments;
    _NSXPCConnectionExpectedReplyInfo* replyInfo = nil;
    BOOL startReportingProgress = NO;
    dispatch_semaphore_t timeoutWaiter = NULL;

    os_log_debug(nsxpc_get_log(), "going to send invocation %@ with signature %@ for selector %s on proxy %p", invocation, signature, sel_getName(selector), proxy);

    xpc_dictionary_set_uint64(request, "proxynum", [proxy _proxyNumber]);

    // look for a reply block
    if (parameterCount > 2) {
        for (NSUInteger i = 0; i < parameterCount - 2; ++i) {
            @autoreleasepool {
                const char* paramType = [signature getArgumentTypeAtIndex: i + 2];
                size_t paramTypeLen = strlen(paramType);

                if (paramTypeLen > 1 && paramType[0] == '@' && paramType[1] == '?') {
                    // this parameter is a block
                    id block = nil;
                    const char* rawBlockSig = NULL;
                    NSMethodSignature* blockSig = nil;

                    if (replyInfo) {
                        [NSException raise: NSInvalidArgumentException format: @"NSXPC only supports a single reply block per method"];
                    }

                    if (invocation) {
                        [invocation getArgument: &block atIndex: i + 2];
                    } else {
                        block = arguments[i];
                    }

                    if (!block) {
                        [NSException raise: NSInvalidArgumentException format: @"Reply block for %s was nil", sel_getName(selector)];
                    }

                    rawBlockSig = _Block_signature(block);
                    if (!rawBlockSig) {
                        [NSException raise: NSInvalidArgumentException format: @"Reply block for %s was compiled without an embedded signature", sel_getName(selector)];
                    }

                    blockSig = [NSMethodSignature signatureWithObjCTypes: rawBlockSig];

                    if (blockSig.methodReturnType[0] != 'v') {
                        [NSException raise: NSInvalidArgumentException format: @"Reply block for %s must return void", sel_getName(selector)];
                    }

                    // zero-out the block argument (so it doesn't confuse the serializer)
                    if (invocation) {
                        id arg = nil;
                        [invocation setArgument: &arg atIndex: i + 2];
                    } else {
                        arguments[i] = nil;
                    }

                    xpc_transaction_begin();

                    replyInfo = [_NSXPCConnectionExpectedReplyInfo new];
                    replyInfo.interface = proxy._remoteInterface;
                    replyInfo.selector = selector;
                    replyInfo.proxyNumber = proxy._proxyNumber;
                    replyInfo.replyBlock = block;
                    replyInfo.errorBlock = proxy._errorHandler;

                    if (proxy._timeout && !proxy._sync) {
                        // if we don't have a timeout, we have no reason to set this up.
                        // likewise, if the proxy is synchronous, we're going to block until we get a response anyways, so we don't need a waiter.
                        timeoutWaiter = dispatch_semaphore_create(0);
                    }

                    replyInfo.cleanupBlock = ^{
                        if (timeoutWaiter) {
                            dispatch_semaphore_signal(timeoutWaiter);
                        }
                        xpc_transaction_end();
                    };

                    options |= NSXPCConnectionMessageOptionsExpectsReply;
                    xpc_dictionary_set_string(request, "replysig", rawBlockSig);
                } else if (paramTypeLen > 0 && paramType[0] == '@') {
                    // this parameter is an object
                    id object = nil;

                    if (invocation) {
                        [invocation getArgument: &object atIndex: i + 2];
                    } else {
                        object = arguments[i];
                    }

                    object = [self tryReplacingWithProxy: object interface: [proxy._remoteInterface _interfaceForArgument: i ofSelector: selector reply: NO]];
                    if (object) {
                        if (invocation) {
                            [invocation setArgument: &object atIndex: i + 2];
                            [invocation _addAttachedObject: object];
                        } else {
                            arguments[i] = object;
                        }
                    }
                }
            }
        }
    }

    // methods are usually required to return void;
    // the only other thing they can return is NSProgress, and that's only when they have reply blocks
    if (signature.methodReturnType[0] != 'v') {
        if (replyInfo) {
            Class retClass = [proxy._remoteInterface _returnClassForSelector: selector];
            if (!retClass || ![retClass isSubclassOfClass: [NSProgress class]]) {
                // any other non-NSProgress return type is an error
                [NSException raise: NSInvalidArgumentException format: @"Selector %s must return void or NSProgress*", sel_getName(selector)];
            }
            startReportingProgress = YES;
        } else {
            // no reply block? must return void.
            [NSException raise: NSInvalidArgumentException format: @"Selector %s must return void because it does not accept a reply block", sel_getName(selector)];
        }
    }

    // now, check if proxy is valid. this check is performed here rather than earlier because we need reply info, if any.
    // for it to be valid, it must either be the root proxy or have the same generation count as this connection.
    if (proxy._proxyNumber != 1 && proxy._generationCount != _generationCount) {
        // not the root proxy and generation count didn't match? it's invalid
        // let's do some cleanup
        if (replyInfo) {
            void (^cleanupReplyInfo)(void) = ^{
                if (replyInfo.errorBlock) {
                    NSError* err = [NSError errorWithDomain: NSCocoaErrorDomain code: NSXPCConnectionInvalid userInfo: @{
                        (__bridge NSString*)kCFErrorDescriptionKey: @"The connection was interrupted, but the message was sent over a proxy that was not the root connection proxy; that proxy is now invalid.",
                    }];
                    __NSXPCCONNECTION_IS_CALLING_OUT_TO_ERROR_BLOCK__(replyInfo.errorBlock, err);
                }

                if (replyInfo.cleanupBlock) {
                    replyInfo.cleanupBlock();
                }
            };

            if (proxy._sync) {
                cleanupReplyInfo();
            } else {
                dispatch_async(_queue, cleanupReplyInfo);
            }
        }

        xpc_release(request);
        return;
    }

    // encode the message
    @autoreleasepool {
        unsigned char buffer[1024];
        NSXPCEncoder *encoder = [[NSXPCEncoder alloc]
                                    initWithStackSpace: buffer
                                                  size: sizeof(buffer)];
        [encoder setConnection: self];
        [encoder _encodeInvocation: invocation
                           isReply: NO
                              into: request];
        os_log_debug(nsxpc_get_log(), "encoded invocation: %@", request);
        [encoder release];
    }

    os_log_debug(nsxpc_get_log(), "sending invocation with flags %lu", (unsigned long)options);

    // if we want a reply, then we've got some more work to do
    if (options & NSXPCConnectionMessageOptionsExpectsReply) {
        NSProgress* progress = nil;
        NSUInteger sequence = 0;
        void (^replyHandler)(xpc_object_t) = nil;
        BOOL hasProxiesInReply = [proxy._remoteInterface _hasProxiesInReplyBlockArgumentsOfSelector: selector];

        // if we return an NSProgress, then we start tracking it separately from the "current" NSProgress
        if (startReportingProgress) {
            progress = [NSProgress discreteProgressWithTotalUnitCount: 1];
            [invocation setReturnValue: &progress];
            [invocation _addAttachedObject: progress];
            options |= NSXPCConnectionMessageOptionsTracksProgress | NSXPCConnectionMessageOptionsInitiatesProgressTracking;
        } else {
            // otherwise, check to see if there's a "current" NSProgress
            // POSSIBLE BUG: check if this is only supposed to be done when a reply is expected or if it's done in all cases
            NSProgress* parent = [NSProgress currentProgress];
            if (parent) {
                progress = [[[NSProgress alloc] initWithParent: parent userInfo: nil] autorelease];
                options |= NSXPCConnectionMessageOptionsTracksProgress;
            }
        }

        // generate a new reply sequence
        sequence = [_expectedReplies sequenceForProgress: progress];

        os_log_debug(nsxpc_get_log(), "sending invocation expecting reply, with sequence %lu", (unsigned long)sequence);

        xpc_dictionary_set_uint64(request, "f", options);
        xpc_dictionary_set_uint64(request, "sequence", sequence);

        progress.totalUnitCount = 1;
        progress.cancellationHandler = ^{
            [self _cancelProgress: sequence];
        };
        progress.pausingHandler = ^{
            [self _pauseProgress: sequence];
        };
        progress.resumingHandler = ^{
            [self _resumeProgress: sequence];
        };

        // ok, i don't entirely understand why this part is necessary, but it follows Apple behavior...
        // if we're expecting to receive proxies, we need to make local proxy releases wait, for some reason :/
        if (hasProxiesInReply) {
            [self incrementOutstandingReplyCount];
        }

        replyHandler = ^(xpc_object_t reply) {
            xpc_type_t type = xpc_get_type(reply);

            os_log_debug(nsxpc_get_log(), "recevied reply for sequence %lu with raw XPC content: %@", (unsigned long)sequence, reply);

            // alright, we're done with this reply sequence
            [_expectedReplies removeProgressSequence: sequence];

            // also mark the NSProgress as complete
            progress.completedUnitCount = progress.totalUnitCount;

            if (type == XPC_TYPE_DICTIONARY) {
                [self _decodeAndInvokeReplyBlockWithEvent: reply sequence: sequence replyInfo: replyInfo];
            } else if (type == XPC_TYPE_ERROR) {
                NSInteger code = 0;
                NSString* desc = nil;

                if (reply == XPC_ERROR_CONNECTION_INTERRUPTED) {
                    if (proxy._proxyNumber == 1) {
                        // the default proxy is the only one that can be re-established
                        code = NSXPCConnectionInterrupted;
                        desc = @"The connection was interrupted";
                    } else {
                        code = NSXPCConnectionInvalid;
                        desc = @"The connection was interrupted, but the message was sent over a proxy that was not the root connection proxy; that proxy is now invalid.";
                    }
                } else if (reply == XPC_ERROR_CONNECTION_INVALID) {
                    code = NSXPCConnectionInvalid;
                    desc = @"The connection was invalidated";
                } else {
                    [NSException raise: NSInvalidArgumentException format: @"Invalid error (not XPC_ERROR_CONNECTION_INTERRUPTED and not XPC_ERROR_CONNECTION_INVALID)"];
                }

                if (replyInfo.errorBlock) {
                    NSError* err = [NSError errorWithDomain: NSCocoaErrorDomain code: code userInfo: @{
                        (__bridge NSString*)kCFErrorDescriptionKey: desc,
                    }];
                    __NSXPCCONNECTION_IS_CALLING_OUT_TO_ERROR_BLOCK__(replyInfo.errorBlock, err);
                }

                if (replyInfo.cleanupBlock) {
                    replyInfo.cleanupBlock();
                }
            } else {
                [NSException raise: NSInvalidArgumentException format: @"Invalid reply (not error and not dictionary)"];
            }

            // this is the counterpart to the earlier `incrementOutstandingReplyCount`
            if (hasProxiesInReply) {
                [self decrementOutstandingReplyCount];
            }
        };

        if (proxy._sync) {
            xpc_object_t reply = __NSXPCCONNECTION_IS_WAITING_FOR_A_SYNCHRONOUS_REPLY__(_xpcConnection, request);
            replyHandler(reply);
            xpc_release(reply);
        } else {
            xpc_connection_send_message_with_reply(_xpcConnection, request, _queue, replyHandler);
        }
    } else {
        xpc_dictionary_set_uint64(request, "f", options);
        // TODO: no-importance sending
        xpc_connection_send_message(_xpcConnection, request);
    }

    [replyInfo release];
    xpc_release(request);

    if (timeoutWaiter) {
        // when timeouts are involved, asynchronous proxies block unil the timeout expires (or a reply is received).
        // seems like stupid behavior to me (especially when we could just do `dispatch_async`), but that's how it behaves on macOS.
        dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(proxy._timeout * NSEC_PER_SEC));
        if (dispatch_semaphore_wait(timeoutWaiter, timeout)) {
            // timeout triggered; invalidate the connection and wait for it to be invalidated
            [self invalidate];
            dispatch_semaphore_wait(timeoutWaiter, DISPATCH_TIME_FOREVER);
        }
        dispatch_release(timeoutWaiter);
    }
}

- (void)_beginTransactionForSequence: (NSUInteger)sequence reply: (xpc_object_t)object withProgress: (NSProgress*)progress
{
    xpc_transaction_begin();
}

- (void)_endTransactionForSequence: (NSUInteger)sequence completionHandler: (void(^)(void))handler
{
    handler();
    xpc_transaction_end();
}

- (void)incrementOutstandingReplyCount
{
    dispatch_group_enter(_outstandingRepliesGroup);
}

- (void)decrementOutstandingReplyCount
{
    dispatch_group_leave(_outstandingRepliesGroup);
}

static void __NSXPCCONNECTION_IS_CALLING_OUT_TO_EXPORTED_OBJECT__(NSInvocation* invocation) {
    [invocation invoke];
};

static xpc_object_t __NSXPCCONNECTION_IS_CREATING_REPLY__(xpc_object_t original) {
    return xpc_dictionary_create_reply(original);
};

- (void)_decodeAndInvokeMessageWithEvent: (xpc_object_t)event flags: (NSXPCConnectionMessageOptions)flags
{
    NSUInteger proxyNumber = xpc_dictionary_get_uint64(event, "proxynum");
    id exportedObject = [self _exportedObjectForProxyNumber: proxyNumber];
    NSXPCInterface* interface = [self _interfaceForProxyNumber: proxyNumber];
    NSXPCDecoder* decoder = [[NSXPCDecoder new] autorelease];
    NSInvocation* invocation = nil;
    NSArray* arguments = nil;
    NSMethodSignature* signature = nil;
    SEL selector = nil;
    _NSProgressWithRemoteParent* progress = nil;
    BOOL progressShouldBecomeCurrent = !(flags & NSXPCConnectionMessageOptionsInitiatesProgressTracking);

    [decoder setConnection: self];

    os_log_debug(nsxpc_get_log(), "decoding and invoking message with flags %lu and raw XPC content %@", (unsigned long)flags, event);

    if (!exportedObject || !interface) {
        // bad proxy number; invalidate this connection (the peer probably has outdated info)
        os_log_fault(nsxpc_get_log(), "no exported interface or object was found for the given proxy number (%lu)", (unsigned long)proxyNumber);
        [self invalidate];
        return;
    }

    [decoder _decodeMessageFromXPCObject: event
               allowingSimpleMessageSend: NO // TODO: support simple message send as an optimization
                           outInvocation: &invocation
                            outArguments: &arguments
                    outArgumentsMaxCount: 4
                      outMethodSignature: &signature
                             outSelector: &selector
                               interface: interface];

    os_log_debug(nsxpc_get_log(), "decoded invocation %@ with signature %@ and selector %s", invocation, signature, sel_getName(selector));

    // if they expect a reply, there's more work
    if (flags & NSXPCConnectionMessageOptionsExpectsReply) {
        NSUInteger sequence = xpc_dictionary_get_uint64(event, "sequence");
        NSUInteger parameterCount = signature.numberOfArguments;
        BOOL foundReplyBlock = NO;

        os_log_debug(nsxpc_get_log(), "received invocation expecting reply for sequence %lu", (unsigned long)sequence);

        // if we've got progress tracking, setup a special NSProgress instance
        if (flags & NSXPCConnectionMessageOptionsTracksProgress) {
            progress = [[[_NSProgressWithRemoteParent alloc] initWithParent: nil userInfo: nil] autorelease];
            progress.totalUnitCount = 1;
            progress.sequence = sequence;
            progress.parentConnection = self;
        }

        // look for the reply block
        if (parameterCount > 2) {
            for (NSUInteger i = 0; i < parameterCount - 2; ++i) {
                @autoreleasepool {
                    const char* paramType = [signature getArgumentTypeAtIndex: i + 2];
                    size_t paramTypeLen = strlen(paramType);

                    if (paramTypeLen > 1 && paramType[0] == '@' && paramType[1] == '?') {
                        // TODO: check if incoming and local reply block signatures are compatible
                        const char* replySig = xpc_dictionary_get_string(event, "replysig");
                        NSMethodSignature* remoteBlockSignature = nil;
                        NSMethodSignature* localBlockSignature = nil;
                        xpc_object_t reply = NULL;
                        id forwardingBlock = nil;

                        foundReplyBlock = YES;

                        if (!replySig) {
                            os_log_fault(nsxpc_get_log(), "No remote reply signature provided");
                            [self invalidate];
                            return;
                        }

                        remoteBlockSignature = [NSMethodSignature signatureWithObjCTypes: replySig];

                        localBlockSignature = [interface replyBlockSignatureForSelector: selector];

                        if (!localBlockSignature) {
                            os_log_fault(nsxpc_get_log(), "Found reply block parameter, but no local reply signature");
                            [self invalidate];
                            return;
                        }

                        reply = __NSXPCCONNECTION_IS_CREATING_REPLY__(event);

                        os_log_debug(nsxpc_get_log(), "creating forwarding block with signature %@", localBlockSignature._typeString);

                        // tell the XPC runtime that we're handling a message that needs a reply
                        [self _beginTransactionForSequence: sequence reply: reply withProgress: progress];

                        // setup a forwarding block to pass to the exported object
                        forwardingBlock = [__NSMakeSpecialForwardingCaptureBlock(localBlockSignature._typeString.UTF8String, ^(NSBlockInvocation* invocation) {
                            os_log_debug(nsxpc_get_log(), "forwarding reply block called with invocation %@; sending invocation to remote peer...", invocation);

                            // tell the XPC runtime that we're done handling the mesage;
                            [self _endTransactionForSequence: sequence completionHandler: ^{
                                NSUInteger parameterCount = invocation.methodSignature.numberOfArguments;

                                // look for arguments that need to become proxies
                                if (parameterCount > 1) {
                                    for (NSUInteger i = 0; i < parameterCount - 1; ++i) {
                                        @autoreleasepool {
                                            const char* paramType = [invocation.methodSignature getArgumentTypeAtIndex: i + 1];
                                            size_t paramTypeLen = strlen(paramType);

                                            if (paramTypeLen > 0 && paramType[0] == '@') {
                                                // this parameter is an object
                                                id object = nil;

                                                [invocation getArgument: &object atIndex: i + 1];

                                                // see if it needs to be replaced with a proxy
                                                object = [self tryReplacingWithProxy: object interface: [interface _interfaceForArgument: i ofSelector: selector reply: YES]];
                                                if (object) {
                                                    [invocation setArgument: &object atIndex: i + 1];
                                                    [invocation _addAttachedObject: object];
                                                }
                                            }
                                        }
                                    }
                                }

                                // encode it
                                @autoreleasepool {
                                    unsigned char buffer[1024];
                                    NSXPCEncoder *encoder = [[NSXPCEncoder alloc] initWithStackSpace: buffer size: sizeof(buffer)];
                                    [encoder setConnection: self];
                                    [encoder _encodeInvocation: invocation isReply: YES into: reply];
                                    os_log_debug(nsxpc_get_log(), "encoded reply invocation: %@", reply);
                                    [encoder release];
                                }

                                xpc_connection_send_message(_xpcConnection, reply);
                            }];
                        }) autorelease];

                        [invocation setArgument: &forwardingBlock atIndex: i + 2];
                        [invocation _addAttachedObject: forwardingBlock];

                        break;
                    }
                }
            }
        }

        if (!foundReplyBlock) {
            os_log_fault(nsxpc_get_log(), "Remote asked for reply but we didn't find any reply block parameter locally");
            [self invalidate];
            return;
        }
    }

    invocation.target = exportedObject;

    _CFSetTSD(__CFTSDKeyNSXPCCurrentConnection, self, NULL);
    _CFSetTSD(__CFTSDKeyNSXPCCurrentMessage, event, NULL);

    if (progressShouldBecomeCurrent) {
        [progress becomeCurrentWithPendingUnitCount: 1];
    }

    __NSXPCCONNECTION_IS_CALLING_OUT_TO_EXPORTED_OBJECT__(invocation);

    if (progressShouldBecomeCurrent) {
        [progress resignCurrent];
    } else if (signature.methodReturnType[0] == '@') {
        NSProgress* ret = nil;
        [invocation getReturnValue: &ret];
        if ([ret isKindOfClass: [NSProgress class]]) {
            [progress addChild: ret withPendingUnitCount: 1];
        }
    }

    _CFSetTSD(__CFTSDKeyNSXPCCurrentMessage, NULL, NULL);
    _CFSetTSD(__CFTSDKeyNSXPCCurrentConnection, NULL, NULL);
}

- (void)_decodeAndInvokeReplyBlockWithEvent: (xpc_object_t)event sequence: (NSUInteger)sequence replyInfo: (_NSXPCConnectionExpectedReplyInfo*)replyInfo
{
    NSXPCDecoder* decoder = [[NSXPCDecoder new] autorelease];
    NSInvocation* invocation = nil;

    [decoder setConnection: self];

    invocation = [decoder _decodeReplyFromXPCObject: event forSelector: replyInfo.selector interface: replyInfo.interface];

    os_log_debug(nsxpc_get_log(), "decoded reply invocation %@ for selector %s", invocation, sel_getName(replyInfo.selector));

    if (!invocation) {
        [NSException raise: NSInvalidArgumentException format: @"Failed to decode incoming reply invocation"];
    }

    invocation.target = replyInfo.replyBlock;

    _CFSetTSD(__CFTSDKeyNSXPCCurrentConnection, self, NULL);

    __NSXPCCONNECTION_IS_CALLING_OUT_TO_REPLY_BLOCK__(invocation);

    if (replyInfo.cleanupBlock) {
        replyInfo.cleanupBlock();
    }

    _CFSetTSD(__CFTSDKeyNSXPCCurrentConnection, nil, NULL);
}

- (void)receivedReleaseForProxyNumber: (NSUInteger)proxyNumber userQueue: (dispatch_queue_t)queue
{
    os_log_debug(nsxpc_get_log(), "received release for proxy #%lu; waiting for outstanding replies", (long unsigned)proxyNumber);
    // wait until there's no possibility of anyone using the proxy
    dispatch_group_notify(_outstandingRepliesGroup, queue, ^{
        [self releaseExportedObject: proxyNumber];
    });
}

- (void)_decodeProgressMessageWithData: (xpc_object_t)data flags: (NSXPCConnectionMessageOptions)flags
{
    NSUInteger sequence = xpc_dictionary_get_uint64(data,"sequence");
    NSProgress* progress = [_expectedReplies progressForSequence: sequence];

    if (flags & NSXPCConnectionMessageOptionsCancelProgress) {
        [progress cancel];
    } else if (flags & NSXPCConnectionMessageOptionsPauseProgress) {
        [progress pause];
    } else if (flags & NSXPCConnectionMessageOptionsResumeProgress) {
        [progress resume];
    } else {
        [progress _receiveProgressMessage: data forSequence: sequence];
    }
}

- (void)releaseExportedObject: (NSUInteger)proxyNumber
{
    @synchronized(_exported) {
        os_log_debug(nsxpc_get_log(), "releasing proxy #%lu", (long unsigned)proxyNumber);
        @autoreleasepool {
            NSNumber* key = [NSNumber numberWithUnsignedInteger: proxyNumber];
            _NSXPCConnectionExportInfo* info = _exported[key];
            if (info) {
                if (info.exportCount == 0) {
                    os_log_debug(nsxpc_get_log(), "proxy #%lu has no more references; removing it from export table", (long unsigned)proxyNumber);
                    [_exported removeObjectForKey: key];
                } else {
                    --info.exportCount;
                }
            }
        }
    }
}

- (NSUInteger)_generationCount
{
    return _generationCount;
}

- (void) dealloc {
    os_log_debug(nsxpc_get_log(), "connection %@ is being deallocated", self);
    [_importInfo release];
    [_exported release];
    [_expectedReplies release];
    [_serviceName release];
    [_endpoint release];
    [_invalidationHandler release];
    [_interruptionHandler release];
    if (_xpcConnection != NULL) {
        xpc_release(_xpcConnection);
        _xpcConnection = NULL;
    }
    if (_queue != NULL) {
        dispatch_release(_queue);
        _queue = NULL;
    }
    if (_outstandingRepliesGroup != NULL) {
        dispatch_release(_outstandingRepliesGroup);
        _outstandingRepliesGroup = NULL;
    }
    [super dealloc];
}

- (void)_setTargetUserIdentifier:(uid_t)client {
     NSLog(@"Stub called: _setTargetUserIdentifier: in %@", [self class]);
}

@end

@implementation NSXPCListener

+ (instancetype)anonymousListener
{
    return [[[NSXPCListener alloc] initAsAnonymousListener] autorelease];
}

+ (instancetype)serviceListener
{
    static NSXPCListener* listener = nil;
    static dispatch_once_t token;

    dispatch_once(&token, ^{
        listener = [[NSXPCListener alloc] _initShared];
    });

    return listener;
}

- (void)dealloc
{
    [_serviceName release];
    self.delegate = nil;
    if (_xpcConnection != NULL) {
        xpc_release(_xpcConnection);
        _xpcConnection = NULL;
    }
    if (_queue != NULL) {
        dispatch_release(_queue);
        _queue = NULL;
    }
    [super dealloc];
}

- (NSXPCListenerEndpoint*)endpoint
{
    return [[[NSXPCListenerEndpoint alloc] _initWithConnection: _xpcConnection] autorelease];
}

- (void)_createQueueForService: (NSString*)serviceName
{
    _queue = dispatch_queue_create([@"org.darlinghq.Foundation.NSXPCListener." stringByAppendingString: serviceName].UTF8String, dispatch_queue_attr_make_with_autorelease_frequency(NULL, DISPATCH_AUTORELEASE_FREQUENCY_WORK_ITEM));
}

static void process_connection(NSXPCListener* self, xpc_connection_t connection) {
    NSXPCConnection* peer = [[NSXPCConnection alloc] _initWithPeerConnection: connection name: self->_serviceName options: 0];
    id<NSXPCListenerDelegate> delegate = self.delegate;
    BOOL acceptIt = NO;
    os_log_debug(nsxpc_get_log(), "received new peer connection from PID %u, EUID %u, EGID %u", peer.processIdentifier, peer.effectiveUserIdentifier, peer.effectiveGroupIdentifier);
    if (delegate && [delegate respondsToSelector: @selector(listener:shouldAcceptNewConnection:)]) {
        acceptIt = [delegate listener: self shouldAcceptNewConnection: peer];
    }
    if (!acceptIt) {
        os_log_debug(nsxpc_get_log(), "delegate refused connection (or lacked the necessary method to make that decision); invalidating peer connection");
        [peer invalidate];
    }
    [peer release];
};

- (void)_setupConnection
{
    xpc_connection_set_event_handler(_xpcConnection, ^(xpc_object_t object) {
        xpc_type_t type = xpc_get_type(object);

        if (type == XPC_TYPE_CONNECTION) {
            process_connection(self, object);
        } else if (type == XPC_TYPE_ERROR) {
            if (object != XPC_ERROR_CONNECTION_INVALID && object != XPC_ERROR_TERMINATION_IMMINENT) {
                os_log_fault(nsxpc_get_log(), "Received unexpected/unknown error in listener event handler");
            }
        } else {
            os_log_fault(nsxpc_get_log(), "Received non-connection, non-error object in listener event handler");
        }
    });
}

- (instancetype)initAsAnonymousListener
{
    if (self = [super init]) {
        _serviceName = @"";
        [self _createQueueForService: @"anonymous"];
        _xpcConnection = xpc_connection_create(NULL, _queue);
        [self _setupConnection];
    }
    return self;
}

- (instancetype)initWithMachServiceName: (NSString*)serviceName
{
    if (self = [super init]) {
        _serviceName = [serviceName copy];
        [self _createQueueForService: serviceName];
        _xpcConnection = xpc_connection_create_mach_service(serviceName.UTF8String, _queue, XPC_CONNECTION_MACH_SERVICE_LISTENER);
        [self _setupConnection];
    }
    return self;
}

- (instancetype)_initShared
{
    if (self = [super init]) {
        _queue = dispatch_get_main_queue();
        dispatch_retain(_queue);
    }
    return self;
}

- (id<NSXPCListenerDelegate>)delegate
{
    return objc_loadWeak(&_delegate);
}

- (void)setDelegate: (id<NSXPCListenerDelegate>)delegate
{
    objc_storeWeak(&_delegate, delegate);
}

- (void)invalidate
{
    xpc_connection_cancel(_xpcConnection);
}

static void handle_new_connection(xpc_connection_t connection) {
    process_connection([NSXPCListener serviceListener], connection);
};

- (void)resume
{
    if (self == [NSXPCListener serviceListener]) {
        xpc_main(handle_new_connection);
        return;
    }

    xpc_connection_resume(_xpcConnection);
}

- (void)suspend
{
    xpc_connection_suspend(_xpcConnection);
}

@end

@implementation NSXPCListenerEndpoint

- (void)dealloc
{
    [_endpoint release];
    [super dealloc];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder: (NSCoder*)coder
{
    if (![coder isKindOfClass: [NSXPCDecoder class]]) {
        [NSException raise: NSInvalidArgumentException format: @"NSXPCListenerEndpoint must be decoded with NSXPCDecoder"];
    }

    if (self = [super init]) {
        self._endpoint = [(NSXPCDecoder*)coder decodeXPCObjectOfType: XPC_TYPE_ENDPOINT forKey: @"ep"];
    }

    return self;
}

- (instancetype)_initWithConnection: (xpc_connection_t)connection
{
    if (self = [super init]) {
        _endpoint = xpc_endpoint_create(connection);
    }
    return self;
}

- (void)encodeWithCoder: (NSCoder*)coder
{
    if (![coder isKindOfClass: [NSXPCEncoder class]]) {
        [NSException raise: NSInvalidArgumentException format: @"NSXPCListenerEndpoint must be encoded with NSXPCEncoder"];
    }

    [(NSXPCDecoder*)coder encodeXPCObject: _endpoint forKey: @"ep"];
}

@end

@implementation NSXPCListenerEndpoint (NSXPCPrivateStuff)

- (xpc_endpoint_t)_endpoint
{
    return _endpoint;
}

- (void)set_endpoint: (xpc_endpoint_t)endpoint
{
    [_endpoint release];
    _endpoint = [endpoint retain];
}

@end
