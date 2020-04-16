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

@class NSAutoreleasePool;

@interface NSConnection (Internal)

+ (nullable instancetype) lookUpConnectionWithReceivePort: (NSPort *) recvPort
                                                 sendPort: (NSPort *) sendPort;

// Invocations.
- (void) sendInvocation: (NSInvocation *) invocation;
- (void) sendInvocation: (NSInvocation *) invocation
               internal: (BOOL) internal;

- (void) _replyToInvocation: (NSInvocation *) invocation
              withException: (NSException *) exception
             sequenceNumber: (uint32_t) sequenceNumber
              releasingPool: (NSAutoreleasePool *) pool;

- (void) handleRequest: (NSConcretePortCoder *) coder
        sequenceNumber: (uint32_t) sequenceNumber;

- (void) handlePortCoder: (NSConcretePortCoder *) coder;
- (void) dispatchWithComponents: (NSArray *) components;
- (void) handlePortMessage: (NSPortMessage *) portMessage;

- (void) sendExposeProxyID: (int) id toConnection: (NSConnection *) connection;

// Releasing proxies.
- (void) releaseProxyID: (int) id count: (unsigned int) count;
- (void) encodeReleasedProxies: (NSConcretePortCoder *) coder;
- (void) decodeReleasedProxies: (NSConcretePortCoder *) coder;
- (void) handleKeyedReleasedProxies: (NSArray<NSConnectionReleasedProxyRecord> *) records;
- (void) handleUnkeyedReleasedProxies: (void *) bytes length: (NSUInteger) length;
- (void) sendReleasedProxies;

// Tracking class versions.
- (void) addClassNamed: (const char *) className
               version: (NSInteger) version;
- (NSInteger) versionForClassNamed: (NSString *) className;

// Run loops and modes.
- (void) addRunLoop: (NSRunLoop *) runLoop;
- (void) removeRunLoop: (NSRunLoop *) runLoop;
- (void) addRequestMode: (NSRunLoopMode) mode;
- (void) removeRequestMode: (NSRunLoopMode) mode;

// Utilities.
- (void) run;
- (id) newConversation;

- (Class) _portCoderClassWithComponents: (NSArray *) components;
- (NSConcretePortCoder *) portCoderWithComponents: (NSArray *) components;

- (void) _sendUsingCoder: (NSConcretePortCoder *) coder;

@end

@protocol NSConnectionVersionedProtocol
- (id) rootObject;
- (id) keyedRootObject;
@end

typedef NS_ENUM(unsigned int, NSConnectionMessageMagic) {
    // A request: please invoke this invocation.
    NSConnectionMessageMagicRequest = 0xe1ffeed,
    // A reply to a specific request: here's what that invocation returned,
    // and here's the exception it has thrown.
    NSConnectionMessageMagicReply =   0xe2ffece,
    // Just wire release these proxies.
    NSConnectionMessageMagicRelease = 0xe2ffee1,
    // Expose a proxy to another connection.
    NSConnectionMessageMagicExpose =  0xe2ffee2,
};

// NSConnection._canUseKeyedCoder is a tri-state: either YES, NO, or MAYBE.
enum {
    MAYBE = 2
};

__attribute__ ((visibility ("hidden")))
extern BOOL NSDOLoggingEnabled;

#define NSDOLog(...) \
if (NSDOLoggingEnabled) { \
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, [NSString stringWithFormat: __VA_ARGS__]); \
} else
