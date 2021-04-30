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

CF_PRIVATE
os_log_t nsxpc_get_log(void) {
    static os_log_t logger = NULL;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        logger = os_log_create("org.darlinghq.Foundation", "NSXPC");
    });
    return logger;
};

@interface _NSXPCConnectionExportInfo : NSObject {
    id _exportedObject;
    NSXPCInterface *_exportedInterface;
    NSUInteger _exportCount;
}

@property(nonatomic, retain) id exportedObject;
@property(nonatomic, retain) NSXPCInterface *exportedInterface;
@property(nonatomic) NSUInteger exportCount;

@end

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
    _imported = [NSMutableArray new];
    _exported = [NSMutableDictionary new];
    _expectedReplies = [_NSXPCConnectionExpectedReplies new];
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

            if (!(flags & NSXPCConnectionMessageOptionsTracksProgress)) {
                [self _decodeAndInvokeMessageWithEvent: message flags: flags];
            } else {
                // TODO: NSProgress support
            }
        } else if (type == XPC_TYPE_ERROR) {
            if (message == XPC_ERROR_CONNECTION_INTERRUPTED) {
                if (self.interruptionHandler) {
                    self.interruptionHandler();
                }
            } else if (message == XPC_ERROR_CONNECTION_INVALID) {
                [self invalidate];
                if (self.invalidationHandler) {
                    self.invalidationHandler();
                }

                // shouldn't be necessary, but Apple does this
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

- (void) _sendDesistForProxy: (_NSXPCDistantObject *) proxy {
    // TODO
}

- (void) _addImportedProxy: (_NSXPCDistantObject *) proxy {
    [_imported addObject: proxy];
}

- (void) _removeImportedProxy: (_NSXPCDistantObject *) proxy {
    NSUInteger index = [_imported indexOfObjectIdenticalTo: proxy];
    if (index == NSNotFound) {
        return;
    }
    [self _sendDesistForProxy: proxy];
    [_imported removeObjectAtIndex: index];
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

- (void) _sendInvocation: (NSInvocation *) invocation
             orArguments: (id *) arguments
                   count: (NSUInteger) argumentsCount
         methodSignature: (NSMethodSignature *) signature
                selector: (SEL) selector
               withProxy: (_NSXPCDistantObject *) proxy
{
    xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
    NSXPCConnectionMessageOptions options = NSXPCConnectionMessageOptionsInvocation;
    NSUInteger parameterCount = signature.numberOfArguments;
    _NSXPCConnectionExpectedReplyInfo* replyInfo = nil;

    os_log_debug(nsxpc_get_log(), "going to send invocation %@ with signature %@ for selector %s on proxy %p", invocation, signature, sel_getName(selector), proxy);

    xpc_dictionary_set_uint64(request, "proxynum", [proxy _proxyNumber]);

    if (parameterCount > 2) {
        for (NSUInteger i = 0; i < parameterCount - 2; ++i) {
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
                replyInfo.cleanupBlock = ^{
                    // TODO: timeouts
                    xpc_transaction_end();
                };

                options |= NSXPCConnectionMessageOptionsExpectsReply;
                xpc_dictionary_set_string(request, "replysig", rawBlockSig);
            }
        }
    }

    // TODO: NSProgress support
    if (signature.methodReturnType[0] != 'v') {
        [NSException raise: NSInvalidArgumentException format: @"Reply block for %s must return void", sel_getName(selector)];
    }

    @autoreleasepool {
        unsigned char buffer[1024];
        NSXPCEncoder *encoder = [[NSXPCEncoder alloc]
                                    initWithStackSpace: buffer
                                                  size: sizeof(buffer)];
        [encoder _encodeInvocation: invocation
                           isReply: NO
                              into: request];
        os_log_debug(nsxpc_get_log(), "encoded invocation: %@", request);
        [encoder release];
    }

    xpc_dictionary_set_uint64(request, "f", options);
    os_log_debug(nsxpc_get_log(), "sending invocation with flags %zu", options);

    if (options & NSXPCConnectionMessageOptionsExpectsReply) {
        // TODO: NSProgress support
        NSProgress* progress = nil;
        NSUInteger sequence = [_expectedReplies sequenceForProgress: progress];
        void (^replyHandler)(xpc_object_t) = nil;

        os_log_debug(nsxpc_get_log(), "sending invocation expected reply, with sequence %zu", sequence);

        xpc_dictionary_set_uint64(request, "sequence", sequence);

        replyHandler = ^(xpc_object_t reply) {
            xpc_type_t type = xpc_get_type(reply);

            os_log_debug(nsxpc_get_log(), "recevied reply for sequence %zu with raw XPC content: %@", sequence, reply);

            [_expectedReplies removeProgressSequence: sequence];

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
        };

        if (proxy._sync) {
            replyHandler(__NSXPCCONNECTION_IS_WAITING_FOR_A_SYNCHRONOUS_REPLY__(_xpcConnection, request));
        } else {
            xpc_connection_send_message_with_reply(_xpcConnection, request, _queue, replyHandler);
        }
    } else {
        // TODO: no-importance sending
        xpc_connection_send_message(_xpcConnection, request);
    }

    [replyInfo release];
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

    os_log_debug(nsxpc_get_log(), "decoding and invoking message with flags %zu and raw XPC content %@", flags, event);

    if (!exportedObject || !interface) {
        os_log_fault(nsxpc_get_log(), "no exported interface or object was found for the given proxy number (%zu)", proxyNumber);
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

    if (flags & NSXPCConnectionMessageOptionsExpectsReply) {
        NSUInteger sequence = xpc_dictionary_get_uint64(event, "sequence");
        NSUInteger parameterCount = signature.numberOfArguments;

        os_log_debug(nsxpc_get_log(), "received invocation expecting reply for sequence %zu", sequence);

        if (parameterCount > 2) {
            for (NSUInteger i = 0; i < parameterCount - 2; ++i) {
                const char* paramType = [signature getArgumentTypeAtIndex: i + 2];
                size_t paramTypeLen = strlen(paramType);

                if (paramTypeLen > 1 && paramType[0] == '@' && paramType[1] == '?') {
                    // TODO: check if incoming and local reply block signatures are compatible
                    const char* replySig = xpc_dictionary_get_string(event, "replysig");
                    NSMethodSignature* remoteBlockSignature = nil;
                    NSMethodSignature* localBlockSignature = nil;
                    xpc_object_t reply = NULL;
                    id forwardingBlock = nil;

                    if (!replySig) {
                        [NSException raise: NSInvalidArgumentException format: @"No remote reply signature provided"];
                    }

                    remoteBlockSignature = [NSMethodSignature signatureWithObjCTypes: replySig];

                    localBlockSignature = [interface replyBlockSignatureForSelector: selector];

                    if (!localBlockSignature) {
                        [NSException raise: NSInvalidArgumentException format: @"No local reply signature found"];
                    }

                    reply = __NSXPCCONNECTION_IS_CREATING_REPLY__(event);

                    os_log_debug(nsxpc_get_log(), "creating forwarding block with signature %@", localBlockSignature._typeString);

                    forwardingBlock = [__NSMakeSpecialForwardingCaptureBlock(localBlockSignature._typeString.UTF8String, ^(NSBlockInvocation* invocation) {
                        os_log_debug(nsxpc_get_log(), "forwarding reply block called with invocation %@; sending invocation to remote peer...", invocation);
                        [self _endTransactionForSequence: sequence completionHandler: ^{
                            @autoreleasepool {
                                unsigned char buffer[1024];
                                NSXPCEncoder *encoder = [[NSXPCEncoder alloc] initWithStackSpace: buffer size: sizeof(buffer)];
                                [encoder _encodeInvocation: invocation isReply: YES into: reply];
                                os_log_debug(nsxpc_get_log(), "encoded reply invocation: %@", reply);
                                [encoder release];
                            }

                            xpc_connection_send_message(_xpcConnection, reply);
                        }];
                    }) autorelease];

                    [invocation setArgument: &forwardingBlock atIndex: i + 2];

                    break;
                }
            }
        }
    }

    invocation.target = exportedObject;

    _CFSetTSD(__CFTSDKeyNSXPCCurrentConnection, self, NULL);
    _CFSetTSD(__CFTSDKeyNSXPCCurrentMessage, event, NULL);

    __NSXPCCONNECTION_IS_CALLING_OUT_TO_EXPORTED_OBJECT__(invocation);

    _CFSetTSD(__CFTSDKeyNSXPCCurrentMessage, NULL, NULL);
    _CFSetTSD(__CFTSDKeyNSXPCCurrentConnection, NULL, NULL);
}

- (void)_decodeAndInvokeReplyBlockWithEvent: (xpc_object_t)event sequence: (NSUInteger)sequence replyInfo: (_NSXPCConnectionExpectedReplyInfo*)replyInfo
{
    NSXPCDecoder* decoder = [[NSXPCDecoder new] autorelease];
    NSInvocation* invocation = [decoder _decodeReplyFromXPCObject: event forSelector: replyInfo.selector interface: replyInfo.interface];

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

- (void) dealloc {
    [_imported release];
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
    [super dealloc];
}

@end

@implementation NSXPCListener

+ (instancetype)anonymousListener
{
    return [[[NSXPCListener alloc] initAsAnonymousListener] autorelease];
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

- (void)_setupConnection
{
    xpc_connection_set_event_handler(_xpcConnection, ^(xpc_object_t object) {
        xpc_type_t type = xpc_get_type(object);

        if (type == XPC_TYPE_CONNECTION) {
            NSXPCConnection* peer = [[NSXPCConnection alloc] _initWithPeerConnection: object name: _serviceName options: 0];
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

- (void)resume
{
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
