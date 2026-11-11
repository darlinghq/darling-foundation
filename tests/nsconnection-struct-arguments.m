// Copyright (C) 2026 Lubos Dolezel
#import <Foundation/Foundation.h>
#include <stdio.h>
typedef struct { double x, y; } Pt;
typedef struct { long a, b, c, d, e; } Big;
@protocol Svc
- (Pt)scale:(Pt)p by:(double)k;
- (Big)bump:(Big)b with:(int)i;
- (double)sumF:(float)f d:(double)d;
@end
@interface Impl : NSObject <Svc> @end
@implementation Impl
- (Pt)scale:(Pt)p by:(double)k { Pt r = { p.x * k, p.y * k }; return r; }
- (Big)bump:(Big)b with:(int)i { Big r = { b.a + i, b.b + i, b.c + i, b.d + i, b.e + i }; return r; }
- (double)sumF:(float)f d:(double)d { return f + d; }
@end
static NSPort *port1, *port2;
static dispatch_semaphore_t ready;
@interface Server : NSObject @end
@implementation Server
+ (void)run:(id)unused {
    @autoreleasepool {
        NSConnection *c = [NSConnection connectionWithReceivePort: port1 sendPort: port2];
        [c setRootObject: [Impl new]];
        dispatch_semaphore_signal(ready);
        [[NSRunLoop currentRunLoop] run];
    }
}
@end
int main(void) {
    @autoreleasepool {
        int pass = 0, total = 0, ok;
        port1 = [NSMachPort port]; port2 = [NSMachPort port];
        ready = dispatch_semaphore_create(0);
        [NSThread detachNewThreadSelector: @selector(run:) toTarget: [Server class] withObject: nil];
        dispatch_semaphore_wait(ready, DISPATCH_TIME_FOREVER);
        NSConnection *cc = [NSConnection connectionWithReceivePort: port2 sendPort: port1];
        cc.requestTimeout = 20; cc.replyTimeout = 20;
        id<Svc> proxy = (id<Svc>) [cc rootProxy];
        Pt p = { 1.5, -2.0 }; Pt r = [proxy scale: p by: 3];
        total++; ok = r.x == 4.5 && r.y == -6.0; pass += ok; printf("%s distributed objects struct argument and result {dd}\n", ok ? "PASS" : "FAIL");
        Big b = { 1, 2, 3, 4, 5 }; Big rb = [proxy bump: b with: 10];
        total++; ok = rb.a == 11 && rb.e == 15; pass += ok; printf("%s distributed objects 40-byte struct argument and result\n", ok ? "PASS" : "FAIL");
        total++; ok = [proxy sumF: 1.5f d: 2.25] == 3.75; pass += ok; printf("%s distributed objects float and double arguments\n", ok ? "PASS" : "FAIL");
        printf("%d/%d passed\n", pass, total);
        return pass == total ? 0 : 1;
    }
}
