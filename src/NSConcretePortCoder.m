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

#import "NSConcretePortCoder.h"
#import <Foundation/NSSet.h>
#import "NSObjectInternal.h"
#import <objc/runtime.h>

@implementation NSConcretePortCoder

- (void) dealloc {
    [_whitelist release];
    [super dealloc];
}

- (void) _setWhitelist: (NSSet *) whitelist {
    [whitelist retain];
    [_whitelist release];
    _whitelist = whitelist;
}

- (BOOL) _classAllowed: (Class) class {
    // By default, everything is allowed.
    if (_whitelist == nil) {
        return YES;
    }

    // Allow a class if it's a descendant
    // of an explicitly allowed class.
    while (class != Nil) {
        if ([_whitelist member: class]) {
            return YES;
        }
        class = class_getSuperclass(class);
    }

    return NO;
}

- (NSConnection *) connection {
    NSRequestConcreteImplementation();
}

- (NSArray *) finishedComponents {
    NSRequestConcreteImplementation();
}

- (void) invalidate {
    NSRequestConcreteImplementation();
}

- (void) encodeInvocation: (NSInvocation *) invocation {
    NSRequestConcreteImplementation();
}

- (NSInvocation *) decodeInvocation {
    NSRequestConcreteImplementation();
}

- (void) encodeReturnValue: (NSInvocation *) invocation {
    NSRequestConcreteImplementation();
}

- (void) decodeReturnValue: (NSInvocation *) invocation {
    NSRequestConcreteImplementation();
}

- (void) encodeReturnValueOfInvocation: (NSInvocation *) invocation
                                forKey: (NSString *) key
{
    NSRequestConcreteImplementation();
}

- (void) decodeReturnValueOfInvocation: (NSInvocation *) invocation
                                forKey: (NSString *) key
{
    NSRequestConcreteImplementation();
}

@end
