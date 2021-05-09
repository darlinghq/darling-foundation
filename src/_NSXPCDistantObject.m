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

#import "_NSXPCDistantObject.h"
#import "NSXPCEncoder.h"
#import "NSXPCDecoder.h"
#import <Foundation/NSException.h>
#import <Foundation/NSXPCInterface.h>
#import <Foundation/NSXPCConnection.h>
#import "NSXPCConnectionInternal.h"
#import "NSXPCInterfaceInternal.h"

@implementation _NSXPCDistantObject

@synthesize _connection = _connection;
@synthesize _errorHandler = _errorHandler;
@synthesize _generationCount = _generationCount;
@synthesize _proxyNumber = _proxyNumber;
@synthesize _remoteInterface = _remoteInterface;
@synthesize _timeout = _timeout;

- (BOOL) _sync {
    return (_flags & NSXPCDistantObjectFlagSync) != 0;
}

- (BOOL) _exported {
    return (_flags & NSXPCDistantObjectFlagExported) != 0;
}

- (BOOL) _noImportance {
    return (_flags & NSXPCDistantObjectFlagNoImportance) != 0;
}

- (instancetype)_initWithConnection: (NSXPCConnection*)connection exportedObject: (id)object interface: (NSXPCInterface*)interface
{
    if (self = [super init]) {
        _connection = [connection retain];
        _proxyNumber = [_connection proxyNumberForExportedObject: object interface: interface];
        _flags = NSXPCDistantObjectFlagExported;
    }
    return self;
}

- (instancetype) _initWithConnection: (NSXPCConnection *) connection
                         proxyNumber: (NSUInteger) proxyNumber
                     generationCount: (NSUInteger) generationCount
                           interface: (NSXPCInterface *) remoteInterface
                             options: (NSUInteger) flags
                               error: (void (^)(NSError *error)) errorHandler
{
    _connection = [connection retain];
    _errorHandler = [errorHandler copy];
    _flags = flags;
    _proxyNumber = proxyNumber;
    _generationCount = generationCount;
    _remoteInterface = [remoteInterface retain];

    [connection _addImportedProxy: self];
    return self;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (void) encodeWithCoder: (NSXPCEncoder *) coder {
    if (![coder isKindOfClass: [NSXPCEncoder class]]) {
        [NSException raise: NSInvalidArgumentException
                    format: @"XPC proxies can only be encoded"
                     " with NSXPCEncoder, not %@", [coder class]];
    }

    if (_connection != [coder connection]) {
        [NSException raise: NSInvalidArgumentException
                    format: @"Trying to send an XPC proxy for %@ over %@",
                    _connection, [coder connection]];
    }

    [coder encodeInt64: _proxyNumber forKey: @"pn"];
    [coder encodeBool: [self _exported] forKey: @"ex"];
}

- (instancetype) initWithCoder: (NSXPCDecoder *) coder {
    if (![coder isKindOfClass: [NSXPCDecoder class]]) {
        [NSException raise: NSInvalidArgumentException
                    format: @"XPC proxies can only be decoded"
                     " with NSXPCDecoder, not %@", [coder class]];
    }

    _connection = [[coder connection] retain];
    _generationCount = [_connection _generationCount];

    _proxyNumber = [coder decodeInt64ForKey: @"pn"];
    BOOL exported = [coder decodeBoolForKey: @"ex"];
    if (exported) {
        // It was exported for them, so it's a proxy for us.
        [_connection _addImportedProxy: self];
        return self;
    } else {
        // It was *not* exported for them, so it's actually a
        // local object on our side!
        id object = [_connection _exportedObjectForProxyNumber: _proxyNumber];
        [self release];
        return [object retain];
    }
}

- (id) remoteObjectProxy {
    return [self remoteObjectProxyWithErrorHandler: nil];
}

- (id) remoteObjectProxyWithErrorHandler: (void (^)(NSError *error)) handler {
    Class class = [_remoteInterface _distantObjectClass];
    return [[[class alloc] _initWithConnection: _connection
                                   proxyNumber: _proxyNumber
                               generationCount: _generationCount
                                     interface: _remoteInterface
                                       options: 0
                                         error: handler] autorelease];
}

- (id) synchronousRemoteObjectProxyWithErrorHandler: (void (^)(NSError *error)) handler {
    Class class = [_remoteInterface _distantObjectClass];
    return [[[class alloc] _initWithConnection: _connection
                                   proxyNumber: _proxyNumber
                               generationCount: _generationCount
                                     interface: _remoteInterface
                                       options: NSXPCDistantObjectFlagSync
                                         error: handler] autorelease];
}

- (BOOL) respondsToSelector: (SEL) selector {
    char response = _remoteInterface ? [_remoteInterface _respondsToRemoteSelector: selector] : 1;

    if (response == 0) {
        // response of 0 means it DOES respond to it
        return YES;
    } else if (response == 2) {
        // response of 2 means it DOES respond to it, but the versions aren't compatible
        return NO;
    }

    // response of 1 it DOES NOT respond to it, so we need to check our non-proxied methods
    return [super respondsToSelector: selector];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) selector {
    // Look among remote signatures first.
    NSMethodSignature *signature =
        [_remoteInterface _methodSignatureForRemoteSelector: selector];
    if (signature != nil) {
        return signature;
    }
    // Otherwise, we support the regular NSObject
    // signature resolution mechanism.
    return [super methodSignatureForSelector: selector];
}

- (void) forwardInvocation: (NSInvocation *) invocation {
    [_connection _sendInvocation: invocation withProxy: self];
}

- (void) dealloc {
    os_log_debug(nsxpc_get_log(), "deallocating proxy %p", self);

    if (![self _exported]) {
        [_connection _removeImportedProxy: self];
    }

    [_connection release];
    [_errorHandler release];
    [_remoteInterface release];
    [super dealloc];
}

@end
