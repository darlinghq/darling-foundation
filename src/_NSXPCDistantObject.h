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
#import <Foundation/NSXPCProxyCreating.h>

@class NSXPCConnection, NSXPCInterface;

typedef NS_OPTIONS(NSUInteger, NSXPCDistantObjectFlags) {
    NSXPCDistantObjectFlagExported = 1,
    NSXPCDistantObjectFlagNoImportance = 2,
    NSXPCDistantObjectFlagSync = 4
};

// Instances of _NSXPCDistantObject (or really, its subclasses) are proxies
// that represent remote (and local) objects.
// Note that this class inherits from NSObject, not NSProxy!
CF_PRIVATE
@interface _NSXPCDistantObject : NSObject <NSSecureCoding, NSXPCProxyCreating> {
    NSXPCConnection *_connection;
    void (^_errorHandler)(NSError *error);
    NSXPCDistantObjectFlags _flags;
    NSUInteger _proxyNumber;
    NSUInteger _generationCount;
    NSXPCInterface *_remoteInterface;
    double _timeout;
}

@property (readonly, retain) NSXPCConnection *_connection;
@property (readonly, copy) void (^_errorHandler)(NSError *error);
@property (readonly) BOOL _exported;
@property (readonly) BOOL _sync;
@property (readonly) BOOL _noImportance;
@property (readonly) NSUInteger _generationCount;
@property (readonly) NSUInteger _proxyNumber;
@property (retain) NSXPCInterface *_remoteInterface;
@property double _timeout;

- (instancetype) _initWithConnection: (NSXPCConnection *) connection
                         proxyNumber: (NSUInteger) proxyNumber
                     generationCount: (NSUInteger) generationCount
                           interface: (NSXPCInterface *) remoteInterface
                             options: (NSUInteger) flags
                               error: (void (^)(NSError *error)) errorHandler;


@end
