#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        NSProcessInfo *info = [NSProcessInfo processInfo];
        expect([info respondsToSelector:@selector(isLowPowerModeEnabled)],
               @"NSProcessInfo should respond to -isLowPowerModeEnabled");
        expect(info.lowPowerModeEnabled == NO,
               @"lowPowerModeEnabled should return NO when low power mode is unsupported/inactive");

        NSLog(@"PASS: NSProcessInfo.isLowPowerModeEnabled");
    }
    return 0;
}
