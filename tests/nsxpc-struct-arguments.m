// Copyright (C) 2026 Lubos Dolezel
#import <Foundation/Foundation.h>
#include <stdio.h>
typedef struct { double x, y; } Pt;
typedef struct { float a, b, c; } F3;
typedef struct { long a, b, c, d, e; } Big;
@protocol Svc
- (void)scale:(Pt)p by:(double)k reply:(void (^)(Pt))reply;
- (void)half:(double)d reply:(void (^)(double))reply;
- (void)mix:(int)i f3:(F3)f d:(double)d big:(Big)b reply:(void (^)(F3, Big, double))reply;
@end
@interface Impl : NSObject <Svc, NSXPCListenerDelegate> @end
@implementation Impl
- (void)half:(double)d reply:(void (^)(double))reply { reply(d / 2); }
- (BOOL)listener:(NSXPCListener *)l shouldAcceptNewConnection:(NSXPCConnection *)c {
    c.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Svc)];
    c.exportedObject = self; [c resume]; return YES; }
- (void)scale:(Pt)p by:(double)k reply:(void (^)(Pt))reply { Pt r = { p.x * k, p.y * k }; reply(r); }
- (void)mix:(int)i f3:(F3)f d:(double)d big:(Big)b reply:(void (^)(F3, Big, double))reply {
    F3 g = { f.a + i, f.b + i, f.c + i }; Big c = { b.a + 1, b.b + 2, b.c + 3, b.d + 4, b.e + 5 }; reply(g, c, d * 2); }
@end
int main(void) {
    @autoreleasepool {
        // Arguments and replies are copied through -getArgument:atIndex: and -setArgument:atIndex:.
        int pass = 0, total = 0;
        Impl *impl = [Impl new];
        NSXPCListener *l = [NSXPCListener anonymousListener];
        l.delegate = impl; [l resume];
        NSXPCConnection *c = [[NSXPCConnection alloc] initWithListenerEndpoint:l.endpoint];
        c.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(Svc)];
        [c resume];
        __block Pt rp = {0, 0}; __block BOOL got = NO;
        dispatch_semaphore_t s = dispatch_semaphore_create(0);
        id<Svc> proxy = [c remoteObjectProxyWithErrorHandler:^(NSError *e) { printf("error %s\n", e.description.UTF8String); dispatch_semaphore_signal(s); }];
        __block double hd = 0; got = NO;
        [proxy half:5.0 reply:^(double r) { hd = r; got = YES; dispatch_semaphore_signal(s); }];
        dispatch_semaphore_wait(s, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC));
        total++; int ok0 = got && hd == 2.5; pass += ok0; printf("%s xpc double argument and reply\n", ok0 ? "PASS" : "FAIL");
        Pt p = { 1.5, -2.0 };
        [proxy scale:p by:3 reply:^(Pt r) { rp = r; got = YES; dispatch_semaphore_signal(s); }];
        dispatch_semaphore_wait(s, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC));
        total++; int ok = got && rp.x == 4.5 && rp.y == -6.0; pass += ok; printf("%s xpc struct argument and reply {dd}\n", ok ? "PASS" : "FAIL");
        __block F3 rf = {0}; __block Big rb = {0}; __block double rd = 0; got = NO;
        F3 f = { 1, 2, 3 }; Big b = { 10, 20, 30, 40, 50 };
        [proxy mix:5 f3:f d:1.25 big:b reply:^(F3 g, Big c2, double d) { rf = g; rb = c2; rd = d; got = YES; dispatch_semaphore_signal(s); }];
        dispatch_semaphore_wait(s, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC));
        total++; ok = got && rf.a == 6 && rf.b == 7 && rf.c == 8 && rb.a == 11 && rb.e == 55 && rd == 2.5; pass += ok;
        printf("%s xpc mixed struct arguments and reply {fff}{lllll}\n", ok ? "PASS" : "FAIL");
        printf("%d/%d passed\n", pass, total);
        return pass == total ? 0 : 1;
    }
}
