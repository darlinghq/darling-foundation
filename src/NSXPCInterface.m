#import <Foundation/NSXPCInterface.h>
#import <Foundation/NSString.h>
#import <Foundation/NSMethodSignature.h>
#import "_NSXPCDistantObject.h"

extern const char* _protocol_getMethodTypeEncoding(Protocol* proto, SEL sel, BOOL isRequiredMethod, BOOL isInstanceMethod);

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

- (NSMethodSignature*)replyBlockSignatureForSelector: (SEL)selector
{
    NSMethodSignature* methodSignature = nil;
    const char* extendedTypes = _protocol_getMethodTypeEncoding(_protocol, selector, YES, YES);
    size_t parameterCount = 0;

    if (!extendedTypes) {
        // check optional methods
        extendedTypes = _protocol_getMethodTypeEncoding(_protocol, selector, NO, YES);
    }

    if (!extendedTypes) {
        // still no type information? no such method
        return nil;
    }

    methodSignature = [NSMethodSignature signatureWithObjCTypes: extendedTypes];

    if (!methodSignature) {
        return nil;
    }

    parameterCount = methodSignature.numberOfArguments;

    // next, find which argument is the reply block
    for (NSUInteger i = 0; i < parameterCount; ++i) {
        const char* paramType = [methodSignature getArgumentTypeAtIndex: i];
        size_t paramTypeLen = strlen(paramType);

        if (paramTypeLen > 1 && paramType[0] == '@' && paramType[1] == '?') {
            // found the block
            return [methodSignature _signatureForBlockAtArgumentIndex: i];
        }
    }

    return nil;
}

- (NSXPCInterface *) interfaceForSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{
    return nil;
}

- (xpc_type_t) XPCTypeForSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{
    return NULL;
}

- (void) setClass: (Class)klass forSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{
    return [self setClasses: [NSSet setWithObject: klass] forSelector: selector argumentIndex: argumentIndex ofReply: isReply];
}

- (void) setClasses: (NSSet<Class> *)classes forSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{

}

- (void) setInterface: (NSXPCInterface *)interface forSelector: (SEL) selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{

}

- (void) setXPCType: (xpc_type_t)type forSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{

}

@end

