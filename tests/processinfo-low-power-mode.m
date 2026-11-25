#import <Foundation/Foundation.h>
#include <stdlib.h>

// NSProcessInfo.lowPowerModeEnabled (macOS 12): a host with no low power mode
// reports it off, through both the property and its getter.

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
        expect(!info.lowPowerModeEnabled, @"low power mode should be off");
        expect(![info isLowPowerModeEnabled], @"the getter should agree with the property");
        expect([info respondsToSelector:@selector(isLowPowerModeEnabled)], @"the getter is isLowPowerModeEnabled");
        expect(NSProcessInfoPowerStateDidChangeNotification != nil, @"the power state notification name should be exported");

        NSLog(@"PASS: NSProcessInfo.lowPowerModeEnabled");
    }
    return 0;
}
