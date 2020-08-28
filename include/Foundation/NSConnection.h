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
#import <Foundation/NSNotification.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSRunLoop.h>

@class NSArray<ObjectType>, NSMutableArray<ObjectType>, NSMutableDictionary<KeyType, ObjectType>;
@class NSData, NSNumber, NSString;
@class NSPort, NSConcretePortCoder, NSPortMessage, NSPortNameServer;
@class NSInvocation, NSException, NSRunLoop;
@class NSConnection, NSDistantObject, NSDistantObjectRequest;

@protocol NSConnectionDelegate<NSObject>
@optional
- (NSData *) authenticationDataForComponents: (NSArray *) components;

- (BOOL) authenticateComponents: (NSArray *) components
                       withData: (NSData *) authenticationData;

- (BOOL)       connection: (NSConnection *) parent
  shouldMakeNewConnection: (NSConnection *) newConnection;

- (BOOL) makeNewConnection: (NSConnection *) newConnection
                    sender: (NSConnection *) parent;

- (BOOL) connection: (NSConnection *) connection
      handleRequest: (NSDistantObjectRequest *) request;

- (id) createConversationForConnection: (NSConnection *) connection;

@end

FOUNDATION_EXPORT const NSRunLoopMode NSConnectionReplyMode;
FOUNDATION_EXPORT const NSNotificationName NSConnectionDidInitializeNotification;
FOUNDATION_EXPORT const NSNotificationName NSConnectionDidDieNotification;

// We store info about each released proxy (or rather, each proxy release) as an
// array with two ints: the id and the release count. This is also the format
// used for transferring the released proxy data.
typedef NSArray<NSNumber *> *NSConnectionReleasedProxyRecord;

@interface NSConnection : NSObject {
    bool _isValid;
    unsigned char _canUseKeyedCoder;

    id _rootObject;
    id<NSConnectionDelegate> _delegate;
    NSPort *_sendPort;
    NSPort *_recvPort;

    NSTimeInterval _requestTimeout;
    NSTimeInterval _replyTimeout;
    NSMutableArray<NSRunLoopMode> *_requestModes;
    NSMutableArray<NSRunLoop *> *_runLoops;

    NSMutableDictionary<NSString *, NSNumber *> *_classVersions;
    NSMutableArray<NSConnectionReleasedProxyRecord> *_releasedProxies;
    // Which run loop (effectively, which thread) is waiting for a reply with the
    // given sequence number.
    NSMutableDictionary<NSNumber *, NSRunLoop *> *_sequenceNumberToRunLoop;
    // Used to pass the port coder (and the message data it decodes) from whoever
    // happens to receive the message to the interested thread.
    NSMutableDictionary<NSNumber *, NSConcretePortCoder *> *_sequenceNumberToCoder;
}

@property (readonly, getter=isValid) BOOL valid;
@property (retain) id rootObject;
@property (readonly, retain) NSDistantObject *rootProxy;
@property (assign) id<NSConnectionDelegate> delegate;
@property (readonly, retain) NSPort *sendPort;
@property (readonly, retain) NSPort *receivePort;
@property NSTimeInterval requestTimeout;
@property NSTimeInterval replyTimeout;
@property (readonly, copy) NSArray<NSRunLoopMode> *requestModes;

// Creation.
- (instancetype) init;

- (nullable instancetype) initWithReceivePort: (NSPort *) recvPort
                                     sendPort: (NSPort *) sendPort NS_DESIGNATED_INITIALIZER;


+ (nullable instancetype) connectionWithReceivePort: (NSPort *) recvPort
                                           sendPort: (NSPort *) sendPort;

+ (NSConnection *) defaultConnection;
+ (NSArray<NSConnection *> *) allConnections;

// Names.
+ (nullable instancetype) serviceConnectionWithName: (NSString *) name
                                         rootObject: (id) rootObject
                                    usingNameServer: (NSPortNameServer *) portNameServer;

+ (nullable instancetype) serviceConnectionWithName: (NSString *) name
                                         rootObject: (id) rootObject;

- (BOOL) registerName: (NSString *) name;
- (BOOL) registerName: (NSString *) name
       withNameServer: (NSPortNameServer *) portNameServer;

+ (nullable instancetype) connectionWithRegisteredName: (NSString *) name
                                                  host: (NSString *) hostName;

+ (nullable instancetype) connectionWithRegisteredName: (NSString *) name
                                                  host: (NSString *) hostName
                                       usingNameServer: (NSPortNameServer *) portNameServer;

+ (NSDistantObject *) rootProxyForConnectionWithRegisteredName: (NSString *) name
                                                          host: (NSString *) hostName;

+ (NSDistantObject *) rootProxyForConnectionWithRegisteredName: (NSString *) name
                                                          host: (NSString *) hostName
                                               usingNameServer: (NSPortNameServer *) portNameServer;

- (void) invalidate;
- (void) runInNewThread;

@end
