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

#import <Foundation/NSProtocolChecker.h>
#import "NSConcreteProtocolChecker.h"
#import <Foundation/NSPortCoder.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSDistantObject.h>
#import "NSObjectInternal.h"


@implementation NSProtocolChecker

+ (instancetype) allocWithZone: (NSZone *) zone {
    if (self == [NSProtocolChecker class]) {
        return [NSConcreteProtocolChecker allocWithZone: zone];
    } else {
        return [super allocWithZone: zone];
    }
}

+ (instancetype) protocolCheckerWithTarget: (NSObject *) target
                                  protocol: (Protocol *) protocol
{
    return [[[self alloc] initWithTarget: target protocol: protocol] autorelease];
}

- (instancetype) initWithTarget: (NSObject *) target
                       protocol: (Protocol *) protocol
{
    NSRequestConcreteImplementation();
}

- (NSObject *) target {
    NSRequestConcreteImplementation();
}

- (Protocol *) protocol {
    NSRequestConcreteImplementation();
}

- (BOOL) conformsToProtocol: (Protocol *) otherProtocol {
    return protocol_conformsToProtocol([self protocol], otherProtocol);
}

static struct objc_method_description methodDescription(NSProtocolChecker *self, SEL selector) {
    struct objc_method_description desc;
    Protocol *protocol = [self protocol];

    // Check required methods.
    desc = protocol_getMethodDescription(protocol, selector, YES, YES);
    if (desc.types != NULL) {
        return desc;
    }
    // Check optional methods.
    // We only ask the target if the method is found in the protocol and
    // it's an optional method, so we need to know whether the target
    // actually implements it or not.
    desc = protocol_getMethodDescription(protocol, selector, NO, YES);
    if (desc.types != NULL && [[self target] respondsToSelector: selector]) {
        return desc;
    }

    return (struct objc_method_description) { NULL, NULL };
}

- (BOOL) respondsToSelector: (SEL) selector {
    return methodDescription(self, selector).name != NULL;
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL) selector {
    const char *types = methodDescription(self, selector).types;
    return types ? [NSMethodSignature signatureWithObjCTypes: types] : nil;
}

- (id) forwardingTargetForSelector: (SEL) selector {
    BOOL responds = methodDescription(self, selector).name != NULL;
    return responds ? [self target] : nil;
}

- (void) doesNotRecognizeSelector: (SEL) selector {
    [NSException raise: NSInvalidArgumentException
                format: @"NSProtocolChecker: target protocol does not recognize selector: %s",
                 sel_getName(selector)];
}

// Note: there's a default implementation of this method that does essentially
// the same for NSObject, but not for an NSProxy (because for a proxy, we most
// likely want its target to return a replacement, not the proxy itself). But
// for a NSProtocolChecker, we actually want NSDistantObject that proxies the
// NSProtocolChecker that proxies the real target.
- (id) replacementObjectForPortCoder: (NSPortCoder *) coder {
    return [NSDistantObject proxyWithLocal: self
                                connection: [coder connection]];
}

@end
