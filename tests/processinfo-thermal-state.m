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
        NSProcessInfoThermalState state = [NSProcessInfo processInfo].thermalState;
        expect(state == NSProcessInfoThermalStateNominal, @"a host with no thermal source should report Nominal");
        expect(NSProcessInfoThermalStateFair == 1 && NSProcessInfoThermalStateSerious == 2 &&
               NSProcessInfoThermalStateCritical == 3, @"thermal states should keep the public enum values");
        expect(NSProcessInfoThermalStateDidChangeNotification != nil, @"the thermal state notification name should be exported");

        NSLog(@"PASS: NSProcessInfo.thermalState/NSProcessInfoThermalStateDidChangeNotification");
    }
    return 0;
}
