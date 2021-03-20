#import <Foundation/NSXPCInterface.h>
#import <Foundation/NSString.h>
#import <Foundation/NSMethodSignature.h>
#import "_NSXPCDistantObject.h"

@interface _NSXPCInterfaceMethodInfo : NSObject {
}
@end

@implementation NSXPCInterface

@synthesize _distantObjectClass = _distantObjectClass;

+ (instancetype) interfaceWithProtocol: (Protocol *) protocol {
    NSXPCInterface *interface = [[NSXPCInterface alloc] init];
    [interface setProtocol: protocol];
    return [interface autorelease];
}

- (Protocol *) protocol {
    return _protocol;
}

- (void) setProtocol: (Protocol *) protocol {
    if (_protocol == protocol) {
        return;
    }
    _protocol = protocol;

    // Find or create a subclass of _NSXPCDistantObject.
    NSString *className =
        [NSString stringWithFormat: @"__NSXPCInterfaceProxy_%s",
                  protocol_getName(protocol)];

    _distantObjectClass = NSClassFromString(className);
    if (_distantObjectClass == nil) {
        _distantObjectClass = objc_allocateClassPair(
            [_NSXPCDistantObject class],
            [className UTF8String],
            0
        );
        objc_registerClassPair(_distantObjectClass);
    }
}

- (NSMethodSignature *) _methodSignatureForRemoteSelector: (SEL) selector {
    struct objc_method_description desc;

    // Check required methods.
    desc = protocol_getMethodDescription(_protocol, selector, YES, YES);

    if (desc.types == NULL) {
        // Check optional methods.
        desc = protocol_getMethodDescription(_protocol, selector, NO, YES);
    }

    // If we still have not found a method, give up.
    if (desc.types == NULL) {
        return nil;
    }

    return [NSMethodSignature signatureWithObjCTypes: desc.types];
}

@end

