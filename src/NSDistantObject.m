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

#import <Foundation/NSDistantObject.h>
#import <Foundation/NSException.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSPortCoder.h>
#import <Foundation/NSConnection.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSProtocolChecker.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import "NSConnectionInternal.h"
#import "NSConcretePortCoder.h"
#import "NSMessageBuilder.h"
#include <objc/runtime.h>

#include <stdatomic.h>

@interface NSObject (NSDOAdditions)
+ (struct objc_method_description *) methodDescriptionForSelector: (SEL) selector;
- (struct objc_method_description *) methodDescriptionForSelector: (SEL) selector;
+ (struct objc_method_description *) instanceMethodDescriptionForSelector: (SEL) selector;
- (BOOL) _conformsToProtocolNamed: (const char *) name;
@end


// All proxies, local and remote, for all the connections.
static NSMutableArray<NSDistantObject *> *allProxies;

// Last ID assigned when creating a local proxy -- the next time a local proxy
// is created, we will increment this number and use that ID. Note that ID 0 is
// special (it means the current connection), so as we initialize this variable
// with zero, ID 0 will never get assigned to any other proxy.
static atomic_uint lastId = 0;

static const char *typeString(int type) {
    switch (type) {
    case NSDistantObjectTypeLocalProxy:
        return "local";
    case NSDistantObjectTypeRemoteProxy:
        return "remote";
    case NSDistantObjectTypeOtherConnection:
        return "other connection";
    default:
        return "???";
    }
}

#define _atomic_wireRetainCount (*((atomic_uint*)&_wireRetainCount))
#define _proxy_atomic_writeRetainCount(proxy) (*((atomic_uint*)&proxy->_wireRetainCount))

@implementation NSDistantObject

@synthesize connectionForProxy = _connection;
@synthesize protocolForProxy = _protocol;

+ (void) initialize {
    if (self != [NSDistantObject class]) {
        return;
    }

    // This is not your usual NSArray; it doesn't retain its elements.
    // However, the CFArray API is the same, so it should be safe to
    // use toll-free bridging here.
    allProxies = (NSMutableArray *) CFArrayCreateMutable(NULL, 0, NULL);
}

- (void) dealloc {
    NSDOLog(@"%s proxy with id %d", typeString(_type), _id);

    switch (_type) {
    case NSDistantObjectTypeLocalProxy:
        NSAssert(_atomic_wireRetainCount == 0, @"deallocating a proxy that's still in use");
        break;
    case NSDistantObjectTypeRemoteProxy:
        if (_atomic_wireRetainCount != 0) {
            // Tell the remote we're no longer using this proxy.
            [_connection releaseProxyID: _id count: _atomic_wireRetainCount];
        }
        break;
    default:
        [NSException raise: NSInternalInconsistencyException
                    format: @"unexpected proxy type %d", _type];
        break;
    }

    @synchronized (allProxies) {
        [allProxies removeObjectIdenticalTo: self];
    }
    [_localObject release];
    [_connection release];
    [_knownSelectors release];
    [super dealloc];
}

- (instancetype) initWithCoder: (NSCoder *) coder {
    [self release];
    return nil;
}

- (instancetype) initWithTarget: (id) target
                     connection: (NSConnection *) connection
{
    [self release];
    return nil;
}

+ (instancetype) proxyWithTarget: (id) target
                      connection: (NSConnection *) connection
{
    return nil;
}

+ (void) wireRelease: (NSDistantObject *) proxy count: (unsigned int) count {
    NSAssert(
       proxy->_type == NSDistantObjectTypeLocalProxy,
       @"attempting to wireRelease a %s proxy",
       typeString(proxy->_type)
    );
    NSDOLog(@"local proxy with id %d, count %u", proxy->_id, count);

    unsigned int previousWireRetainCount = atomic_fetch_sub((atomic_uint*)&proxy->_wireRetainCount, count);
    BOOL shouldInvalidate = previousWireRetainCount <= count;
    if (shouldInvalidate) {
        // The remote no longer needs this proxy. We cannot deallocate it just
        // yet, because someone may still be holding a reference to it locally.
        // But let's make sure we detach it from the connection.
        NSDOLog(@"invalidating the proxy");
        [allProxies removeObjectIdenticalTo: proxy];
        [proxy->_connection release];
        proxy->_connection = nil;
    }

    for (unsigned int i = 0; i < count; i++) {
        [proxy release];
    }
}

- (void) encodeWithCoder: (NSCoder *) aCoder {
    if (![aCoder isKindOfClass: [NSPortCoder class]]) {
        NSDOLog(@"attempted to encode with a %@, ignoring", aCoder);
        return;
    }
    NSConcretePortCoder *coder = (NSConcretePortCoder *) aCoder;
    NSConnection *connection = [coder connection];
    if (!connection) {
        NSDOLog(@"attempted to encode with nil connection, ignoring");
        return;
    }

    unsigned int type = _type;
    if (connection != _connection) {
        // We're being encoded for a different connection.
        if (_type == NSDistantObjectTypeLocalProxy) {
            // If it's a local proxy, we can just expose it ourselves.
            [NSDistantObject exposeLocalProxyFromConnection: _connection
                                               toConnection: connection
                                                         id: _id];
        } else {
            // But doing it for a remote proxy is more involved.
            // First, we ask the remote to expose the proxy to the other connection.
            [_connection sendExposeProxyID: _id toConnection: connection];
            // Second, we will encode a special type and a send port for this
            // connection, so that the other remote can look up or establish its
            // own connection to our remote, and get their own proxy for this
            // object. There's of course no guarantee that our expose request
            // reaches our remote before this connection's remote asks other
            // remote for the proxy. Oh well.
            type = NSDistantObjectTypeOtherConnection;
        }
    }

    NSDOLog(@"encoding %s with id %d", typeString(type), _id);

    if ([coder allowsKeyedCoding]) {
        [coder encodeInt: _id forKey: @"i"];
        [coder encodeInt: type forKey: @"t"];
    } else {
        [coder encodeValueOfObjCType: @encode(int) at: &_id];
        [coder encodeValueOfObjCType: @encode(unsigned int) at: &type];
    }

    if (type == NSDistantObjectTypeOtherConnection) {
        if ([coder allowsKeyedCoding]) {
            [coder encodePortObject: [_connection sendPort] forKey: @"p"];
        } else {
            [coder encodePortObject: [_connection sendPort]];
        }
    }

    if (type == NSDistantObjectTypeLocalProxy) {
        // Passing a local proxy encoded also implicitly
        // transfers them a strong reference.
        _atomic_wireRetainCount++;
        [self retain];
    }
}

+ (instancetype) newDistantObjectWithCoder: (NSCoder *) aCoder {
    if (![aCoder isKindOfClass: [NSPortCoder class]]) {
        NSDOLog(@"attempted to decode from a %@, ignoring", aCoder);
        return nil;
    }
    NSConcretePortCoder *coder = (NSConcretePortCoder *) aCoder;
    NSConnection *connection = [coder connection];
    if (connection == nil) {
        NSDOLog(@"attempted to decode with a nil connection, ignoring");
        return nil;
    }

    int id, type;
    if ([coder allowsKeyedCoding]) {
        id = [coder decodeIntForKey: @"i"];
        type = [coder decodeIntForKey: @"t"];
    } else {
        [coder decodeValueOfObjCType: @encode(int) at: &id];
        [coder decodeValueOfObjCType: @encode(int) at: &type];
    }

    NSDOLog(@"decoding %s with id %d", typeString(type), id);

    NSDistantObject *proxy;

    switch (type) {
    case NSDistantObjectTypeLocalProxy:
        // It was local for them, so it's remote for us.
        proxy = [self proxyWithConnection: connection
                                       id: id
                                     type: NSDistantObjectTypeRemoteProxy];
        // Decoding a remote proxy gives us a strong reference.
        _proxy_atomic_writeRetainCount(proxy)++;
        [proxy retain];
        // [connection importObject: proxy];
        break;
    case NSDistantObjectTypeRemoteProxy:
        // It was remote for them, so it's local for us.
        proxy = [self proxyWithConnection: connection
                                       id: id
                                     type: NSDistantObjectTypeLocalProxy];
        [proxy retain];
        break;
    case NSDistantObjectTypeOtherConnection:
        {
            // This is an NSDistantObject on the remote end, but it doesn't
            // belong to *this* connection; so it's a proxy used on the remote
            // for some other connection. Our remote has asked that other remote
            // to expose the proxy to us, and has sent us a port for that other
            // connection.
            NSPort *sendPort;
            if ([coder allowsKeyedCoding]) {
                sendPort = [coder decodePortObjectForKey: @"p"];
            } else {
                sendPort = [coder decodePortObject];
            }
            // Look up or create that other connection.
            Class connectionClass = [connection class];
            NSConnection *otherConnection =
                [connectionClass connectionWithReceivePort: [connection receivePort]
                                                  sendPort: sendPort];
            // And look up or create the proxy.
            proxy = [self proxyWithConnection: otherConnection
                                           id: id
                                         type: NSDistantObjectTypeRemoteProxy];
            // This also gives us a strong reference.
            _proxy_atomic_writeRetainCount(proxy)++;
            [proxy retain];
            // Should we [otherConnection importObject: proxy]; ??
            break;
        }
    default:
        [NSException raise: NSInternalInconsistencyException
                    format: @"bad type %d", type];
    }

    return proxy;
}

+ (instancetype) new {
    NSDistantObject *proxy = [self alloc];

    proxy->_knownSelectors = [NSMutableDictionary new];
    proxy->_knownSelectors[@"rootObject"] =
        [NSConnection instanceMethodSignatureForSelector: @selector(rootObject)];
    proxy->_knownSelectors[@"keyedRootObject"] =
        [NSConnection instanceMethodSignatureForSelector: @selector(keyedRootObject)];
    proxy->_knownSelectors[@"methodDescriptionForSelector:"] =
        [NSObject instanceMethodSignatureForSelector: @selector(methodDescriptionForSelector:)];

    return proxy;
}

- (instancetype) initWithLocal: (id) localObject
                    connection: (NSConnection *) connection
{
    [self release];
    return [[NSDistantObject proxyWithLocal: localObject connection: connection] retain];
}

+ (instancetype) proxyWithLocal: (id) localObject
                     connection: (NSConnection *) connection
{
    @synchronized (allProxies) {
        // First, try to find an existing proxy.
        for (NSDistantObject *proxy in allProxies) {
            if (
                proxy->_type == NSDistantObjectTypeLocalProxy &&
                proxy->_localObject == localObject &&
                proxy->_connection == connection
            ) {
                NSDOLog(@"found existing proxy with id %d for local object %@", proxy->_id, localObject);
                return proxy;
            }
        }

        // If that failed, create a new one.
        NSDistantObject *proxy = [self new];
        proxy->_id = ++lastId;
        proxy->_type = NSDistantObjectTypeLocalProxy;
        proxy->_localObject = [localObject retain];
        proxy->_connection = [connection retain];
        [allProxies addObject: proxy];
        NSDOLog(@"created new proxy with id %d for local object %@", proxy->_id, localObject);
        return [proxy autorelease];
    }
}

+ (instancetype) proxyWithConnection: (NSConnection *) connection
                                  id: (int) id
                                type: (NSDistantObjectType) type
{
    @synchronized (allProxies) {
        // First, try to find an existing proxy.
        for (NSDistantObject *proxy in allProxies) {
            if (
                proxy->_connection == connection &&
                proxy->_id == id &&
                proxy->_type == type
            ) {
                NSDOLog(@"found existing proxy with id %d", id);
                return proxy;
            }
        }

        // If that failed, create a new one.
        NSDistantObject *proxy = [self new];
        proxy->_id = id;
        proxy->_type = type;
        proxy->_connection = [connection retain];
        NSDOLog(@"created new %s proxy with id %d", typeString(type), id);

        if (type == NSDistantObjectTypeLocalProxy) {
            // For local proxies, this means that either it was the first time ID 0
            // (the connection), the only proxy we don't create explicitly, was
            // mentioned...
            if (id == 0) {
                // TODO: What's the wire retain count in this case?
                NSProtocolChecker *checker = [NSProtocolChecker alloc];
                [checker initWithTarget: connection
                               protocol: @protocol(NSConnectionVersionedProtocol)];
                proxy->_localObject = checker;
            } else {
                // ...or the other side is giving us bogus ids.
                [proxy release];
                [NSException raise: NSInternalInconsistencyException
                            format: @"requested unknown local proxy for id %d", id];
            }
        }

        [allProxies addObject: proxy];
        return [proxy autorelease];
    }
}

+ (void) exposeLocalProxyFromConnection: (NSConnection *) oldConnection
                           toConnection: (NSConnection *) newConnection
                                     id: (int) id
{
    NSDOLog(@"proxy with id %d from %@ to %@", id, oldConnection, newConnection);
    @synchronized (allProxies) {
        // See if the other local proxy already exists. There won't be an ID clash
        // with an unrelated existing proxy for the new connection, because both the
        // old connection's proxy and the potential clashing new connection's proxy
        // would both be local proxies, so it was us who allocated both IDs, and we
        // wouldn't have allocated the same ID for different objects.
        for (NSDistantObject *proxy in allProxies) {
            if (
                proxy->_connection == newConnection &&
                proxy->_id == id &&
                proxy->_type == NSDistantObjectTypeLocalProxy
            ) {
                NSDOLog(@"proxy id %d already exposed to connection %@", id, newConnection);
                return;
            }
        }

        // Otherwise, look up the old connection's proxy -- we're going to need its
        // local object.
        NSDistantObject *oldProxy = nil;
        for (NSDistantObject *proxy in allProxies) {
            if (
                proxy->_connection == oldConnection &&
                proxy->_id == id &&
                proxy->_type == NSDistantObjectTypeLocalProxy
            ) {
                oldProxy = proxy;
                break;
            }
        }

        if (oldProxy == nil) {
            [NSException raise: NSInternalInconsistencyException
                        format: @"asked to expose an nonexistent proxy id %d", id];
        }

        // And create the new proxy.
        NSDistantObject *newProxy = [self new];
        // It shares the same ID, but it's fine because it represents the same object,
        // so this doesn't violate the above statement.
        newProxy->_id = id;
        newProxy->_type = NSDistantObjectTypeLocalProxy;
        newProxy->_connection = [newConnection retain];
        newProxy->_localObject = [oldProxy->_localObject retain];
        [allProxies addObject: newProxy];
        _proxy_atomic_writeRetainCount(newProxy) = 1;
    }
}

- (id) forwardingTargetForSelector: (SEL) selector {
    // For local proxies, we can use the forwarding fast path.
    switch (_type) {
    case NSDistantObjectTypeLocalProxy:
        return _localObject;
    case NSDistantObjectTypeRemoteProxy:
        return nil;
    default:
        [NSException raise: NSInternalInconsistencyException
                    format: @"unexpected proxy type %d", _type];
        return nil;
    }
}

static NSInvocation *makeInvocation(NSDistantObject *self, SEL _cmd) {
    NSMethodSignature *signature = [NSObject instanceMethodSignatureForSelector: _cmd];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature: signature];
    [invocation setTarget: self];
    [invocation setSelector: _cmd];
    return invocation;
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) selector {
    NSString *str = NSStringFromSelector(selector);
    NSMethodSignature *signature = nil;

    NSDOLog(@"%s proxy with id %d, selector %@", typeString(_type), _id, str);

    // First, try to look it up in the cache.
    @synchronized (_knownSelectors) {
        signature = _knownSelectors[str];
    }
    if (signature) {
        NSDOLog(@"found %@ in cache", [signature _typeString]);
        return signature;
    }

    if (_type == NSDistantObjectTypeLocalProxy) {
        // We should not get here when unknown methods are invoked on us
        // locally, because forwardingTargetForSelector: handles local proxies.
        // However, others can still ask us about our method signatures
        // explicitly; and this is why we end up here when the remote wonders
        // about a method signature.
        signature = [_localObject methodSignatureForSelector: selector];
    } else if (_type == NSDistantObjectTypeRemoteProxy) {

        struct objc_method_description desc = { NULL, NULL };

        // Maybe it's a method of the protocol?
        if (_protocol) {
            // Check required methods.
            desc = protocol_getMethodDescription(_protocol, selector, YES, YES);
            if (desc.types == NULL) {
                // Check optional methods.
                desc = protocol_getMethodDescription(_protocol, selector, NO, YES);
            }
        }

        if (desc.types == NULL) {
            // Maybe we don't have a protocol, or maybe this is not a method
            // from the protocol. Let's ask the remote about it. We cannot just
            // ask it for an NSMethodSignature though, because it'll return
            // another proxy for that, and we'll recurse when asking anything of
            // that proxy. Instead, ask it for a method description, and
            // reconstruct a method signature object locally.
            NSInvocation *invocation = makeInvocation(self, @selector(methodDescriptionForSelector:));
            [invocation setArgument: &selector atIndex: 2];
            [_connection sendInvocation: invocation internal: YES];
            struct objc_method_description *descPtr = NULL;
            [invocation getReturnValue: &descPtr];
            if (descPtr != NULL) {
                desc = *descPtr;
            }
        }
        if (desc.types) {
            NSDOLog(@"got a method description with types %s", desc.types);
            signature = [NSMethodSignature signatureWithObjCTypes: desc.types];
        }
    }

    if (signature) {
        @synchronized(_knownSelectors) {
            _knownSelectors[str] = signature;
        }
    }

    NSDOLog(@"going to return %@", [signature _typeString]);
    return signature;
}

- (void) forwardInvocation: (NSInvocation *) invocation {
    NSDOLog(@"%s proxy with id %d, invocation %@", typeString(_type), _id, invocation);

    switch (_type) {
    case NSDistantObjectTypeLocalProxy:
        [invocation invokeWithTarget: _localObject];
        break;
    case NSDistantObjectTypeRemoteProxy:
        [_connection sendInvocation: invocation internal: NO];
        break;
    default:
        [NSException raise: NSInternalInconsistencyException
                    format: @"unexpected proxy type %d", _type];
    }
}

- (BOOL) conformsToProtocol: (Protocol *) protocol {
    switch (_type) {
    case NSDistantObjectTypeLocalProxy:
        return [_localObject conformsToProtocol: protocol];
    case NSDistantObjectTypeRemoteProxy:
        {
            NSInvocation *invocation = makeInvocation(self, @selector(_conformsToProtocolNamed:));
            const char *protocolName = protocol_getName(protocol);
            [invocation setArgument: &protocolName atIndex: 2];
            [_connection sendInvocation: invocation internal: YES];
            BOOL conforms;
            [invocation getReturnValue: &conforms];
            return conforms;
        }
    default:
        [NSException raise: NSInternalInconsistencyException
                    format: @"unexpected proxy type %d", _type];
        return NO;
    }
}

// Below, we override a few common methods to ensure they go through
// forwardInvocation:, as if neither us nor NSProxy implemented them.

- (BOOL) isEqual: (id) other {
    if (other == self) {
        return YES;
    }
    BOOL retVal = NO;
    NSInvocation *inv = nil;
    id builder = _NSMessageBuilder(self, &inv);
    [builder isEqual: other];
    object_dispose(builder);
    [self forwardInvocation: inv];
    [inv getReturnValue: &retVal];
    return retVal;
}

- (NSUInteger) hash {
    NSUInteger retVal = 0;
    NSInvocation *inv = nil;
    id builder = _NSMessageBuilder(self, &inv);
    [builder hash];
    object_dispose(builder);
    [self forwardInvocation: inv];
    [inv getReturnValue: &retVal];
    return retVal;
}

- (NSString *) description {
    NSString *retVal = nil;
    NSInvocation *inv = nil;
    id builder = _NSMessageBuilder(self, &inv);
    [builder description];
    object_dispose(builder);
    [self forwardInvocation: inv];
    [inv getReturnValue: &retVal];
    return retVal;
}

- (id) copy {
    id retVal = nil;
    NSInvocation *inv = nil;
    id builder = _NSMessageBuilder(self, &inv);
    [builder copy];
    object_dispose(builder);
    [self forwardInvocation: inv];
    [inv getReturnValue: &retVal];
    return retVal;
}

- (id) copyWithZone: (NSZone *) zone {
    id retVal = nil;
    NSInvocation *inv = nil;
    id builder = _NSMessageBuilder(self, &inv);
    // Let's not pass zone pointer to the remote...
    [builder copyWithZone: NULL];
    object_dispose(builder);
    [self forwardInvocation: inv];
    [inv getReturnValue: &retVal];
    return retVal;
}

- (id) mutableCopy {
    id retVal = nil;
    NSInvocation *inv = nil;
    id builder = _NSMessageBuilder(self, &inv);
    [builder mutableCopy];
    object_dispose(builder);
    [self forwardInvocation: inv];
    [inv getReturnValue: &retVal];
    return retVal;
}

- (id) mutableCopyWithZone: (NSZone *) zone {
    id retVal = nil;
    NSInvocation *inv = nil;
    id builder = _NSMessageBuilder(self, &inv);
    // Let's not pass zone pointer to the remote...
    [builder mutableCopyWithZone: NULL];
    object_dispose(builder);
    [self forwardInvocation: inv];
    [inv getReturnValue: &retVal];
    return retVal;
}

// Override these two to deal with format varargs properly, because NSInvocation
// doesn't handle varargs in the general case. These could be implemented in
// NSMutableStringProxy instead, but Apple does it here.

- (id) stringByAppendingFormat: (NSString *) format, ... {
    va_list args;
    va_start(args, format);
    NSString *resolved = [[NSString alloc] initWithFormat: format arguments: args];

    id retVal = nil;
    NSInvocation *inv = nil;
    id builder = _NSMessageBuilder(self, &inv);
    [builder stringByAppendingString: resolved];
    object_dispose(builder);
    [self forwardInvocation: inv];
    [inv getReturnValue: &retVal];
    [resolved release];
    return retVal;
}

- (void) appendFormat: (NSString *) format, ... {
    va_list args;
    va_start(args, format);
    NSString *resolved = [[NSString alloc] initWithFormat: format arguments: args];

    NSInvocation *inv = nil;
    id builder = _NSMessageBuilder(self, &inv);
    [builder appendString: resolved];
    object_dispose(builder);
    [self forwardInvocation: inv];
    [resolved release];
}

@end


@implementation NSObject (NSDOAdditions)

+ (struct objc_method_description *) methodDescriptionForSelector: (SEL) selector {
    Method method = class_getClassMethod(self, selector);
    return method ? method_getDescription(method) : NULL;
}

- (struct objc_method_description *) methodDescriptionForSelector: (SEL) selector {
    Method method = class_getInstanceMethod([self class], selector);
    return method ? method_getDescription(method) : NULL;
}

+ (struct objc_method_description *) instanceMethodDescriptionForSelector: (SEL) selector {
    Method method = class_getInstanceMethod(self, selector);
    return method ? method_getDescription(method) : NULL;
}

- (BOOL) _conformsToProtocolNamed: (const char *) name {
    Protocol *protocol = objc_getProtocol(name);
    if (!protocol) {
        return NO;
    }
    return [self conformsToProtocol: protocol];
}

@end


@implementation NSProxy (NSDOAdditions)

- (struct objc_method_description *) methodDescriptionForSelector: (SEL) selector {
    // We cannot just ask the runtime about us, as we may pretend to be someone else.
    // -[NSDistantObject class] actually returns NSDistantObject, but this may not
    // be true for other proxies.
    NSMethodSignature *signature = [self methodSignatureForSelector: selector];
    if (signature == nil) {
        return NULL;
    }
    NSString *types = [signature _typeString];

    // We have to return the result by pointer; moreover, struct objc_method_description
    // itself contains pointers to two other strings. Allocate temporary memory by using
    // autoreleased NSData.
    NSUInteger len = [types length] + 1;
    NSUInteger size = sizeof(struct objc_method_description) + len;
    NSMutableData *data = [NSMutableData dataWithLength: size];
    struct objc_method_description *desc = (struct objc_method_description *) [data mutableBytes];
    desc->name = selector;
    desc->types = (char *) [data mutableBytes] + sizeof(struct objc_method_description);
    [types getCString: desc->types maxLength: len encoding: NSUTF8StringEncoding];

    return desc;
}

@end
