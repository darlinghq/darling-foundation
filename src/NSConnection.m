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

#import <Foundation/NSConnection.h>
#import "NSConnectionInternal.h"

#import <Foundation/NSDistantObject.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMachBootstrapServer.h>
#import <Foundation/NSPortMessage.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSPort.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSUserDefaults.h>

#import "NSConcreteDistantObjectRequest.h"
#import "NSConcretePortCoder.h"
#import "NSKeyedPortCoder.h"
#import "NSUnkeyedPortCoder.h"

@interface NSRunLoop (Wakeup)
- (void) _wakeup;
@end

const NSRunLoopMode NSConnectionReplyMode = @"NSConnectionReplyMode";
const NSNotificationName NSConnectionDidInitializeNotification = @"NSConnectionDidInitializeNotification";
const NSNotificationName NSConnectionDidDieNotification = @"NSConnectionDidDieNotification";

BOOL NSDOLoggingEnabled = NO;
static atomic_uint lastSequenceNumber = 0;
static NSMutableArray<NSConnection *> *allConnections;
static NSData *keyedMagic;


@implementation NSConnection

@synthesize rootObject = _rootObject;
@synthesize delegate = _delegate;
@synthesize sendPort = _sendPort;
@synthesize receivePort = _recvPort;
@synthesize requestTimeout = _requestTimeout;
@synthesize replyTimeout = _replyTimeout;
@synthesize requestModes = _requestModes;

+ (void) initialize {
    if (self != [NSConnection class]) {
        return;
    }

    allConnections = [NSMutableArray new];
    keyedMagic = [[@"0001KeYd" dataUsingEncoding: NSUTF8StringEncoding] retain];
}

- (instancetype) init {
    // Make a service connection with a fresh port.
    return [self initWithReceivePort: [NSPort port] sendPort: nil];
}

- (instancetype) initWithReceivePort: (NSPort *) recvPort
                            sendPort: (NSPort *) sendPort
{
    // 1. If both ports are nil, return nil.
    if (recvPort == nil && sendPort == nil) {
        [self release];
        return nil;
    }
    // 2. If we have a send port but not a receive port,
    // create a receive port of the same type.
    if (recvPort == nil) {
        recvPort = [[[[sendPort class] alloc] init] autorelease];
    }
    // 3. If we have a receive port but not a send port,
    // use the same port for both.
    if (sendPort == nil) {
        sendPort = recvPort;
    }

    // 4. If there's an existing connection, return that.
    NSConnection *existing = [[self class]
        lookUpConnectionWithReceivePort: recvPort
                               sendPort: sendPort];

    if (existing) {
        [self release];
        return [existing retain];
    }

    // 5. Otherwise, create a new connection.
    _recvPort = [recvPort retain];
    _sendPort = [sendPort retain];
    _isValid = YES;

    // 6. If there's a connection that uses our receive port
    // as both its receive and send port, it's our parent.
    NSConnection *parent = [[self class]
        lookUpConnectionWithReceivePort: recvPort
                               sendPort: recvPort];
    if (parent == nil) {
        _requestTimeout = [[NSDate distantFuture] timeIntervalSinceNow];
        _replyTimeout = [[NSDate distantFuture] timeIntervalSinceNow];

        _runLoops = [NSMutableArray new];
        [_runLoops addObject: [NSRunLoop currentRunLoop]];
        _requestModes = [NSMutableArray new];
        [self addRequestMode: NSDefaultRunLoopMode];
        [self addRequestMode: NSConnectionReplyMode];
    } else {
        NSDOLog(@"found parent connection %@", parent);
        // Copy settings from our parent.
        _requestTimeout = parent->_requestTimeout;
        _replyTimeout = parent->_replyTimeout;
        _rootObject = [parent->_rootObject retain];

        _runLoops = [parent->_runLoops mutableCopy];
        // Add modes via addRequestMode:, which will actually
        // register us.
        for (NSRunLoopMode mode in parent->_requestModes) {
            [self addRequestMode: mode];
        }

        // Ask the parent's delegate for permission.
        id<NSConnectionDelegate> parentDelegate = [parent delegate];
        if ([parentDelegate respondsToSelector: @selector(connection:shouldMakeNewConnection:)]) {
            if (![parentDelegate connection: parent shouldMakeNewConnection: self]) {
                [self release];
                return nil;
            }
        }
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"NSForceUnkeyedPortCoder"]) {
        _canUseKeyedCoder = NO;
    } else {
        _canUseKeyedCoder = MAYBE;
    }

    _classVersions = [NSMutableDictionary new];
    _releasedProxies = [NSMutableArray new];
    _sequenceNumberToRunLoop = [NSMutableDictionary new];
    _sequenceNumberToCoder = [NSMutableDictionary new];

    @synchronized (allConnections) {
        [allConnections addObject: self];
    }

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    [center addObserver: self
               selector: @selector(invalidate)
                   name: NSPortDidBecomeInvalidNotification
                 object: recvPort];

    if (sendPort != recvPort) {
        [center addObserver: self
                   selector: @selector(invalidate)
                       name: NSPortDidBecomeInvalidNotification
                     object: sendPort];
    }

    [center postNotificationName: NSConnectionDidInitializeNotification
                          object: self];

    return self;
}

+ (NSConnection *) defaultConnection {
    return NSThreadSharedInstance(@"NSConnection");
}

+ (NSArray<NSConnection *> *) allConnections {
    return allConnections;
}

+ (instancetype) lookUpConnectionWithReceivePort: (NSPort *) recvPort
                                        sendPort: (NSPort *) sendPort
{
    @synchronized (allConnections) {
        for (NSConnection *connection in allConnections) {
            if (connection->_recvPort == recvPort && connection->_sendPort == sendPort) {
                return connection;
            }
        }
    }
    return nil;
}

+ (instancetype) connectionWithReceivePort: (NSPort *) recvPort
                                  sendPort: (NSPort *) sendPort
{
    NSConnection *connection;
    connection = [[self alloc] initWithReceivePort: recvPort
                                          sendPort: sendPort];
    return [connection autorelease];
}

- (void) dealloc {
    BOOL wasValid = _runLoops != nil;
    [self invalidate];
    if (wasValid) {
        // Only log the message if we're deallocating a connection that was
        // actually initialized, rather then a temporary object created and
        // quickly deallocated in +[NSConnection connectionWith...].
        NSDOLog(@"%@", self);
    }
    [super dealloc];
}

- (BOOL) isValid {
    return _isValid;
}

- (void) invalidate {
    BOOL wasValid = atomic_exchange(&_isValid, NO);
    if (!wasValid) {
        // Lost the race to invalidate this connection; some other thread is
        // going to invalidate us. Or maybe we are already invalidated. In any
        // case, there's nothing for us to do.
        return;
    }
    NSDOLog(@"%@", self);

    for (NSRunLoopMode mode in [_requestModes copy]) {
        [self removeRequestMode: mode];
    }
    [_requestModes release];
    _requestModes = nil;
    [_runLoops release];
    _runLoops = nil;

    if ([_releasedProxies count] > 0 && _sendPort != nil) {
        [self sendReleasedProxies];
    }
    [_releasedProxies release];
    _releasedProxies = nil;
    [_classVersions release];
    _classVersions = nil;
    [_sequenceNumberToRunLoop release];
    _sequenceNumberToRunLoop = nil;
    [_sequenceNumberToCoder release];
    _sequenceNumberToCoder = nil;

    [_sendPort release];
    _sendPort = nil;
    [_recvPort release];
    _recvPort = nil;
    [_rootObject release];
    _rootObject = nil;

    // TODO: invalidate all the proxies.

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver: self];
    [center postNotificationName: NSConnectionDidDieNotification
                          object: self];

    [allConnections removeObjectIdenticalTo: self];
}

// Names.

+ (instancetype) serviceConnectionWithName: (NSString *) name
                                rootObject: (id) rootObject
                           usingNameServer: (NSPortNameServer *) portNameServer
{
    NSPort *recvPort;
    if ([portNameServer respondsToSelector: @selector(servicePortWithName:)]) {
        recvPort = [(NSMachBootstrapServer *) portNameServer servicePortWithName: name];
    } else {
        recvPort = [NSPort port];
        [portNameServer registerPort: recvPort name: name];
    }
    NSConnection *connection = [NSConnection connectionWithReceivePort: recvPort
                                                              sendPort: nil];
    [connection setRootObject: rootObject];
    return connection;
}

+ (instancetype) serviceConnectionWithName: (NSString *) name
                                rootObject: (id) rootObject
{
    return [self serviceConnectionWithName: name
                                rootObject: rootObject
                           usingNameServer: [NSPortNameServer systemDefaultPortNameServer]];
}

- (BOOL) registerName: (NSString *) name {
    return [self registerName: name
               withNameServer: [NSPortNameServer systemDefaultPortNameServer]];
}

- (BOOL) registerName: (NSString *) name
       withNameServer: (NSPortNameServer *) portNameServer
{
    return [portNameServer registerPort: _recvPort name: name];
}

+ (instancetype) connectionWithRegisteredName: (NSString *) name
                                         host: (NSString *) hostName
{
    return [self connectionWithRegisteredName: name
                                         host: hostName
                              usingNameServer: [NSPortNameServer systemDefaultPortNameServer]];
}

+ (instancetype) connectionWithRegisteredName: (NSString *) name
                                         host: (NSString *) hostName
                              usingNameServer: (NSPortNameServer *) portNameServer
{
    NSPort *sendPort = [portNameServer portForName: name host: hostName];
    return [NSConnection connectionWithReceivePort: nil
                                          sendPort: sendPort];
}

+ (NSDistantObject *) rootProxyForConnectionWithRegisteredName: (NSString *) name
                                                          host: (NSString *) hostName
{
    NSConnection *connection = [self connectionWithRegisteredName: name host: hostName];
    return [connection rootProxy];
}

+ (NSDistantObject *) rootProxyForConnectionWithRegisteredName: (NSString *) name
                                                          host: (NSString *) hostName
                                               usingNameServer: (NSPortNameServer *) portNameServer
{
    NSConnection *connection = [self connectionWithRegisteredName: name
                                                             host: hostName
                                                  usingNameServer: portNameServer];
    return [connection rootProxy];
}

// Invocations.

- (void) sendInvocation: (NSInvocation *) invocation {
    [self sendInvocation: invocation internal: NO];
}

- (void) sendInvocation: (NSInvocation *) invocation
               internal: (BOOL) internal
{
    @autoreleasepool {
        if (!_isValid) {
            // Sorry, we no longer accept new invocations.
            [NSException raise: NSInvalidReceivePortException
                        format: @"attempted to send an invocation using an invalid connection"];
            return;
        }
        // Invocations are organized into *sequences* (and also, conversations).
        // A request-reply pair shares a sequence number.
        NSConnectionMessageMagic magic = NSConnectionMessageMagicRequest;
        uint32_t sequenceNumber = ++lastSequenceNumber;
        BOOL isOneway = [[invocation methodSignature] isOneway];
        id conversation = nil;

        if (!isOneway) {
            conversation = [[self newConversation] autorelease];
            // TODO: check how Apple initialize the conversation...
        }

        NSDOLog(@"invocation %@, sequenceNumber %u, conversation %@", invocation, sequenceNumber, conversation);

        NSConcretePortCoder *coder = [self portCoderWithComponents: nil];
        if ([coder allowsKeyedCoding]) {
            [coder encodeInt: magic forKey: @"id"];
            [coder encodeInt: sequenceNumber forKey: @"seq"];
            [coder encodeObject: invocation forKey: @"inv"];
            [coder encodeObject: conversation forKey: @"con"];
        } else {
            [coder encodeValueOfObjCType: @encode(unsigned int) at: &magic];
            [coder encodeValueOfObjCType: @encode(unsigned int) at: &sequenceNumber];
            [coder encodeObject: invocation];
            [coder encodeObject: conversation];
        }
        [self encodeReleasedProxies: coder];

        NSDOLog(@"going to send the request");
        [self _sendUsingCoder: coder];
        [coder invalidate];

        if (isOneway) {
            // No need to wait for a reply, so we're done here!
            return;
        }
        // Otherwise, we're going to wait for a reply.
        NSDate *replyDeadline = [NSDate dateWithTimeIntervalSinceNow: _replyTimeout];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        @synchronized (_sequenceNumberToRunLoop) {
            _sequenceNumberToRunLoop[@(sequenceNumber)] = runLoop;
        }

        // Prepare to use this run loop.
        BOOL runLoopRegistered = [_runLoops containsObject: runLoop];
        if (!runLoopRegistered) {
            [_recvPort addConnection: self
                           toRunLoop: runLoop
                             forMode: NSConnectionReplyMode];
        }

        NSDOLog(@"waiting for a reply...");

        // Loop while we haven't received our reply. We may receive other
        // messages, such as nested requests and messages meant for other
        // threads, in between.
        do {
            @autoreleasepool {
                BOOL success = [runLoop runMode: NSConnectionReplyMode beforeDate: replyDeadline];
                NSAssert(success, @"failed to run run loop");
            }
            // If we have received the reply message, we should find the coder in
            // this dictionary:
            @synchronized (_sequenceNumberToCoder) {
                coder = _sequenceNumberToCoder[@(sequenceNumber)];
            }
        } while (coder == nil && [replyDeadline compare: [NSDate date]] == NSOrderedDescending);

        // Let go of the run loop.
        @synchronized (_sequenceNumberToRunLoop) {
            [_sequenceNumberToRunLoop removeObjectForKey: @(sequenceNumber)];
        }
        if (!runLoopRegistered) {
            [_recvPort removeConnection: self
                            fromRunLoop: runLoop
                                forMode: NSConnectionReplyMode];
        }

        // Did we get a reply?
        if (coder == nil) {
            [NSException raise: NSPortTimeoutException
                        format: @"timed out waiting for a reply"];
        }
        // Yes we did!
        NSDOLog(@"got a reply");
        [coder retain];
        @synchronized (_sequenceNumberToCoder) {
            [_sequenceNumberToCoder removeObjectForKey: @(sequenceNumber)];
        }

        // Let's check if it's an exception or a successful return. Note that
        // decoding the invocation's return value will automatically write it back
        // into the invocation (e.g. using setReturnValue:), so we don't need do
        // anything special to actually return the value.
        NSException *exception;
        if ([coder allowsKeyedCoding]) {
            NSKeyedPortCoder *keyedCoder = (NSKeyedPortCoder *) coder;
            exception = [keyedCoder decodeObjectForKey: @"exc"];
            if (!exception) {
                [keyedCoder decodeReturnValueOfInvocation: invocation forKey: @"ret"];
            }
        } else {
            NSUnkeyedPortCoder *unkeyedCoder = (NSUnkeyedPortCoder *) coder;
            exception = [unkeyedCoder decodeObject];
            if (!exception) {
                [unkeyedCoder decodeReturnValue: invocation];
            }
        }
        [self decodeReleasedProxies: coder];
        [coder invalidate];
        // Balance the retain above.
        [coder release];

        if (exception) {
            @throw exception;
        }
    }
}

- (void) _replyToInvocation: (NSInvocation *) invocation
              withException: (NSException *) exception
             sequenceNumber: (uint32_t) sequenceNumber
              releasingPool: (NSAutoreleasePool *) pool
{
    NSDOLog(@"replying to sequence number %d exception %@", sequenceNumber, exception);
    NSConnectionMessageMagic magic = NSConnectionMessageMagicReply;

    // We retain the coder to make sure it doesn't go away when we release the pool below.
    NSConcretePortCoder *coder = [[self portCoderWithComponents: nil] retain];
    if ([coder allowsKeyedCoding]) {
        NSKeyedPortCoder *keyedCoder = (NSKeyedPortCoder *) coder;
        [keyedCoder encodeInt: magic forKey: @"id"];
        [keyedCoder encodeInt: sequenceNumber forKey: @"seq"];
        [keyedCoder encodeObject: exception forKey: @"exc"];
        if (exception == nil) {
            [keyedCoder encodeReturnValueOfInvocation: invocation forKey: @"ret"];
        }
    } else {
        NSUnkeyedPortCoder *unkeyedCoder = (NSUnkeyedPortCoder *) coder;
        [unkeyedCoder encodeValueOfObjCType: @encode(unsigned int) at: &magic];
        [unkeyedCoder encodeValueOfObjCType: @encode(unsigned int) at: &sequenceNumber];
        [unkeyedCoder encodeObject: exception];
        if (exception == nil) {
            [unkeyedCoder encodeReturnValue: invocation];
        }
    }

    // Release the pool after encoding the exception and the invocation, but
    // before encoding released proxies. We do it this way because both the
    // invocation and the exception are very likely to be allocated in that
    // pool, and we don't want to invalidate them too early; and at the same
    // time it's likely that nothing else retains them, so we would prefer to
    // tell the remote we've released them in this very message.
    [pool release];

    [self encodeReleasedProxies: coder];
    [self _sendUsingCoder: coder];
    [coder invalidate];
    [coder release];
}

- (void) handleRequest: (NSConcretePortCoder *) coder
        sequenceNumber: (uint32_t) sequenceNumber
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSInvocation *invocation;
    id conversation;
    if ([coder allowsKeyedCoding]) {
        invocation = [coder decodeObjectForKey: @"inv"];
        conversation = [coder decodeObjectForKey: @"con"];
    } else {
        invocation = [coder decodeObject];
        conversation = [coder decodeObject];
    }
    [self decodeReleasedProxies: coder];
    [coder invalidate];

    BOOL isOneway = [[invocation methodSignature] isOneway];

    // Let's see if the delegate wants to handle this request...
    if ([_delegate respondsToSelector: @selector(connection:handleRequest:)]) {
        NSConcreteDistantObjectRequest *request = [NSConcreteDistantObjectRequest alloc];
        [request initWithConversation: conversation
                           connection: self
                           invocation: invocation
                       sequenceNumber: sequenceNumber
                        releasingPool: pool];
        BOOL handled = [_delegate connection: self handleRequest: request];
        [request release];
        if (handled) {
            return;
        }
    }

    NSException *exception = nil;
    @try {
        NSDOLog(@"going to invoke %@", invocation);
        [invocation invoke];
        NSDOLog(@"invoked successfully");
    } @catch (NSException *caught) {
        NSDOLog(@"caught an exception");
        exception = caught;
    } @finally {
        if (!isOneway) {
            [self _replyToInvocation: invocation
                       withException: exception
                      sequenceNumber: sequenceNumber
                       releasingPool: pool];
        } else {
            [pool release];
        }
    }
}

- (void) sendExposeProxyID: (int) id toConnection: (NSConnection *) connection {
    @autoreleasepool {
        NSConnectionMessageMagic magic = NSConnectionMessageMagicExpose;
        NSConcretePortCoder *coder = [self portCoderWithComponents: nil];

        if ([coder allowsKeyedCoding]) {
            // Sic: encode magic for key @"id", and id for key @"wid".
            [coder encodeInt: magic forKey: @"id"];
            [coder encodeInt: id forKey: @"wid"];
        } else {
            [coder encodeValueOfObjCType: @encode(unsigned int) at: &magic];
            [coder encodeValueOfObjCType: @encode(int) at: &id];
        }
        // Note: we encode the port without an explicit key in both cases.
        [coder encodePortObject: [connection sendPort]];
        [self _sendUsingCoder: coder];
        [coder invalidate];
    }
}

- (void) releaseProxyID: (int) id count: (unsigned int) count {
    NSConnectionReleasedProxyRecord record = @[@(id), @(count)];
    @synchronized (self) {
        [_releasedProxies addObject: record];
    }
}

- (void) encodeReleasedProxies: (NSConcretePortCoder *) coder {
    // "Steal" the released proxies, substituting a fresh array.
    NSArray<NSConnectionReleasedProxyRecord> *proxies;
    @synchronized (self) {
        proxies = _releasedProxies;
        _releasedProxies = [NSMutableArray new];
    }
    NSDOLog(@"encoding %lu released proxies", (unsigned long) [proxies count]);

    if ([coder allowsKeyedCoding]) {
        // For keyed coders, we just encode the array as-is.
        [coder encodeObject: proxies forKey: @"rp"];
    } else {
        // But for unkeyed coders, we encode it as raw bytes which internally
        // contain those numbers encoded next to each other. To produce this
        // format, use a temporary coder.
        NSMutableData *data = [NSMutableData data];
        NSUnkeyedPortCoder *tempCoder = [NSUnkeyedPortCoder alloc];
        [tempCoder initWithReceivePort: nil
                              sendPort: nil
                            components: @[data]];
        for (NSArray<NSNumber *> *record in proxies) {
            int id = [record[0] intValue];
            int count = [record[1] intValue];
            [tempCoder encodeValueOfObjCType: @encode(int) at: &id];
            [tempCoder encodeValueOfObjCType: @encode(int) at: &count];
        }
        [coder encodeBytes: [data bytes] length: [data length]];
        [tempCoder invalidate];
        [tempCoder release];
    }
    [proxies release];
}

- (void) decodeReleasedProxies: (NSConcretePortCoder *) coder {
    if ([coder allowsKeyedCoding]) {
        NSArray *proxies = [coder decodeObjectForKey: @"rp"];
        [self handleKeyedReleasedProxies: proxies];
    } else {
        NSUInteger length;
        void *bytes = [coder decodeBytesWithReturnedLength: &length];
        [self handleUnkeyedReleasedProxies: bytes length: length];
    }
}

- (void) handleUnkeyedReleasedProxies: (void *) bytes length: (NSUInteger) length {
    if (bytes == NULL) {
        return;
    }
    NSData *data = [NSData dataWithBytesNoCopy: bytes
                                        length: length
                                  freeWhenDone: NO];
    NSUnkeyedPortCoder *tempCoder = [NSUnkeyedPortCoder alloc];
    [tempCoder initWithReceivePort: nil
                          sendPort: nil
                        components: @[data]];

    while ([tempCoder _hasMoreData]) {
        int id, count;
        [tempCoder decodeValueOfObjCType: @encode(int) at: &id];
        [tempCoder decodeValueOfObjCType: @encode(int) at: &count];

        NSDistantObject *proxy;
        proxy = [NSDistantObject proxyWithConnection: self
                                                  id: id
                                                type: NSDistantObjectTypeLocalProxy];
        [NSDistantObject wireRelease: proxy count: count];
    }

    [tempCoder invalidate];
    [tempCoder release];
}

- (void) handleKeyedReleasedProxies: (NSArray<NSConnectionReleasedProxyRecord> *) records {
    for (NSArray<NSNumber *> *record in records) {
        int id = [record[0] intValue];
        int count = [record[1] intValue];

        NSDistantObject *proxy;
        proxy = [NSDistantObject proxyWithConnection: self
                                                  id: id
                                                type: NSDistantObjectTypeLocalProxy];
        [NSDistantObject wireRelease: proxy count: count];
    }
}

- (void) sendReleasedProxies {
    @autoreleasepool {
        NSConcretePortCoder *coder = [self portCoderWithComponents: nil];
        NSConnectionMessageMagic magic = NSConnectionMessageMagicRelease;

        if ([coder allowsKeyedCoding]) {
            [coder encodeInt: magic forKey: @"id"];
        } else {
            [coder encodeValueOfObjCType: @encode(unsigned int) at: &magic];
        }

        [self encodeReleasedProxies: coder];
        [self _sendUsingCoder: coder];
        [coder invalidate];
    }
}

- (void) handlePortCoder: (NSConcretePortCoder *) coder {
    @autoreleasepool {
        NSDOLog(@"got a message");
        NSConnectionMessageMagic magic;
        uint32_t sequenceNumber;
        if ([coder allowsKeyedCoding]) {
            // Sic: magic for key @"id".
            magic = [coder decodeIntForKey: @"id"];
        } else {
            [coder decodeValueOfObjCType: @encode(unsigned int) at: &magic];
        }

        if (magic == NSConnectionMessageMagicRequest || magic == NSConnectionMessageMagicReply) {
            if ([coder allowsKeyedCoding]) {
                sequenceNumber = [coder decodeIntForKey: @"seq"];
            } else {
                [coder decodeValueOfObjCType: @encode(unsigned int) at: &sequenceNumber];
            }
            NSDOLog(@"...with sequence number %d", sequenceNumber);
        }

        switch (magic) {
        case NSConnectionMessageMagicRequest:
            [self handleRequest: coder sequenceNumber: sequenceNumber];
            break;
        case NSConnectionMessageMagicReply:
            @synchronized (_sequenceNumberToCoder) {
                _sequenceNumberToCoder[@(sequenceNumber)] = coder;
            }
            // Wake up whoever's waiting for this reply.
            // It might be us, or it might be another thread.
            NSRunLoop *runLoop;
            @synchronized (_sequenceNumberToRunLoop) {
                runLoop = _sequenceNumberToRunLoop[@(sequenceNumber)];
            }
            NSDOLog(@"waking up %@", runLoop);
            [runLoop _wakeup];
            break;
        case NSConnectionMessageMagicRelease:
            [self decodeReleasedProxies: coder];
            [coder invalidate];
            break;
        case NSConnectionMessageMagicExpose:
            {
                int id;
                if ([coder allowsKeyedCoding]) {
                    id = [coder decodeIntForKey: @"wid"];
                } else {
                    [coder decodeValueOfObjCType: @encode(int) at: &id];
                }
                // Note: we decode the port without an explicit key in both cases.
                NSPort *sendPort = [coder decodePortObject];
                NSConnection *connection;
                connection = [[self class] connectionWithReceivePort: _recvPort
                                                            sendPort: sendPort];
                [NSDistantObject exposeLocalProxyFromConnection: self
                                                   toConnection: connection
                                                             id: id];
                [coder invalidate];
                break;
            }
        default:
            NSDOLog(@"unexpected message magic %x", magic);
            [coder invalidate];
            break;
        }
    }
}

- (void) addClassNamed: (const char *) className
               version: (NSInteger) version
{
    @synchronized (_classVersions) {
        _classVersions[@(className)] = @(version);
    }
}

- (NSInteger) versionForClassNamed: (NSString *) className {
    @synchronized (_classVersions) {
        return [_classVersions[className] integerValue];
    }
}

- (NSDistantObject *) rootProxy {
    // The NSConnection on the remote is represented as a proxy with a special
    // ID 0 -- both sides just assume it to exist from the very start, and
    // there's no need to ask the remote about exposing it. So we can make a
    // local proxy for it without asking the remote.
    NSConnection *remoteConnection = (NSConnection *)
        [NSDistantObject proxyWithConnection: self
                                          id: 0
                                        type: NSDistantObjectTypeRemoteProxy];

    // Now, we can ask remote connection for its root object "directly".
    // But since this is may be the first time we talk to the remote,
    // we also want to try and figure out if it supports NSKeyedPortCoder.
    // For this, we use a special method, keyedRootObject, that returns
    // the same root object, but (if executed successfully) lets both
    // sides know they both support NSKeyedPortCoder.
    switch ((unsigned int) _canUseKeyedCoder) {
    case YES:
        NSDOLog(@"can use NSKeyedPortCoder, using keyedRootObject");
        return [remoteConnection keyedRootObject];
    case NO:
        NSDOLog(@"cannot use NSKeyedPortCoder, using rootObject");
        return [remoteConnection rootObject];
    case MAYBE:
        @try {
            // Try using keyedRootObject. Note that we'll still use
            // NSUnkeyedPortCoder for this request itself.
            NSDOLog(@"attempting to invoke keyedRootObject");
            id rootProxy = [remoteConnection keyedRootObject];
            // If no exception got thrown, the remote supports NSKeyedPortCoder!
            _canUseKeyedCoder = YES;
            return rootProxy;
        } @catch (NSException *exception) {
            // Old versions of Cocoa don't support NSKeyedPortCoder and don't
            // have the keyedRootObject method, so we'll get an unknown method
            // exception.
            if ([[exception name] isEqual: NSInvalidArgumentException]) {
                NSDOLog(@"got an exception %@;"
                        " assuming remote doesn't support NSKeyedPortCoder", exception);
                _canUseKeyedCoder = NO;
                return [remoteConnection rootObject];
            } else {
                NSDOLog(@"got an unexpected exception %@", exception);
                @throw;
            }
        }
    }
}

- (id) keyedRootObject {
    if (_canUseKeyedCoder == NO) {
        // Pretend we got an unrecognized selector.
        [self doesNotRecognizeSelector: _cmd];
    }
    // If the remote is calling this, it supports NSKeyedPortCoder!
    _canUseKeyedCoder = YES;
    return _rootObject;
}

- (void) addRunLoop: (NSRunLoop *) runLoop {
    @synchronized (_runLoops) {
        if ([_runLoops containsObject: runLoop]) {
            return;
        }
        [_runLoops addObject: runLoop];
        for (NSRunLoopMode mode in _requestModes) {
            [_recvPort addConnection: self
                           toRunLoop: runLoop
                             forMode: mode];
        }
    }
}

- (void) removeRunLoop: (NSRunLoop *) runLoop {
    @synchronized (_runLoops) {
        if (![_runLoops containsObject: runLoop]) {
            return;
        }
        [_runLoops removeObjectIdenticalTo: runLoop];
        for (NSRunLoopMode mode in _requestModes) {
            [_recvPort removeConnection: self
                            fromRunLoop: runLoop
                                forMode: mode];
        }
    }
}

- (void) addRequestMode: (NSRunLoopMode) mode {
    // Note: locking the loops, not the modes array.
    @synchronized (_runLoops) {
        if ([_requestModes containsObject: mode]) {
            return;
        }
        [_requestModes addObject: mode];
        for (NSRunLoop *runLoop in _runLoops) {
            [_recvPort addConnection: self
                           toRunLoop: runLoop
                             forMode: mode];
        }
    }
}

- (void) removeRequestMode: (NSRunLoopMode) mode {
    // Note: locking the loops, not the modes array.
    @synchronized (_runLoops) {
        if (![_requestModes containsObject: mode]) {
            return;
        }
        [_requestModes removeObject: mode];
        for (NSRunLoop *runLoop in _runLoops) {
            [_recvPort removeConnection: self
                            fromRunLoop: runLoop
                                forMode: mode];
        }
    }
}

- (void) run {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [self addRunLoop: runLoop];

    NSDate *distantFuture = [NSDate distantFuture];
    while (_isValid) {
        @autoreleasepool {
            [runLoop runMode: NSDefaultRunLoopMode
                  beforeDate: distantFuture];
        }
    }
}

- (void) runInNewThread {
    // We're getting our own thread, so make sure we detach ourselves from this
    // thread.
    [self removeRunLoop: [NSRunLoop currentRunLoop]];
    [NSThread detachNewThreadSelector: @selector(run)
                             toTarget: self
                           withObject: nil];
}

- (Class) _portCoderClass {
    if (_canUseKeyedCoder == YES) {
        return [NSKeyedPortCoder class];
    } else {
        return [NSUnkeyedPortCoder class];
    }
}

- (Class) _portCoderClassWithComponents: (NSArray *) components {
    if (components == nil) {
        return [self _portCoderClass];
    }

    if ([[components lastObject] isEqual: keyedMagic]) {
        return [NSKeyedPortCoder class];
    } else {
        return [NSUnkeyedPortCoder class];
    }
}

- (NSConcretePortCoder *) portCoderWithComponents: (NSArray *) components {
    NSMutableArray *mutableComponents = [[components mutableCopy] autorelease];

    Class portCoderClass;
    if (mutableComponents != nil) {
        id lastObject = [mutableComponents lastObject];
        if ([lastObject isEqual: keyedMagic]) {
            portCoderClass = [NSKeyedPortCoder class];
            [mutableComponents removeLastObject];

            switch ((unsigned int) _canUseKeyedCoder) {
            case YES:
                break;
            case MAYBE:
                NSDOLog(@"got a keyed-coded message from the remote,"
                        " assuming it supports NSKeyedPortCoder");
                _canUseKeyedCoder = YES;
                break;
            case NO:
                NSDOLog(@"got an unexpected keyed-coded message from the remote");
                break;
            }

        } else {
            portCoderClass = [NSUnkeyedPortCoder class];
        }
    } else {
        portCoderClass = [self _portCoderClass];
    }

    return (NSConcretePortCoder *)
        [portCoderClass portCoderWithReceivePort: _recvPort
                                        sendPort: _sendPort
                                      components: mutableComponents];
}

- (void) _sendUsingCoder: (NSConcretePortCoder *) coder {
    NSMutableArray *components = [[[coder finishedComponents] mutableCopy] autorelease];

    if ([coder allowsKeyedCoding]) {
        [components addObject: keyedMagic];
    }

    // TODO: what's going on here?
    NSUInteger reserved = [_sendPort reservedSpaceLength];
    if (reserved) {
        NSMutableData *data = [NSMutableData dataWithLength: reserved];
        [data appendData: [components firstObject]];
        components[0] = data;
    }

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: _requestTimeout];
    [_sendPort sendBeforeDate: deadline
                        msgid: 0
                   components: components
                         from: _recvPort
                     reserved: reserved];
}

- (id) newConversation {
    if ([_delegate respondsToSelector: @selector(createConversationForConnection:)]) {
        return [_delegate createConversationForConnection: self];
    }
    return nil; // [NSObject new];
}

// TODO: the docs seem to say NSPort should invoke this,
// but also that it should invoke handlePortMessage:?
// Which one is it?
- (void) dispatchWithComponents: (NSArray *) components {
    NSConcretePortCoder *coder = [self portCoderWithComponents: components];
    if (coder) {
        [self handlePortCoder: coder];
    }
}

- (void) handlePortMessage: (NSPortMessage *) portMessage {
    NSAssert(
        [portMessage receivePort] == _recvPort,
        @"somehow got a message for a different receive port"
    );
    if ([portMessage sendPort] == nil) {
        NSDOLog(@"received a message with no send port, dropping");
        return;
    }

    // Now, decide which connection should handle this message. It may be us, or
    // it may be our child (if we're a service connection), or it may be a child
    // connection we are going to create, if this is somebody new talking to us.
    NSConnection *connection = [[self class]
        connectionWithReceivePort: [portMessage receivePort]
                         sendPort: [portMessage sendPort]];
    [connection dispatchWithComponents: [portMessage components]];
}

@end
