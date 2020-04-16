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

#import <Foundation/NSMachBootstrapServer.h>
#import <Foundation/NSString.h>
#import <Foundation/NSPort.h>
#import <bootstrap_priv.h>
#import <mach/mach.h>
#import <dispatch/dispatch.h>

@implementation NSMachBootstrapServer

+ (instancetype) sharedInstance {
    static NSMachBootstrapServer *server = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        server = [NSMachBootstrapServer new];
    });
    return server;
}

- (NSPort *) portForName: (NSString *) name options: (NSMachBootstrapServerLookupOptions) options {
    uint64_t flags = 0;
    switch (options) {
    case NSMachBootstrapServerLookupDefault:
        flags = 0;
        break;
    case NSMachBootstrapServerLookupPrivileged:
        flags = BOOTSTRAP_PRIVILEGED_SERVER;
        break;
    }

    mach_port_t port;
    kern_return_t kr = bootstrap_look_up2(bootstrap_port, [name UTF8String], &port, 0, flags);
    if (kr != KERN_SUCCESS) {
        return nil;
    }
    return [NSMachPort portWithMachPort: port options: NSMachPortDeallocateSendRight];
}

- (NSPort *) portForName: (NSString *) name {
    return [self portForName: name options: NSMachBootstrapServerLookupDefault];
}

- (NSPort *) portForName: (NSString *) name
                    host: (NSString *) host
{
    if ([host length] != 0) {
        // We cannot look up remote ports.
        return nil;
    }
    return [self portForName: name];
}

- (BOOL) registerPort: (NSPort *) port
                 name: (NSString *) name
{
    if (![port isKindOfClass: [NSMachPort class]]) {
        return NO;
    }
    kern_return_t kr = bootstrap_register(
        bootstrap_port,
        (char *) [name UTF8String],
        [(NSMachPort *) port machPort]
    );
    return kr == KERN_SUCCESS;
}

- (BOOL) removePortForName: (NSString *) name {
#if 0
    kern_return_t kr = bootstrap_register(bootstrap_port, MACH_PORT_NULL);
    return kr == KERN_SUCCESS;
#else
    // Apple's implementation appears to always return NO?
    return NO;
#endif
}

- (NSPort *) servicePortWithName: (NSString *) name {
    // First, try using bootstrap_check_in().
    mach_port_t port;
    kern_return_t kr = bootstrap_check_in(bootstrap_port, [name UTF8String], &port);
    if (kr == KERN_SUCCESS) {
        // Give ourselves a send right in addition to the receive right.
        mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
        return [NSMachPort portWithMachPort: port];
    } else {
        // Otherwise, fall back to bootstrap_look_up().
        return [self portForName: name];
    }
}

@end
