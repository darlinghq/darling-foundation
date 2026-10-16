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

        @try
        {
            [info disableAutomaticTermination:@"launching"];
            [info enableAutomaticTermination:@"launching"];
        }
        @catch (NSException *exception)
        {
            expect(NO, [NSString stringWithFormat:@"automatic termination calls raised %@", exception]);
        }

        NSLog(@"PASS: automatic termination calls exist and do not raise");
    }
    return 0;
}
