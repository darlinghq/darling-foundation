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

#import <Foundation/NSProxy.h>
#import <Foundation/NSDictionary.h>
#import <stdatomic.h>

@class NSCoder, NSConnection;

// NSDistantObject's exist in pairs, a *local* proxy on one end and a *remote*
// proxy on the other end. They share an ID and represent the same object, which
// exists on the side the local proxy is on.

typedef NS_ENUM(unsigned int, NSDistantObjectType) {
    // A proxy for a local object, mostly used for housekeeping
    // and encoding/decoding.
    NSDistantObjectTypeLocalProxy = 0,
    // A proxy for a remote object. Actually stands in for the remote object.
    NSDistantObjectTypeRemoteProxy = 1,
    // This proxy belongs to another connection (it's not local on either side
    // of this connection). This special type is only used on the wire, but not
    // as a value of NSDistantObject._type.
    NSDistantObjectTypeOtherConnection = 2,
};

@interface NSDistantObject : NSProxy <NSCoding> {
    int _id;
    NSDistantObjectType _type;
    // For local proxies, the object they represent.
    id _localObject;
    NSConnection *_connection;
    // "Wire retain count" -- how many times the represented object is strongly
    // referenced through this connection.
    // For local proxies, this is the wire retain count the remote holds on us.
    // For remote proxies, this is the wire retain count we hold on them.
    // Note that for local proxies, wire retain count also contributes to the
    // regular retain count, i.e. we actually retain ourselves that many times.
    atomic_uint _wireRetainCount;
    // A protocol the proxy is known to conform to. This can be set explicitly,
    // and enables us to resolve method signatures locally instead of asking the
    // remote.
    Protocol *_protocol;
    // Method signature cache.
    NSMutableDictionary<NSString*, NSMethodSignature *> *_knownSelectors;
}

@property (readonly, retain) NSConnection *connectionForProxy;
@property (nonatomic, assign) Protocol *protocolForProxy;

// Local proxy creation.
- (instancetype) initWithLocal: (id) localObject
                    connection: (id) conneciton;

+ (instancetype) proxyWithLocal: (id) localObject
                     connection: (NSConnection *) connection;

// These two methods always return nil.
- (instancetype) initWithTarget: (id) target
                     connection: (NSConnection *) connection;

+ (instancetype) proxyWithTarget: (id) target
                      connection: (NSConnection *) connection;

// We try to use instance methods as little as possible, so the methods below
// are all class methods.

// Use this instead of initWithCoder: (initWithCoder: just returns nil).
+ (instancetype) newDistantObjectWithCoder: (NSCoder *) coder;
// This is the designated initializer.
+ (instancetype) new;

// Look up or create a proxy.
+ (instancetype) proxyWithConnection: (NSConnection *) connection
                                  id: (int) id
                                type: (NSDistantObjectType) type;

+ (void) exposeLocalProxyFromConnection: (NSConnection *) oldConnection
                           toConnection: (NSConnection *) newConnection
                                     id: (int) id;

// Decrease the wire retain count of a local proxy. This is invoked when the
// remote tells us that it has dropped some of those wire references on their
// side.
+ (void) wireRelease: (NSDistantObject *) proxy count: (unsigned int) count;

@end
