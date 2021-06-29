//
//  NSPlatform.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <CoreFoundation/CFBundle.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <objc/runtime.h>
//#import "wrap.h"

extern void __CFInitialize();
extern char ***_NSGetArgv(void);

static void _enumerationMutationHandler(id object)
{
    [NSException raise:NSGenericException format:@"Illegal mutation while fast enumerating %@", object];
}

static void _NSToDoAtProcessStart() {
    // setup bridging
    class_setSuperclass(objc_getClass("__NSCFString"), objc_getClass("NSMutableString"));
    class_setSuperclass(objc_getClass("__NSCFError"), objc_getClass("NSError"));
    class_setSuperclass(objc_getClass("__NSCFCharacterSet"), objc_getClass("NSMutableCharacterSet"));
    class_setSuperclass(objc_getClass("__NSCFAttributedString"), objc_getClass("NSMutableAttributedString"));
    class_setSuperclass(objc_getClass("__NSCFBoolean"), objc_getClass("NSNumber"));
    class_setSuperclass(objc_getClass("__NSCFNumber"), objc_getClass("NSNumber"));
};

static void NSPlatformInitialize() __attribute__((constructor));
static void NSPlatformInitialize()
{
    static BOOL inited = NO;

    // not sure why not just use dispatch_once, but this is how Apple does it, so must be okay
    if (inited) {
        return;
    }

    inited = YES;

    __CFInitialize();

    _NSToDoAtProcessStart();

    @autoreleasepool {
#if 0
        NSString* appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleExecutableKey];
        __printf_tag = strdup([appName UTF8String]);
        char ***argv = _NSGetArgv();
        snprintf((*argv)[0], PATH_MAX, "%s/%s", __virtual_prefix(virtual_bundle), __printf_tag);
#endif
        objc_setEnumerationMutationHandler(_enumerationMutationHandler);
    }

    // TODO: we also need to setup a bridge for NSData to dispatch_data
}
