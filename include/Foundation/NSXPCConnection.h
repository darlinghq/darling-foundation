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

#import <Foundation/NSObject.h>
#import <xpc/xpc.h>
#import <bsm/audit.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>

@interface NSXPCInterface : NSObject

+ (NSXPCInterface*)interfaceWithProtocol:(Protocol*)protocol;

- (void)setClasses:(NSSet<Class>*)classes forSelector:(SEL)selector argumentIndex:(NSUInteger)argumentIndex ofReply:(BOOL)ofReply;
- (void)setClass:(Class)classes forSelector:(SEL)selector argumentIndex:(NSUInteger)argumentIndex ofReply:(BOOL)ofReply;

@property (assign) Protocol* protocol;

@end

@interface NSXPCListenerEndpoint : NSObject <NSSecureCoding>

@end

@protocol NSXPCListenerDelegate <NSObject>

@end

@interface NSXPCListener : NSObject

+ (instancetype)anonymousListener;

- (instancetype)initWithMachServiceName:(NSString*)serviceName;

- (void)resume;

@property (assign) id<NSXPCListenerDelegate> delegate;
@property (readonly, retain) NSXPCListenerEndpoint* endpoint;

@end

typedef enum NSXPCConnectionOptions : NSUInteger {
	NSXPCConnectionPrivileged = (1 << 12UL),
} NSXPCConnectionOptions;

@interface NSXPCConnection : NSObject

- (void)resume;

- (id)valueForEntitlement:(NSString*)entitlement;

@property (readonly) au_asid_t auditSessionIdentifier;
@property (readonly) gid_t effectiveGroupIdentifier;
@property (readonly) uid_t effectiveUserIdentifier;
@property (readonly, retain) NSXPCListenerEndpoint* endpoint;
@property (retain) NSXPCInterface* exportedInterface;
@property (retain) id exportedObject;
@property (copy) void (^interruptionHandler)(void);
@property (copy) void (^invalidationHandler)(void);
@property (readonly) pid_t processIdentifier;
@property (retain) NSXPCInterface* remoteObjectInterface;
@property (readonly, retain) id remoteObjectProxy;
@property (readonly, copy) NSString* serviceName;

@end
