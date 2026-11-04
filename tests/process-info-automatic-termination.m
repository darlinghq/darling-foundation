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
        expect([info respondsToSelector:@selector(disableAutomaticTermination:)], @"responds to disableAutomaticTermination:");
        expect([info respondsToSelector:@selector(enableAutomaticTermination:)], @"responds to enableAutomaticTermination:");

        expect([info respondsToSelector:@selector(automaticTerminationSupportEnabled)], @"responds to automaticTerminationSupportEnabled");
        expect(![info automaticTerminationSupportEnabled], @"automatic termination support starts disabled");
        info.automaticTerminationSupportEnabled = YES;
        expect(info.automaticTerminationSupportEnabled, @"automatic termination support stays enabled once set");
        info.automaticTerminationSupportEnabled = NO;
        expect(!info.automaticTerminationSupportEnabled, @"automatic termination support can be disabled again");

        @try
        {
            [info disableAutomaticTermination:@"launching"];
            [info enableAutomaticTermination:@"launching"];
        }
        @catch (NSException *exception)
        {
            expect(NO, [NSString stringWithFormat:@"automatic termination calls raised %@", exception]);
        }

        NSLog(@"PASS: automatic termination calls exist and the support flag round-trips");
    }
    return 0;
}
