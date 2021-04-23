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
#import "NSXPCEncoder.h"
#import "_NSXPCDistantObject.h"

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

@implementation NSXPCConnection

@synthesize serviceName = _serviceName;
@synthesize endpoint = _endpoint;
@synthesize invalidationHandler = _invalidationHandler;
@synthesize interruptionHandler = _interruptionHandler;
@synthesize remoteObjectInterface = _remoteObjectInterface;

- (instancetype) init {
    _imported = [NSMutableArray new];
    _exported = [NSMutableDictionary new];
    return self;
}

- (instancetype) initWithServiceName: (NSString *) serviceName {
    return [self initWithServiceName: serviceName options: 0];
}

- (instancetype) initWithServiceName: (NSString *) serviceName
                             options: (NSXPCConnectionOptions) options
{
    self = [self init];
    NSString *queueName = [@"org.darlinghq.NSXPCConnection."
                              stringByAppendingString: serviceName];
    _queue = dispatch_queue_create([queueName UTF8String], NULL);
    _xpcConnection = xpc_connection_create(
        [serviceName fileSystemRepresentation],
        _queue
    );
    if (_xpcConnection == NULL) {
        [NSException raise: NSInvalidArgumentException
                    format: @"Unable to connect to %@", serviceName];
    }
    return self;
}

- (instancetype) initWithMachServiceName: (NSString *) serviceName {
    return [self initWithMachServiceName: serviceName options: 0];
}

- (pid_t) processIdentifier {
    return xpc_connection_get_pid(_xpcConnection);
}

- (id) exportedObject {
    @synchronized (_exported) {
        return [_exported[@1] exportedObject];
    }
}

- (void) setExportedObject: (id) object {
    @synchronized (_exported) {
        [_exported[@1] setExportedObject: object];
    }
}

- (void) resume {
    xpc_connection_resume(_xpcConnection);
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

- (void) _sendInvocation: (NSInvocation *) invocation
             orArguments: (id *) arguments
                   count: (NSUInteger) argumentsCount
         methodSignature: (NSMethodSignature *) signature
                selector: (SEL) selector
               withProxy: (_NSXPCDistantObject *) proxy
{
    xpc_object_t request = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_uint64(request, "proxynum", [proxy _proxyNumber]);

    @autoreleasepool {
        unsigned char buffer[1024];
        NSXPCEncoder *encoder = [[NSXPCEncoder alloc]
                                    initWithStackSpace: buffer
                                                  size: sizeof(buffer)];
        [encoder _encodeInvocation: invocation
                           isReply: NO
                              into: request];
        [encoder release];
    }

    // We're waiting for an asynchronous reply, so inform XPC about it.
    xpc_transaction_begin();

    if ([proxy _sync]) {
        xpc_object_t response =
            __NSXPCCONNECTION_IS_WAITING_FOR_A_SYNCHRONOUS_REPLY__(
                _xpcConnection,
                request
            );
    }

    NSLog(@"would send message here");
    NSLog(@"%s", xpc_copy_description(request));
}

- (void) dealloc {
    [_imported release];
    [_exported release];
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

+ (instancetype)anonymousListener {
    // TODO: do stuff?
    return [NSXPCListener alloc];
}

- (instancetype)initWithMachServiceName:(NSString*)serviceName {
    #warning TODO: implement `initWithMachServiceName:` in NSXPCListener
    // actually, it's more like "TODO: implement all of NSXPC*"
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end

@implementation NSXPCListenerEndpoint

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
