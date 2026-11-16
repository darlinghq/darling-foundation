// Copyright (C) 2026 Lubos Dolezel
// Client half of nsxpc-cross-arch.sh; built for the architecture opposite to the service's (i386 for an x86_64
// service). An NSXPCInterface describes methods by the protocol, so the receiver decodes the arguments of every
// message with its own signatures, not with the type strings of the sender's architecture.
#import "nsxpc-cross-arch.h"
#include <stdio.h>

static int pass, total;
static void report(const char *what, BOOL ok) {
    total++; pass += ok;
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
}

int main(void) {
    @autoreleasepool {
        NSXPCConnection *c = [[NSXPCConnection alloc] initWithMachServiceName:XARCH_SERVICE_NAME options:0];
        c.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XArchService)];
        [c resume];
        dispatch_semaphore_t s = dispatch_semaphore_create(0);
        __block NSString *err = nil;
        id<XArchService> proxy = [c remoteObjectProxyWithErrorHandler:^(NSError *e) {
            err = [e description];
            dispatch_semaphore_signal(s);
        }];
        #define WAIT() (dispatch_semaphore_wait(s, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)) == 0)

        __block long long sum = 0; __block BOOL got = NO;
        [proxy addInt:-5 long:100000 unsigned:7 reply:^(long long r) { sum = r; got = YES; dispatch_semaphore_signal(s); }];
        WAIT();
        report("scalar arguments (int, long, NSUInteger) and a long long reply", got && sum == 100002);
        if (!got) printf("  error: %s\n", err.UTF8String);

        __block NSString *rs = nil; __block NSArray *ra = nil; got = NO;
        [proxy echoString:@"hello" array:@[@"a", @1] reply:^(NSString *x, NSArray *y) { rs = x; ra = y; got = YES; dispatch_semaphore_signal(s); }];
        WAIT();
        report("object arguments and object reply", got && [rs isEqualToString:@"HELLO"] &&
              [ra isEqualToArray:(@[@"a", @1, @"added by receiver"])]);

        __block NSRange rr = NSMakeRange(0, 0); __block NSInteger ri = 0; __block BOOL rf = NO; got = NO;
        [proxy reverseRange:NSMakeRange(3, 9) signed:-42 flag:NO reply:^(NSRange r, NSInteger i, BOOL f) {
            rr = r; ri = i; rf = f; got = YES; dispatch_semaphore_signal(s); }];
        WAIT();
        report("NSRange, NSInteger and BOOL arguments and reply", got && rr.location == 9 && rr.length == 3 && ri == 42 && rf);

        [proxy noteString:@"first" number:@12345];
        [proxy noteString:@"second" number:@-1];
        __block NSArray *notes = nil; got = NO;
        [proxy fetchNotesWithReply:^(NSArray *n) { notes = n; got = YES; dispatch_semaphore_signal(s); }];
        WAIT();
        report("one-way messages are processed", got && [notes isEqualToArray:(@[@"first:12345", @"second:-1"])]);

        [c invalidate];
        printf("%d/%d passed\n", pass, total);
        return pass == total ? 0 : 1;
    }
}
