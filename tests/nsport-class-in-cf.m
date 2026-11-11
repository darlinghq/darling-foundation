// Copyright (C) 2026 Lubos Dolezel
// Guest test: NSPort and NSMachPort are defined by CoreFoundation (as on
// macOS), while their methods and NSMessagePort/NSSocketPort come from
// Foundation. Prints "N/N passed".
#import <Foundation/NSObject.h>
#import <Foundation/NSPort.h>
#import <Foundation/NSAutoreleasePool.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

static int pass, total;

static void check(const char *label, int ok) {
    total++;
    pass += ok;
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
}

static int classInImage(Class c, const char *needle) {
    Dl_info info;
    if (!dladdr((__bridge void *)c, &info) || !info.dli_fname) return 0;
    return strstr(info.dli_fname, needle) != NULL;
}

@interface Delegate : NSObject <NSMachPortDelegate>
@end
@implementation Delegate
@end

int main(void) {
    @autoreleasepool {
        void *cf = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_NOW);
        check("CoreFoundation exports _OBJC_CLASS_$_NSPort",
              cf && dlsym(cf, "OBJC_CLASS_$_NSPort") != NULL);
        check("CoreFoundation exports _OBJC_CLASS_$_NSMachPort",
              cf && dlsym(cf, "OBJC_CLASS_$_NSMachPort") != NULL);
        check("NSPort class object is in CoreFoundation", classInImage([NSPort class], "CoreFoundation"));
        check("NSMachPort class object is in CoreFoundation", classInImage([NSMachPort class], "CoreFoundation"));
        check("NSMessagePort stays in Foundation", classInImage([NSMessagePort class], "Foundation.framework/"));

        // The Foundation category must still supply the behaviour.
        NSPort *p = [NSPort port];
        check("+[NSPort port] returns an NSMachPort", [p isKindOfClass:[NSMachPort class]]);
        check("the port is valid", [p isValid]);
        check("machPort is non-zero", [(NSMachPort *)p machPort] != 0);

        Delegate *d = [Delegate new];
        [p setDelegate:d];
        check("delegate round-trips", [p delegate] == d);

        [p invalidate];
        check("invalidate makes the port invalid", ![p isValid]);

        check("NSPort responds to -scheduleInRunLoop:forMode:",
              [NSPort instancesRespondToSelector:@selector(scheduleInRunLoop:forMode:)]);
    }
    printf("%d/%d passed\n", pass, total);
    return pass == total ? 0 : 1;
}
