// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: -performSelector:onThread:withObject:waitUntilDone:modes: with several run loop
// modes, among them the common modes, performs the selector exactly once per call, whatever the
// order of the modes, and keeps doing so with other sources and timers in the run loop's common
// modes.
#import <Foundation/Foundation.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

@interface Counter : NSObject {
@public
    int count;
}
- (void)hit;
@end

@implementation Counter
- (void)hit { count++; }
@end

// posts from another thread while the main thread's run loop spins; returns the number performed
static int postFromThread(NSArray *modes, int posts)
{
    Counter *counter = [[Counter alloc] init];
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i < posts; i++) {
            [counter performSelectorOnMainThread:@selector(hit) withObject:nil waitUntilDone:NO modes:modes];
            usleep(1000);
        }
    });
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:3];
    while (counter->count < posts && [end timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    // anything delivered more than once would still be pending or arrive now
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    return counter->count;
}

int main(void)
{
    @autoreleasepool {
        NSString *modal = @"NSModalPanelRunLoopMode";
        id common = (id)kCFRunLoopCommonModes;
        const int posts = 20;

        report("default, common and modal modes",
               postFromThread(@[NSDefaultRunLoopMode, common, modal], posts) == posts);
        report("common modes before the default mode",
               postFromThread(@[common, NSDefaultRunLoopMode], posts) == posts);
        report("common, modal and default modes",
               postFromThread(@[common, modal, NSDefaultRunLoopMode], posts) == posts);

        // other items in the common modes, as an application's main run loop has
        int fds[2];
        pipe(fds);
        CFRunLoopSourceContext ctx = {0};
        CFRunLoopSourceRef plain = CFRunLoopSourceCreate(NULL, 0, &ctx);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), plain, kCFRunLoopCommonModes);
        CFSocketRef socket = CFSocketCreateWithNative(NULL, fds[0], kCFSocketReadCallBack, NULL, NULL);
        CFRunLoopSourceRef socketSource = CFSocketCreateRunLoopSource(NULL, socket, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), socketSource, kCFRunLoopCommonModes);
        Counter *unused = [[Counter alloc] init];
        NSTimer *timer = [NSTimer timerWithTimeInterval:3600 target:unused selector:@selector(hit) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        report("common modes before the default mode, with other common mode items",
               postFromThread(@[common, NSDefaultRunLoopMode], posts) == posts);
        report("default, common and modal modes, with other common mode items",
               postFromThread(@[NSDefaultRunLoopMode, common, modal], posts) == posts);
        [timer invalidate];
    }
    printf(failures ? "FAILED\n" : "OK\n");
    return failures != 0;
}
