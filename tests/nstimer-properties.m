// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: NSTimer's documented properties (fireDate, timeInterval, tolerance, userInfo, valid) used with
// dot syntax, which compiles only when the header declares them as properties, and their behaviour on a timer
// created from a block.
#import <Foundation/Foundation.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

int main(void)
{
    @autoreleasepool {
        NSDate *when = [NSDate dateWithTimeIntervalSinceNow:3600];
        NSTimer *timer = [[NSTimer alloc] initWithFireDate:when interval:2.5 repeats:YES block:^(NSTimer *t) {}];
        report("timeInterval property", timer.timeInterval == 2.5);
        report("fireDate property", [timer.fireDate isEqualToDate:when]);
        report("valid property before invalidate", timer.valid && timer.isValid);
        report("userInfo is nil for a block timer", timer.userInfo == nil);
        timer.tolerance = 0.25;
        report("tolerance property round trip", timer.tolerance == 0.25);
        NSDate *later = [when dateByAddingTimeInterval:60];
        timer.fireDate = later;
        report("fireDate setter", [timer.fireDate isEqualToDate:later]);
        [timer invalidate];
        report("valid property after invalidate", !timer.valid);

        NSTimer *info = [NSTimer timerWithTimeInterval:1 target:[NSObject class] selector:@selector(class) userInfo:@"u" repeats:NO];
        report("userInfo property", [info.userInfo isEqual:@"u"]);
        [info invalidate];
    }
    return failures ? 1 : 0;
}
