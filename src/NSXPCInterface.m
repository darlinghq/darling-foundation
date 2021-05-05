#import <Foundation/NSXPCInterface.h>
#import <Foundation/NSString.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSMutableArray.h>
#import <Foundation/NSException.h>
#import "_NSXPCDistantObject.h"

#import "NSXPCInterfaceInternal.h"

extern const char* _protocol_getMethodTypeEncoding(Protocol* proto, SEL sel, BOOL isRequiredMethod, BOOL isInstanceMethod);

@implementation _NSXPCInterfaceMethodInfo

@synthesize methodSignature = _methodSignature;
@synthesize replyBlockSignature = _replyBlockSignature;
@synthesize parameterClassesWhitelist = _parameterClassesWhitelist;
@synthesize replyParameterClassesWhitelist = _replyParameterClassesWhitelist;
@synthesize parameterInterfaces = _parameterInterfaces;
@synthesize replyParameterInterfaces = _replyParameterInterfaces;

- (instancetype)initWithProtocol: (Protocol*)protocol selector: (SEL)selector
{
    if (self = [super init]) {
        const char* extendedTypes = NULL;
        NSUInteger parameterCount = 0;

        // first, check required methods
        extendedTypes = _protocol_getMethodTypeEncoding(protocol, selector, YES, YES);

        if (!extendedTypes) {
            // next, check optional methods
            extendedTypes = _protocol_getMethodTypeEncoding(protocol, selector, NO, YES);
        }

        if (!extendedTypes) {
            // still no type information? there's nothing more we can do;
            // release ourselves and return
            [self release];
            return nil;
        }

        // okay, we've got our main method signature
        _methodSignature = [[NSMethodSignature signatureWithObjCTypes: extendedTypes] retain];

        // now let's see if we can find a reply block signature
        parameterCount = _methodSignature.numberOfArguments;

        for (NSUInteger i = 0; i < parameterCount; ++i) {
            const char* paramType = [_methodSignature getArgumentTypeAtIndex: i];
            size_t paramTypeLen = strlen(paramType);

            if (paramTypeLen > 1 && paramType[0] == '@' && paramType[1] == '?') {
                // found the block
                _replyBlockSignature = [[_methodSignature _signatureForBlockAtArgumentIndex: i] retain];
                break;
            }
        }

        // alright, let's setup some empty arrays

        _parameterClassesWhitelist = [NSMutableArray new];
        _parameterInterfaces = [NSMutableArray new];
        for (NSUInteger i = 2; i < parameterCount; ++i) {
            [_parameterClassesWhitelist addObject: [NSNull null]];
            [_parameterInterfaces addObject: [NSNull null]];
        }

        if (_replyBlockSignature) {
            _replyParameterClassesWhitelist = [NSMutableArray new];
            _replyParameterInterfaces = [NSMutableArray new];
            parameterCount = _replyBlockSignature.numberOfArguments;
            for (NSUInteger i = 1; i < parameterCount; ++i) {
                [_replyParameterClassesWhitelist addObject: [NSNull null]];
                [_replyParameterInterfaces addObject: [NSNull null]];
            }
        }
    }
    return self;
}

- (void)dealloc
{
    [_methodSignature release];
    [_replyBlockSignature release];
    [_parameterClassesWhitelist release];
    [_replyParameterClassesWhitelist release];
    [_parameterInterfaces release];
    [_replyParameterInterfaces release];
    [super dealloc];
}

@end

@implementation NSXPCInterface

@synthesize _distantObjectClass = _distantObjectClass;

+ (instancetype) interfaceWithProtocol: (Protocol *) protocol {
    NSXPCInterface *interface = [[NSXPCInterface alloc] init];
    [interface setProtocol: protocol];
    return [interface autorelease];
}

- (void)dealloc
{
    [_methods release];
    [super dealloc];
}

- (Protocol *) protocol {
    return _protocol;
}

- (void)_populateMethodInfo
{
    struct objc_method_description* methods = NULL;
    unsigned int count = 0;

    // first, do required methods
    methods = protocol_copyMethodDescriptionList(_protocol, YES, YES, &count);

    for (unsigned int i = 0; i < count; ++i) {
        @autoreleasepool {
            _methods[NSStringFromSelector(methods[i].name)] = [[[_NSXPCInterfaceMethodInfo alloc] initWithProtocol: _protocol selector: methods[i].name] autorelease];
            if (!_methods[NSStringFromSelector(methods[i].name)]) {
                [NSException raise: NSInternalInconsistencyException format: @"Failed to populate method information for %s (this should be impossible)", sel_getName(methods[i].name)];
            }
        }
    }

    free(methods);

    // next, do optional methods
    methods = protocol_copyMethodDescriptionList(_protocol, NO, YES, &count);

    for (unsigned int i = 0; i < count; ++i) {
        @autoreleasepool {
            _methods[NSStringFromSelector(methods[i].name)] = [[[_NSXPCInterfaceMethodInfo alloc] initWithProtocol: _protocol selector: methods[i].name] autorelease];
            if (!_methods[NSStringFromSelector(methods[i].name)]) {
                [NSException raise: NSInternalInconsistencyException format: @"Failed to populate method information for %s (this should be impossible)", sel_getName(methods[i].name)];
            }
        }
    }

    free(methods);
}

- (void) setProtocol: (Protocol *) protocol {
    if (_protocol == protocol) {
        return;
    }

    @synchronized(self) {
        _protocol = protocol;

        // Find or create a subclass of _NSXPCDistantObject.
        NSString *className =
            [NSString stringWithFormat: @"__NSXPCInterfaceProxy_%s",
                    protocol_getName(protocol)];

        // populate method information
        [_methods release];
        _methods = [NSMutableDictionary new];
        [self _populateMethodInfo];

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
}

- (NSMethodSignature *) _methodSignatureForRemoteSelector: (SEL) selector {
    _NSXPCInterfaceMethodInfo* info = nil;

    @synchronized(self) {
        info = _methods[NSStringFromSelector(selector)];
    }

    if (!info) {
        return nil;
    }

    return [[info.methodSignature retain] autorelease];
}

- (NSMethodSignature*)replyBlockSignatureForSelector: (SEL)selector
{
    _NSXPCInterfaceMethodInfo* info = nil;
    
    @synchronized(self) {
        info = _methods[NSStringFromSelector(selector)];
    }

    if (!info) {
        return nil;
    }

    return [[info.replyBlockSignature retain] autorelease];
}

- (NSSet<Class>*)classesForSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{
    _NSXPCInterfaceMethodInfo* info = nil;
    NSMutableArray<NSSet<Class>*>* target = nil;

    @synchronized(self) {
        info = _methods[NSStringFromSelector(selector)];
    }

    if (!info) {
        [NSException raise: NSInvalidArgumentException format: @"No method was found for selector %s", sel_getName(selector)];
    }

    target = isReply ? info.replyParameterClassesWhitelist : info.parameterClassesWhitelist;

    if (argumentIndex >= target.count) {
        [NSException raise: NSInvalidArgumentException format: @"Given argument index (%lu) is greater than or equal to number of parameters (%lu)", (long)argumentIndex, (long)target.count];
    }

    @synchronized(target) {
        return (target[argumentIndex] == [NSNull null]) ? nil : target[argumentIndex];
    }
}

- (NSXPCInterface *) interfaceForSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{
    _NSXPCInterfaceMethodInfo* info = nil;
    NSMutableArray<NSXPCInterface*>* target = nil;

    @synchronized(self) {
        info = _methods[NSStringFromSelector(selector)];
    }

    if (!info) {
        [NSException raise: NSInvalidArgumentException format: @"No method was found for selector %s", sel_getName(selector)];
    }

    target = isReply ? info.replyParameterInterfaces : info.parameterInterfaces;

    if (argumentIndex >= target.count) {
        [NSException raise: NSInvalidArgumentException format: @"Given argument index (%lu) is greater than or equal to number of parameters (%lu)", (long)argumentIndex, (long)target.count];
    }

    @synchronized(target) {
        return (target[argumentIndex] == [NSNull null]) ? nil : target[argumentIndex];
    }
}

- (xpc_type_t) XPCTypeForSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{
    // TODO
    return NULL;
}

- (void) setClass: (Class)klass forSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{
    return [self setClasses: [NSSet setWithObject: klass] forSelector: selector argumentIndex: argumentIndex ofReply: isReply];
}

- (void) setClasses: (NSSet<Class> *)classes forSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{
    _NSXPCInterfaceMethodInfo* info = nil;
    NSMutableArray<NSSet<Class>*>* target = nil;

    @synchronized(self) {
        info = _methods[NSStringFromSelector(selector)];
    }

    if (!info) {
        [NSException raise: NSInvalidArgumentException format: @"No method was found for selector %s", sel_getName(selector)];
    }

    target = isReply ? info.replyParameterClassesWhitelist : info.parameterClassesWhitelist;

    if (argumentIndex >= target.count) {
        [NSException raise: NSInvalidArgumentException format: @"Given argument index (%lu) is greater than or equal to number of parameters (%lu)", (long)argumentIndex, (long)target.count];
    }

    @synchronized(target) {
        target[argumentIndex] = classes;
    }
}

- (void) setInterface: (NSXPCInterface *)interface forSelector: (SEL) selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{

    _NSXPCInterfaceMethodInfo* info = nil;
    NSMutableArray<NSXPCInterface*>* target = nil;

    @synchronized(self) {
        info = _methods[NSStringFromSelector(selector)];
    }

    if (!info) {
        [NSException raise: NSInvalidArgumentException format: @"No method was found for selector %s", sel_getName(selector)];
    }

    target = isReply ? info.replyParameterInterfaces : info.parameterInterfaces;

    if (argumentIndex >= target.count) {
        [NSException raise: NSInvalidArgumentException format: @"Given argument index (%lu) is greater than or equal to number of parameters (%lu)", (long)argumentIndex, (long)target.count];
    }

    @synchronized(target) {
        target[argumentIndex] = interface;
    }
}

- (void) setXPCType: (xpc_type_t)type forSelector: (SEL)selector argumentIndex: (NSUInteger)argumentIndex ofReply: (BOOL)isReply
{
    // TODO
}

- (NSXPCInterface*)_interfaceForArgument: (NSUInteger)argumentIndex ofSelector: (SEL)selector reply: (BOOL)isReply
{
    _NSXPCInterfaceMethodInfo* info = nil;
    NSMutableArray<NSXPCInterface*>* target = nil;

    @synchronized(self) {
        info = _methods[NSStringFromSelector(selector)];
    }

    if (!info) {
        return nil;
    }

    target = isReply ? info.replyParameterInterfaces : info.parameterInterfaces;

    if (argumentIndex >= target.count) {
        return nil;
    }

    @synchronized(target) {
        return (target[argumentIndex] == [NSNull null]) ? nil : target[argumentIndex];
    }
}

- (BOOL)_hasProxiesInReplyBlockArgumentsOfSelector: (SEL)selector
{
    _NSXPCInterfaceMethodInfo* info = nil;
    NSMutableArray<NSXPCInterface*>* target = nil;

    @synchronized(self) {
        info = _methods[NSStringFromSelector(selector)];
    }

    if (!info) {
        return NO;
    }

    target = info.replyParameterInterfaces;

    @synchronized(target) {
        for (NSUInteger i = 0; i < target.count; ++i) {
            // if any one of them is set, then we do have proxies
            if (target[i] != [NSNull null]) {
                return YES;
            }
        }
    }

    return NO;
}

@end

