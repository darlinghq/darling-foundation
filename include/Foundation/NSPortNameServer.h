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

@class NSPort, NSString;

@interface NSPortNameServer : NSObject

+ (NSPortNameServer *) defaultPortNameServer;
+ (NSPortNameServer *) systemDefaultPortNameServer;

- (NSPort *) portForName: (NSString *) name;
- (NSPort *) portForName: (NSString *) name
                    host: (NSString *) host;

- (BOOL) registerPort: (NSPort *) port
                 name: (NSString *) name;
- (BOOL) registerPort: (NSPort *) port
              forName: (NSString *) name;

- (BOOL) removePortForName: (NSString *) name;

@end

// For compatibility, also import concrete name server types.
#import <Foundation/NSMachBootstrapServer.h>

@interface NSSocketPortNameServer : NSPortNameServer
@end

// #import <Foundation/NSMessagePortNameServer.h>
@interface NSMessagePortNameServer : NSPortNameServer
@end
