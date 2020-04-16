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

#import <Foundation/NSPortNameServer.h>
#import <Foundation/NSMachBootstrapServer.h>
#import "NSObjectInternal.h"

@implementation NSPortNameServer

+ (NSPortNameServer *) defaultPortNameServer {
    return [self systemDefaultPortNameServer];
}

+ (NSPortNameServer *) systemDefaultPortNameServer {
    return [NSMachBootstrapServer sharedInstance];
}

- (NSPort *) portForName: (NSString *) name {
    NSRequestConcreteImplementation();
}

- (NSPort *) portForName: (NSString *) name
                    host: (NSString *) host
{
    NSRequestConcreteImplementation();
}

- (BOOL) registerPort: (NSPort *) port
                 name: (NSString *) name
{
    NSRequestConcreteImplementation();
}

- (BOOL) registerPort: (NSPort *) port
              forName: (NSString *) name
{
    return [self registerPort: port name: name];
}

- (BOOL) removePortForName: (NSString *) name {
    NSRequestConcreteImplementation();
}

@end
