#import <Foundation/NSScriptCoercionHandler.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSString.h>
#include <dispatch/dispatch.h>
#include <objc/message.h>

@implementation NSScriptCoercionHandler {
    // class pointer -> (class pointer -> NSValue holding {coercer, selector})
    NSMutableDictionary *_coercers;
}

struct NSScriptCoercer {
    id coercer;
    SEL selector;
};

+ (NSScriptCoercionHandler *)sharedCoercionHandler
{
    static NSScriptCoercionHandler *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[NSScriptCoercionHandler alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _coercers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_coercers release];
    [super dealloc];
}

- (void)registerCoercer:(id)coercer selector:(SEL)selector toConvertFromClass:(Class)fromClass toClass:(Class)toClass
{
    struct NSScriptCoercer entry = { coercer, selector };
    NSValue *value = [NSValue valueWithBytes:&entry objCType:@encode(struct NSScriptCoercer)];
    NSValue *fromKey = [NSValue valueWithPointer:fromClass];
    @synchronized (self) {
        NSMutableDictionary *targets = [_coercers objectForKey:fromKey];
        if (targets == nil) {
            targets = [NSMutableDictionary dictionary];
            [_coercers setObject:targets forKey:fromKey];
        }
        [targets setObject:value forKey:[NSValue valueWithPointer:toClass]];
    }
}

- (id)coerceValue:(id)value toClass:(Class)toClass
{
    if (value == nil || toClass == Nil || [value isKindOfClass:toClass]) {
        return value;
    }

    NSValue *found = nil;
    NSValue *toKey = [NSValue valueWithPointer:toClass];
    @synchronized (self) {
        for (Class cls = [value class]; cls != Nil && found == nil; cls = [cls superclass]) {
            found = [[_coercers objectForKey:[NSValue valueWithPointer:cls]] objectForKey:toKey];
        }
    }
    if (found != nil) {
        struct NSScriptCoercer entry;
        [found getValue:&entry];
        return ((id (*)(id, SEL, id, Class))objc_msgSend)(entry.coercer, entry.selector, value, toClass);
    }

    // Built-in string and number conversions.
    if ([toClass isSubclassOfClass:[NSString class]] && [value respondsToSelector:@selector(stringValue)]) {
        return [value stringValue];
    }
    if ([toClass isSubclassOfClass:[NSNumber class]] && [value isKindOfClass:[NSString class]]) {
        return [NSNumber numberWithDouble:[(NSString *)value doubleValue]];
    }
    return nil;
}

@end
