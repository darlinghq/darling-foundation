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

#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSXPCProxyCreating.h>
#import <dispatch/dispatch.h>
#import <xpc/xpc.h>
#import <bsm/audit.h>
#import <xpc/connection.h>
#import <xpc/endpoint.h>

// it seems that this header is supposed to include the interface definition for NSXPCInterface
#import <Foundation/NSXPCInterface.h>

@class NSXPCListenerEndpoint, NSXPCListener;
@class _NSXPCConnectionExportInfo, _NSXPCDistantObject, _NSXPCConnectionExpectedReplies, _NSXPCConnectionImportInfo;

typedef NS_OPTIONS(NSUInteger, NSXPCConnectionOptions) {
    NSXPCConnectionPrivileged = (1 << 12UL)
};

@interface NSXPCConnection : NSObject <NSXPCProxyCreating> {
    NSXPCListenerEndpoint * _endpoint;
    NSXPCInterface * _remoteObjectInterface;
    NSString * _serviceName;

    xpc_connection_t _xpcConnection;
    dispatch_queue_t _queue;
    dispatch_group_t _outstandingRepliesGroup;

    void (^_invalidationHandler)(void);
    void (^_interruptionHandler)(void);

    _NSXPCConnectionImportInfo* _importInfo;
    NSMutableDictionary<NSNumber *, _NSXPCConnectionExportInfo *> *_exported;
    _NSXPCConnectionExpectedReplies* _expectedReplies;
    NSUInteger _nextExportNumber;
    NSUInteger _generationCount;
}

@property(readonly) pid_t processIdentifier;
@property(nullable, readonly, copy) NSString *serviceName;
@property(readonly, retain) NSXPCListenerEndpoint *endpoint;

@property(copy) void (^invalidationHandler)(void);
@property(copy) void (^interruptionHandler)(void);

@property(retain) NSXPCInterface *exportedInterface;
@property(retain) id exportedObject;
@property(retain) NSXPCInterface *remoteObjectInterface;
@property(readonly, retain) id remoteObjectProxy;

@property(readonly) uid_t effectiveUserIdentifier;
@property(readonly) gid_t effectiveGroupIdentifier;
@property(readonly) au_asid_t auditSessionIdentifier;

+ (NSXPCConnection *)currentConnection;

- (instancetype) initWithListenerEndpoint: (NSXPCListenerEndpoint *) endpoint;

- (instancetype) initWithServiceName: (NSString *) serviceName;
- (instancetype) initWithServiceName: (NSString *) serviceName
                             options: (NSXPCConnectionOptions) options;
- (instancetype) initWithMachServiceName: (NSString *) serviceName;
- (instancetype) initWithMachServiceName: (NSString *) serviceName
                                 options: (NSXPCConnectionOptions) options;

- (void) invalidate;
- (void) resume;
- (void) suspend;

- (id) remoteObjectProxyWithErrorHandler: (void (^)(NSError *error)) handler;
- (id) synchronousRemoteObjectProxyWithErrorHandler: (void (^)(NSError *error)) handler;

- (void) _addImportedProxy: (_NSXPCDistantObject *) proxy;
- (void) _removeImportedProxy: (_NSXPCDistantObject *) proxy;

- (void) _sendInvocation: (NSInvocation *) invocation
               withProxy: (_NSXPCDistantObject *) proxy;

- (void) _sendInvocation: (NSInvocation *) invocation
             orArguments: (id *) arguments
                   count: (NSUInteger) argumentsCount
         methodSignature: (NSMethodSignature *) signature
                selector: (SEL) selector
               withProxy: (_NSXPCDistantObject *) proxy;

@end

@protocol NSXPCListenerDelegate <NSObject>

- (BOOL) listener: (NSXPCListener *) listener shouldAcceptNewConnection: (NSXPCConnection *) newConnection;

@end

@interface NSXPCListener : NSObject {
    xpc_connection_t _xpcConnection;
    dispatch_queue_t _queue;
    id<NSXPCListenerDelegate> _delegate;
    NSString* _serviceName;
}

+ (instancetype)anonymousListener;
+ (NSXPCListener *)serviceListener;

- (instancetype)initWithMachServiceName:(NSString*)serviceName;

- (void)invalidate;
- (void)resume;
- (void)suspend;

@property (assign /* actually weak */) id<NSXPCListenerDelegate> delegate;
@property (readonly, retain) NSXPCListenerEndpoint* endpoint;

@end

@interface NSXPCListenerEndpoint : NSObject <NSSecureCoding> {
    xpc_endpoint_t _endpoint;
}

@end
