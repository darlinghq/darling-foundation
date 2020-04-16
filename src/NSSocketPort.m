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

#import <Foundation/NSSocketPort.h>
#import <Foundation/NSHost.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSException.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSPortMessage.h>
#import <Foundation/NSNotificationCenter.h>
#import <CoreFoundation/CFSocket.h>
#import "CFInternal.h"

#import <sys/types.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

typedef NS_ENUM(uint32_t, NSSocketPortMagic) {
    // Identifies a message.
    NSSocketPortMagicMessage = 0xc050cfd0,
    // Identifies a data component within a message.
    NSSocketPortMagicData = 1 << 24,
    // Identifies a port component (represented as its signature) within a message.
    NSSocketPortMagicPort = 1 << 25,
};

struct NSSocketPortMessageHeader {
    NSSocketPortMagic magic;
    uint32_t size;
    uint32_t msgid;
};

struct NSSocketPortComponentHeader {
    NSSocketPortMagic magic;
    uint32_t size;
};

struct NSSocketPortSignatureHeader {
    unsigned char protocolFamily;
    unsigned char socketType;
    unsigned char protocol;
    unsigned char addressLength;
};

static NSMutableDictionary<NSData *, NSSocketPort *> *remoteSignatureToPort;

static NSData *makeSignature(int protocolFamily, int socketType, int protocol, NSData *address) {
    NSUInteger addressLength = [address length];
    if (addressLength > 255) {
        NSLog(@"%s: address is too long", __PRETTY_FUNCTION__);
        return nil;
    }
    if (addressLength >= sizeof(struct sockaddr)) {
        struct sockaddr *sockaddr = (struct sockaddr *) [address bytes];
        // Apple's version trims the passed in address to sa_len/sun_len bytes
        // if it's an AF_UNIX socket, but not for other socket types. This is
        // likely done this way because:
        // 1. Everybody just leaves sa_len as zero for other address types.
        // 2. struct sockaddr_un contains a (variable-length) path, and it
        //    makes sense not to encode the null terminator and the garbage
        //    bytes, and sun_length should be set *not* to include those.
        if (sockaddr->sa_family == AF_UNIX) {
            addressLength = sockaddr->sa_len;
        }
    }
    NSUInteger signatureLength = sizeof(struct NSSocketPortSignatureHeader) + addressLength;
    NSMutableData *signature = [NSMutableData dataWithCapacity: signatureLength];
    // Note: we're using single bytes, so no byte-swapping is necessary.
    // Also note that the address length is essentially encoded twice --
    // in the header and as sa_len inside the address itself.
    struct NSSocketPortSignatureHeader header = { protocolFamily, socketType, protocol, addressLength };
    [signature appendBytes: &header length: sizeof(header)];
    [signature appendBytes: [address bytes] length: addressLength];
    return signature;
}

static BOOL parseSignature(NSData *signature, int *protocolFamily, int *socketType, int *protocol, NSData **address) {
    if ([signature length] < sizeof(struct NSSocketPortSignatureHeader)) {
        NSLog(@"Malformed signature");
        return NO;
    }

    struct NSSocketPortSignatureHeader *signature_header = (struct NSSocketPortSignatureHeader *) [signature bytes];
    if (protocolFamily != NULL) {
        *protocolFamily = signature_header->protocolFamily;
    }
    if (socketType != NULL) {
        *socketType = signature_header->socketType;
    }
    if (protocol != NULL) {
        *protocol = signature_header->protocol;
    }
    if (address != NULL) {
        NSRange addressRange = NSMakeRange(
            sizeof(struct NSSocketPortSignatureHeader),
            signature_header->addressLength
         );
        *address = [signature subdataWithRange: addressRange];
    }
    return YES;
}

static inline BOOL isConnectionOriented(int socketType) {
    return socketType == SOCK_STREAM || socketType == SOCK_SEQPACKET;
}


@implementation NSSocketPort

@synthesize delegate = _delegate;

+ (void) initialize {
    if (self != [NSSocketPort class]) {
        return;
    }

    remoteSignatureToPort = (NSMutableDictionary *)
        CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, NULL);
}

static void invalidateSocket(NSSocketPort *self, CFSocketRef socket) {
    if (self->_receiver == socket) {
        [self invalidate];
        return;
    }

    if (self->_data != NULL) {
        CFDictionaryRemoveValue(self->_data, socket);
    }

    if (self->_connectors == NULL) {
        return;
    }

    CFIndex socketsCount = CFDictionaryGetCount(self->_connectors);
    NSData *signatures[socketsCount];
    CFSocketRef sockets[socketsCount];
    CFDictionaryGetKeysAndValues(self->_connectors, (const void **) signatures, (const void **) sockets);
    for (CFIndex i = 0; i < socketsCount; i++) {
        if (sockets[i] == socket) {
            CFDictionaryRemoveValue(self->_connectors, signatures[i]);
#if 0
            // FIXME: This causes over-invalidation.
            NSSocketPort *remotePort;
            @synchronized (remoteSignatureToPort) {
                remotePort = remoteSignatureToPort[signatures[i]];
            }
            [remotePort invalidate];
#endif
            break;
        }
    }
}

static inline void lazyCreateConnectors(NSSocketPort *self) {
    if (self->_connectors != NULL) {
        return;
    }
    self->_connectors = CFDictionaryCreateMutable(
        NULL, 0,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks
    );
}

static inline void lazyCreateData(NSSocketPort *self) {
    if (self->_data != NULL) {
        return;
    }
    self->_data = CFDictionaryCreateMutable(
        NULL, 0,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks
    );
}

static NSArray<NSPortMessage *> *parseMessages(NSData **messageData, NSSocketPort *recvPort, NSData *peerAddress) {
    NSMutableArray<NSPortMessage *> *messages = [NSMutableArray arrayWithCapacity: 1];
    while (YES) {
        // Let's see if we can read a whole message.
        if ([*messageData length] < sizeof(struct NSSocketPortMessageHeader)) {
            break;
        }
        const unsigned char *message = [*messageData bytes];
        NSUInteger offset = 0;
        struct NSSocketPortMessageHeader *message_header = (struct NSSocketPortMessageHeader *) message;
        if (message_header->magic != NSSocketPortMagicMessage) {
            NSLog(@"Malformed NSSocketPort message");
            return nil;
        }
        offset += sizeof(struct NSSocketPortMessageHeader);

        NSUInteger messageSize = ntohl(message_header->size);
        if ([*messageData length] < messageSize) {
            // ..not yet.
            break;
        }

        unsigned char addressLength = message[offset + 3];
        NSRange signatureRange = NSMakeRange(offset, 4 + addressLength);
        NSData *remoteSignature = [*messageData subdataWithRange: signatureRange];
        int protocolFamily, socketType, protocol;
        NSData *remoteAddress;
        parseSignature(remoteSignature, &protocolFamily, &socketType, &protocol, &remoteAddress);
        if (protocolFamily == AF_INET) {
            // Now, throw away the IP address from the signature and substitute
            // it for the sender's IP address as we know it. This is done
            // because the sender's own idea of its address may be different
            // from our idea -- it may be on a different network (or on
            // several), it may be behind a NAT, and then if it was a listening
            // port, its likely believes its address to be 0.0.0.0.
            remoteAddress = [[remoteAddress mutableCopy] autorelease];
            struct sockaddr_in *remote_sockaddr = [(NSMutableData *) remoteAddress mutableBytes];
            const struct sockaddr_in *peer_sockaddr = [peerAddress bytes];
            remote_sockaddr->sin_addr = peer_sockaddr->sin_addr;
            remoteSignature = makeSignature(protocolFamily, socketType, protocol, remoteAddress);
        }
        NSSocketPort *remotePort = [[[NSSocketPort alloc] _initRemoteWithSignature: remoteSignature] autorelease];
        offset += signatureRange.length;

        NSMutableArray *components = [NSMutableArray arrayWithCapacity: 1];
        while (offset < messageSize) {
            // Locate the component header.
            struct NSSocketPortComponentHeader *component_header =
                (struct NSSocketPortComponentHeader *) (message + offset);
            offset += sizeof(struct NSSocketPortComponentHeader);

            NSRange componentRange = NSMakeRange(offset, ntohl(component_header->size));
            NSData *component = [*messageData subdataWithRange: componentRange];
            offset += componentRange.length;

            if (component_header->magic == NSSocketPortMagicData) {
                // It's just data, take it as is.
                [components addObject: component];
            } else if (component_header->magic == NSSocketPortMagicPort) {
                // It's a port signature.
                NSSocketPort *port = [[[NSSocketPort alloc] _initRemoteWithSignature: component] autorelease];
                [components addObject: port];
            }
        }

        NSPortMessage *portMessage = [[NSPortMessage alloc] initWithSendPort: remotePort
                                                                 receivePort: recvPort
                                                                  components: components];
        [portMessage setMsgid: ntohl(message_header->msgid)];
        [messages addObject: portMessage];
        [portMessage release];

        NSRange remainingRange = NSMakeRange(offset, [*messageData length] - offset);
        *messageData = [*messageData subdataWithRange: remainingRange];
    }
    return messages;
}

static void __NSFireSocketData(CFSocketRef socket, CFSocketCallBackType callbackType,
                               CFDataRef uselessAddress, const void *newlyReceivedData, void *info)
{
    NSSocketPort *self = (NSSocketPort *) info;

    if (!CFSocketIsValid(socket)) {
        invalidateSocket(self, socket);
        return;
    }
    CFDataRef remoteAddress = CFSocketCopyPeerAddress(socket);
    NSArray<NSPortMessage *> *messages;

    @synchronized (self) {
        lazyCreateData(self);
        NSMutableData *previouslyReceivedData = CFDictionaryGetValue(self->_data, socket);
        NSData *data;
        if (previouslyReceivedData != nil) {
            [previouslyReceivedData appendData: newlyReceivedData];
            data = previouslyReceivedData;
        } else {
            data = newlyReceivedData;
        }

        messages = parseMessages(&data, self, (NSData *) remoteAddress);
        CFDictionarySetValue(self->_data, socket, [data mutableCopy]);
    }

    CFRelease(remoteAddress);
    if ([self->_delegate respondsToSelector: @selector(handlePortMessage:)]) {
        for (NSPortMessage *message in messages) {
            [self->_delegate handlePortMessage: message];
        }
    }
}

static void __NSFireSocketAccept(CFSocketRef listeningSocket, CFSocketCallBackType callbackType,
                                 CFDataRef address, const void *data, void *info)
{
    NSSocketPort *self = (NSSocketPort *) info;
    CFSocketNativeHandle nativeSocket = *(CFSocketNativeHandle *) data;

    if (!CFSocketIsValid(listeningSocket)) {
        invalidateSocket(self, listeningSocket);
        return;
    }

    CFSocketContext context = {
        .copyDescription = _NSCFCopyDescription,
        .info = self,
        .release = _NSCFRelease,
        .retain = _NSCFRetain,
        .version = 0
    };
    CFSocketRef acceptedSocket = CFSocketCreateWithNative(NULL, nativeSocket,
                                                          kCFSocketDataCallBack, __NSFireSocketData,
                                                          &context);
    if (acceptedSocket == NULL) {
        // Umm.. something must have gone wrong.
        return;
    }

    @synchronized (self) {
        lazyCreateConnectors(self);
        CFDictionarySetValue(self->_connectors, address, acceptedSocket);

        for (NSRunLoopMode mode in self->_loops) {
            for (NSRunLoop *runLoop in self->_loops[mode]) {
                CFRunLoopRef cfRunLoop = [runLoop getCFRunLoop];
                CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, acceptedSocket, 0);
                CFRunLoopAddSource(cfRunLoop, source, (CFStringRef) mode);
                CFRelease(source);
            }
        }
    }

    CFRelease(acceptedSocket);
}


// Initializers.

- (instancetype) _initWithRetainedCFSocket: (CFSocketRef) CF_CONSUMED socket
                            protocolFamily: (int) protocolFamily
                                socketType: (int) socketType
                                  protocol: (int) protocol
{
    if (socket == NULL) {
        [self release];
        return nil;
    }
    _receiver = socket;

    NSData *address = (NSData *) CFSocketCopyAddress(socket);
    _signature = makeSignature(protocolFamily, socketType, protocol, address);
    [address release];

    _loops = [NSMutableDictionary new];

    return self;
}

- (instancetype) _initRemoteWithSignature: (NSData *) remoteSignature {
    // Here, signature is the remote signature. It specifies the remote port
    // number and address, not ours.
    int protocolFamily, socketType, protocol;
    NSData *remoteAddress;
    if (!parseSignature(remoteSignature, &protocolFamily, &socketType, &protocol, &remoteAddress)) {
        [self release];
        return nil;
    }
    _signature = [remoteSignature retain];

    @synchronized (remoteSignatureToPort) {
        NSSocketPort *existing = remoteSignatureToPort[remoteSignature];
        if (existing != nil) {
            [_signature release];
            _signature = nil;
            [self release];
            return [existing retain];
        }
        remoteSignatureToPort[remoteSignature] = self;
        // It's important here that by the point we release the lock, self is
        // fully initialized and ready to be seen by other threads.
    }

    return self;
}

- (instancetype) init {
    return [self initWithTCPPort: 0];
}

- (instancetype) initWithTCPPort: (unsigned short) port {
    struct sockaddr_in sockaddr = { 0 };
    sockaddr.sin_len = sizeof(sockaddr);
    sockaddr.sin_family = AF_INET;
    sockaddr.sin_port = htons(port);
    NSData *address = [NSData dataWithBytes: &sockaddr length: sizeof(sockaddr)];
    return [self initWithProtocolFamily: AF_INET
                             socketType: SOCK_STREAM
                               protocol: IPPROTO_TCP
                                address: address];
}

- (instancetype) initRemoteWithTCPPort: (unsigned short) port
                                  host: (NSString *) hostName
{
    // First, resolve the host name to an actual address we can use.
    NSHost *host;
    if ([hostName length] == 0) {
        host = [NSHost currentHost];
    } else {
        host = [NSHost hostWithName: hostName];
    }

    NSArray<NSString *> *addresses;
    // Just in case, try the original host name as an address too.
    if (host != nil) {
        addresses = [[host addresses] arrayByAddingObject: hostName];
    } else {
        addresses = @[hostName];
    }

    for (NSString *addressString in addresses) {
        struct sockaddr_in sockaddr = { 0 };
        BOOL ok = inet_pton(AF_INET, [addressString UTF8String], &sockaddr.sin_addr);
        if (!ok) {
            continue;
        }
        sockaddr.sin_len = sizeof(sockaddr);
        sockaddr.sin_family = AF_INET;
        sockaddr.sin_port = htons(port);
        NSData *addressData = [NSData dataWithBytes: &sockaddr length: sizeof(sockaddr)];
        return [self initRemoteWithProtocolFamily: AF_INET
                                       socketType: SOCK_STREAM
                                         protocol: IPPROTO_TCP
                                          address: addressData];
    }

    NSLog(@"Could not parse the host name: %@", hostName);
    [self release];
    return nil;
}

- (instancetype) initWithProtocolFamily: (int) protocolFamily
                             socketType: (int) socketType
                               protocol: (int) protocol
                                address: (NSData *) address
{
    CFSocketCallBackType callbackType;
    CFSocketCallBack callback;
    if (isConnectionOriented(socketType)) {
        callbackType = kCFSocketAcceptCallBack;
        callback = __NSFireSocketAccept;
    } else {
        callbackType = kCFSocketDataCallBack;
        callback = __NSFireSocketData;
    }
    CFSocketContext context = {
        .copyDescription = _NSCFCopyDescription,
        .info = self,
        .release = _NSCFRelease,
        .retain = _NSCFRetain,
        .version = 0
    };
    CFSocketRef socket = CFSocketCreate(NULL, protocolFamily, socketType, protocol,
                                        callbackType, callback, &context);
    if (socket == NULL) {
        [self release];
        return nil;
    }

    // This creates a local listening socket.
    CFSocketError err = CFSocketSetAddress(socket, (CFDataRef) address);

    if (err != kCFSocketSuccess) {
        CFRelease(socket);
        [self release];
        return nil;
    }
    return [self _initWithRetainedCFSocket: socket
                            protocolFamily: protocolFamily
                                socketType: socketType
                                  protocol: protocol];
}

- (instancetype) initRemoteWithProtocolFamily: (int) protocolFamily
                                   socketType: (int) socketType
                                     protocol: (int) protocol
                                      address: (NSData *) remoteAddress
{
    NSData *remoteSignature = makeSignature(protocolFamily, socketType, protocol, remoteAddress);
    return [self _initRemoteWithSignature: remoteSignature];
}

- (instancetype) initWithProtocolFamily: (int) protocolFamily
                             socketType: (int) socketType
                               protocol: (int) protocol
                                 socket: (NSSocketNativeHandle) nativeSocket
{
    CFSocketCallBackType callbackType;
    CFSocketCallBack callback;
    if (isConnectionOriented(socketType)) {
        callbackType = kCFSocketAcceptCallBack;
        callback = __NSFireSocketAccept;
    } else {
        callbackType = kCFSocketDataCallBack;
        callback = __NSFireSocketData;
    }

    CFSocketContext context = {
        .copyDescription = _NSCFCopyDescription,
        .info = self,
        .release = _NSCFRelease,
        .retain = _NSCFRetain,
        .version = 0
    };
    CFSocketRef socket = CFSocketCreateWithNative(NULL, nativeSocket, callbackType, callback, &context);
    if (socket == NULL) {
        [self release];
        return nil;
    }
    return [self _initWithRetainedCFSocket: socket
                            protocolFamily: protocolFamily
                                socketType: socketType
                                  protocol: protocol];
}

- (void) dealloc {
    [self invalidate];
    [super dealloc];
}

- (void) invalidate {
    [[NSNotificationCenter defaultCenter] postNotificationName: NSPortDidBecomeInvalidNotification
                                                        object: self
                                                      userInfo: nil];
    if (_connectors != NULL) {
        CFIndex socketsCount = CFDictionaryGetCount(_connectors);
        CFSocketRef sockets[socketsCount];
        CFDictionaryGetKeysAndValues(_connectors, NULL, (const void **) &sockets[1]);
        for (CFIndex i = 0; i < socketsCount; i++) {
            CFSocketRef socket = sockets[i];
            CFSocketInvalidate(socket);
        }
        CFRelease(_connectors);
        _connectors = NULL;
    }

    if (_data != NULL) {
        CFRelease(_data);
        _data = NULL;
    }

    if (_receiver != NULL) {
        CFSocketInvalidate(_receiver);
        CFRelease(_receiver);
        _receiver = NULL;
    } else if (_signature != nil) {
        @synchronized (remoteSignatureToPort) {
            NSSocketPort *existing = remoteSignatureToPort[_signature];
            if (existing == self) {
                [remoteSignatureToPort removeObjectForKey: _signature];
            }
        }
    }

    // We have invalidated the sockets, that should be enough to get us
    // unregistered from the loops, so just release the housekeeping data.
    [_loops release];
    _loops = nil;
    [_signature release];
    _signature = nil;
    _delegate = nil;
}

- (NSData *) signature {
    return _signature;
}

- (NSSocketNativeHandle) socket {
    if (_receiver == NULL) {
        return -1;
    }
    return CFSocketGetNative(_receiver);
}

- (int) protocolFamily {
    int protocolFamily;
    parseSignature(_signature, &protocolFamily, NULL, NULL, NULL);
    return protocolFamily;
}

- (int) socketType {
    int socketType;
    parseSignature(_signature, NULL, &socketType, NULL, NULL);
    return socketType;
}

- (int) protocol {
    int protocol;
    parseSignature(_signature, NULL, NULL, &protocol, NULL);
    return protocol;
}

- (NSData *) address {
    NSData *address;
    parseSignature(_signature, NULL, NULL, NULL, &address);
    return address;
}

- (void) scheduleInRunLoop: (NSRunLoop *) runLoop
                   forMode: (NSRunLoopMode) mode
{
    CFRunLoopRef cfRunLoop = [runLoop getCFRunLoop];
    @synchronized (self) {
        // Insert the loop/mode pair into _loops.
        NSMutableArray *loops = _loops[mode];
        if (loops != nil) {
            [loops addObject: runLoop];
        } else {
            loops = [NSMutableArray new];
            [loops addObject: runLoop];
            _loops[mode] = loops;
            [loops release];
        }

        // Now, actually create the run loop sources.
        CFIndex socketsCount = 1;
        if (_connectors != NULL) {
            socketsCount += CFDictionaryGetCount(_connectors);
        }
        CFSocketRef sockets[socketsCount];
        sockets[0] = _receiver;
        if (_connectors != NULL) {
            CFDictionaryGetKeysAndValues(_connectors, NULL, (const void **) &sockets[1]);
        }
        for (CFIndex i = 0; i < socketsCount; i++) {
            CFSocketRef socket = sockets[i];
            CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, socket, 0);
            if (source == NULL) {
                invalidateSocket(self, socket);
                continue;
            }
            CFRunLoopAddSource(cfRunLoop, source, (CFStringRef) mode);
            CFRelease(source);
        }
    }
}

- (void) removeFromRunLoop: (NSRunLoop *) runLoop
                   forMode: (NSRunLoopMode) mode
{
    if (!CFSocketIsValid(_receiver)) {
        invalidateSocket(self, _receiver);
        return;
    }

    CFRunLoopRef cfRunLoop = [runLoop getCFRunLoop];
    @synchronized (self) {
        // Remove the loop/mode pair into _loops.
        NSMutableArray *loops = _loops[mode];
        [loops removeObject: runLoop];

        // Now, actually remove the run loop sources.
        CFIndex socketsCount = 1;
        if (_connectors != NULL) {
            socketsCount += CFDictionaryGetCount(_connectors);
        }
        CFSocketRef sockets[socketsCount];
        sockets[0] = _receiver;
        if (_connectors != NULL) {
            CFDictionaryGetKeysAndValues(_connectors, NULL, (const void **) &sockets[1]);
        }
        for (CFIndex i = 0; i < socketsCount; i++) {
            CFSocketRef socket = sockets[i];
            CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, socket, 0);
            if (source == NULL) {
                invalidateSocket(self, socket);
                continue;
            }
            CFRunLoopRemoveSource(cfRunLoop, source, (CFStringRef) mode);
            CFRelease(source);
        }
    }
}

- (CFSocketRef) _sendingSocketForPort: (NSSocketPort *) otherPort
                           beforeTime: (NSTimeInterval) time
{
    NSData *remoteSignature = [otherPort signature];
    CFSocketRef socket;

    @synchronized (self) {
        lazyCreateConnectors(self);

        // Fast path: see if we already have a socket for this remote.
        socket = (CFSocketRef) CFDictionaryGetValue(_connectors, remoteSignature);
        if (socket != NULL) {
            if (CFSocketIsValid(socket)) {
                return socket;
            } else {
                invalidateSocket(self, socket);
                // Proceed to the slow path.
            }
        }

        // Slow path: create a socket and connect to the remote.
        CFSocketContext context = {
            .copyDescription = _NSCFCopyDescription,
            .info = self,
            .release = _NSCFRelease,
            .retain = _NSCFRetain,
            .version = 0
        };
        socket = CFSocketCreate(NULL,
                                [otherPort protocolFamily], [otherPort socketType], [otherPort protocol],
                                kCFSocketDataCallBack, __NSFireSocketData, &context);
        if (socket == NULL) {
            // Something went wrong, give up.
            return NULL;
        }

        // It's not cool at all that we're doing this while holding the lock :(
        CFSocketError err = CFSocketConnectToAddress(socket, (CFDataRef) [otherPort address], time);

        // Verify that has worked and the socket is OK.
        if (err != kCFSocketSuccess || !CFSocketIsValid(socket)) {
            CFSocketInvalidate(socket);
            CFRelease(socket);
            return NULL;
        }

        // Last thing we have to do before committing to this socket is to
        // create a run loop source.
        CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(NULL, socket, 0);
        if (source == NULL) {
            CFSocketInvalidate(socket);
            CFRelease(socket);
            return NULL;
        }

        // Alright, let's save it to the dictionary.
        CFDictionarySetValue(_connectors, remoteSignature, socket);

        // And add it to the run loops.
        for (NSRunLoopMode mode in _loops) {
            for (NSRunLoop *runLoop in _loops[mode]) {
                CFRunLoopAddSource([runLoop getCFRunLoop], source, (CFStringRef) mode);
            }
        }

        CFRelease(source);
        CFRelease(socket);
    }
    return socket;
}

- (BOOL) sendBeforeDate: (NSDate *) date
             components: (NSMutableArray *) components
                   from: (NSPort *) recvPort
               reserved: (NSUInteger) reservedSpaceLength
{
    return [self sendBeforeDate: date
                          msgid: 0
                     components: components
                           from: recvPort
                       reserved: reservedSpaceLength];
}


- (BOOL) sendBeforeDate: (NSDate *) date
                  msgid: (NSUInteger) msgid
             components: (NSMutableArray *) components
                   from: (NSPort *) recvPort
               reserved: (NSUInteger) reservedSpaceLength
{
    return [[self class] sendBeforeTime: [date timeIntervalSinceReferenceDate]
                             streamData: nil
                             components: components
                                     to: self
                                   from: recvPort
                                  msgid: msgid
                               reserved: reservedSpaceLength];
}

- (BOOL) sendBeforeTime: (NSTimeInterval) time
             streamData: (id) streamData
             components: (NSMutableArray *) components
                   from: (NSPort *) recvPort
                  msgid: (NSUInteger) msgid
{
    return [[self class] sendBeforeTime: time
                             streamData: streamData
                             components: components
                                     to: self
                                   from: recvPort
                                  msgid: msgid
                               reserved: [self reservedSpaceLength]];
}

+ (BOOL) sendBeforeTime: (NSTimeInterval) time
             streamData: (id) streamData
             components: (NSMutableArray *) components
                     to: (NSPort *) sendPort
                   from: (NSPort *) recvPort
                  msgid: (NSUInteger) msgid
               reserved: (NSUInteger) reservedSpaceLength
{
    CFSocketRef socket = [(NSSocketPort *) recvPort _sendingSocketForPort: (NSSocketPort *) sendPort
                                                               beforeTime: time];
    if (socket == NULL) {
        NSLog(@"Failed to connect to port %@", sendPort);
        return NO;
    }

    NSMutableData *message = [NSMutableData dataWithCapacity: 256];
    struct NSSocketPortMessageHeader message_header = {
        .magic = NSSocketPortMagicMessage,
        .size = 0,  /* to be replaced */
        .msgid = htonl(msgid)
    };
    [message appendBytes: &message_header length: sizeof(message_header)];
    [message appendData: [(NSSocketPort *) recvPort signature]];

    for (id component in components) {
        NSData *data;
        struct NSSocketPortComponentHeader component_header;

        if ([component isKindOfClass: [NSData class]]) {
            data = component;
            component_header.magic = NSSocketPortMagicData;
        } else if ([component isKindOfClass: [NSSocketPort class]]) {
            data = [(NSSocketPort *) component signature];
            component_header.magic = NSSocketPortMagicPort;
        } else {
            [NSException raise: NSPortSendException
                        format: @"%s: cannot encode object of type %@",
                         __PRETTY_FUNCTION__, [component class]];
            return NO;
        }

        component_header.size = htonl([data length]);
        [message appendBytes: &component_header length: sizeof(component_header)];
        [message appendData: data];
    }

    uint32_t length = htonl([message length]);
    [message replaceBytesInRange: NSMakeRange(4, 4) withBytes: &length];

    return CFSocketSendData(socket, NULL, (CFDataRef) message, time) == kCFSocketSuccess;
}

- (void) addConnection: (NSConnection *) connection
             toRunLoop: (NSRunLoop *) runLoop
               forMode: (NSString *) mode
{
    if (runLoop) {
        [super addConnection: connection
                   toRunLoop: runLoop
                     forMode: mode];
        if (![self delegate]) {
            [self setDelegate: (id<NSPortDelegate>) connection];
        }
    }
}


@end
