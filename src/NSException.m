//
//  NSException.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSException.h>
#import "NSObjectInternal.h"

#import <Foundation/NSString.h>
#import <Foundation/NSPortCoder.h>

#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <unistd.h>

#define __is_being_debugged__ 0

#if __OBJC2__
extern void objc_setUncaughtExceptionHandler(void (*handler)(id, void *));
#else
#    import <CoreFoundation/FoundationExceptions.h>
static void objc_setUncaughtExceptionHandler(void (*handler)(id, void *))
{
    _CFDoExceptionOperation(kCFDoExceptionOperationSetUncaughtHandler, handler);
}
#endif

static NSUncaughtExceptionHandler *handler = nil;
BOOL NSHangOnUncaughtException = NO;

static void printExceptionInformation(id exception)
{
    NSLog(@"Terminating app due to uncaught exception '%@', reason: '%@'", NSStringFromClass([exception class]), [exception reason]);
}

__attribute__((constructor))
static void initializeDefaultUncaughtExceptionHandler(void)
{
    NSSetUncaughtExceptionHandler(printExceptionInformation);
}

NSUncaughtExceptionHandler *NSGetUncaughtExceptionHandler(void)
{
    return handler;
}

static void _NSExceptionHandler(id exception, void *context)
{
    if (handler != NULL)
    {
        while (!__is_being_debugged__ && NSHangOnUncaughtException)
        {
            usleep(100);
        }
        handler(exception);
    }
}

void NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *h)
{
    handler = h;
    if (handler != NULL)
    {
        objc_setUncaughtExceptionHandler(&_NSExceptionHandler);
    }
    else
    {
        objc_setUncaughtExceptionHandler(NULL);
    }
}

NSString *_NSFullMethodName(id object, SEL selector)
{
    Class c = NSClassFromObject(object);
    const char *className = c ? class_getName(c) : "nil";

    return [NSString stringWithFormat:@"%c[%s %s]", (c == object ? '+' : '-'), className, sel_getName(selector)];
}

NSString *_NSMethodExceptionProem(id object, SEL selector)
{
    Class c = NSClassFromObject(object);
    const char *className = c ? class_getName(c) : "nil";

    return [NSString stringWithFormat:@"*** %c[%s %s]", (c == object ? '+' : '-'), className, sel_getName(selector)];
}

@implementation NSAssertionHandler

+ (NSAssertionHandler *)currentHandler
{
    static NSAssertionHandler *current = nil;
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        current = [[NSAssertionHandler alloc] init];
    });
    return current;
}

- (void)handleFailureInMethod:(SEL)selector object:(id)object file:(NSString *)fileName lineNumber:(NSInteger)line description:(NSString *)format,...
{
    Class cls = [object class];
    const char *className = class_getName(cls);
    BOOL instance = YES;
    if (class_isMetaClass(cls))
    {
        instance = NO;
    }
    RELEASE_LOG("*** Assertion failure in %c[%s %s], %s:%ld", instance ? '-' : '+', className, sel_getName(selector), [fileName UTF8String], (long)line);
    va_list args;
    va_start(args, format);
    [NSException raise:NSInternalInconsistencyException format:format arguments:args];
    va_end(args);
}

- (void)handleFailureInFunction:(NSString *)functionName file:(NSString *)fileName lineNumber:(NSInteger)line description:(NSString *)format,...
{
    RELEASE_LOG("*** Assertion failure in %s, %s:%ld", [functionName UTF8String], [fileName UTF8String], (long)line);
    va_list args;
    va_start(args, format);
    [NSException raise:NSInternalInconsistencyException format:format arguments:args];
    va_end(args);
}

@end

@implementation NSException (NSException)
OBJC_PROTOCOL_IMPL_PUSH

- (instancetype) initWithCoder: (NSCoder *) coder {
    if ([coder allowsKeyedCoding]) {
        _name = [[coder decodeObjectForKey: @"NS.name"] retain];
        _reason = [[coder decodeObjectForKey: @"NS.reason"] retain];
        _userInfo = [[coder decodeObjectForKey: @"NS.userinfo"] retain];
    } else {
        _name = [[coder decodeObject] retain];
        _reason = [[coder decodeObject] retain];
        _userInfo = [[coder decodeObject] retain];
    }

    return self;
}

- (void) encodeWithCoder: (NSCoder *) coder {
    if ([coder allowsKeyedCoding]) {
        [coder encodeObject: _name forKey: @"NS.name"];
        [coder encodeObject: _reason forKey: @"NS.reason"];
        [coder encodeObject: _userInfo forKey: @"NS.userinfo"];
    } else {
        [coder encodeObject: _name];
        [coder encodeObject: _reason];
        [coder encodeObject: _userInfo];
    }
}

OBJC_PROTOCOL_IMPL_POP
@end

@implementation NSException (NSExceptionPortCoding)

- (id) replacementObjectForPortCoder: (NSPortCoder *) portCoder {
    return self;
}

@end
