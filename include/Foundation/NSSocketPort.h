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

#import <Foundation/NSPort.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSRunLoop.h>
#import <CoreFoundation/CFSocket.h>
#import <CoreFoundation/CFDictionary.h>

typedef CFSocketNativeHandle NSSocketNativeHandle;

// NSSocketPort is an attempt to emulate Mach port semantics over BSD sockets.
// NSSocketPort instances come in two parts: *local* and *remote* ones. A remote
// socket port basically only stores the remote address (signature) and does not
// own (or even correspond to) any sockets. A local socket port keeps a
// listening socket and a few *connectors* -- sockets connected to a remote or
// accepted from a remote.
NS_AUTOMATED_REFCOUNT_WEAK_UNAVAILABLE
@interface NSSocketPort : NSPort {
    // A listening socket.
    CFSocketRef _receiver;
    // Maps remote signatures to accepted sockets.
    CFMutableDictionaryRef _connectors;
    // Run loops and modes this socket port is currently added to.
    NSMutableDictionary<NSRunLoopMode, NSMutableArray *> *_loops;
    // Maps connectors sockets to the received data.
    CFMutableDictionaryRef _data;
    // Port signature -- encodes protocol family, socket type, protocol and address.
    NSData *_signature;
    id<NSPortDelegate> _delegate;
}

@property (readonly) int protocolFamily;
@property (readonly) int socketType;
@property (readonly) int protocol;
@property (readonly, copy) NSData *address;

@property (readonly) NSSocketNativeHandle socket;
@property (assign) id<NSPortDelegate> delegate;

- (instancetype) init;

- (instancetype) initWithTCPPort: (unsigned short) port;
- (instancetype) initRemoteWithTCPPort: (unsigned short) port
                                  host: (NSString *) hostName;

- (instancetype) initWithProtocolFamily: (int) protocolFamily
                             socketType: (int) socketType
                               protocol: (int) protocol
                                address: (NSData *) address;

- (instancetype) initRemoteWithProtocolFamily: (int) protocolFamily
                                   socketType: (int) socketType
                                     protocol: (int) protocol
                                      address: (NSData *) address;

- (instancetype) initWithProtocolFamily: (int) protocolFamily
                             socketType: (int) socketType
                               protocol: (int) protocol
                                 socket: (NSSocketNativeHandle) socket;


@end
