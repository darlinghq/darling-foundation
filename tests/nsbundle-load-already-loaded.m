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

// A bundle whose code is already loaded must still report success from
// -load and -loadAndReturnError:, as on macOS.
int main(void)
{
    @autoreleasepool
    {
        NSString *path = @"/System/Library/Frameworks/CoreData.framework";
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        expect(bundle != nil, @"bundle must exist");

        expect([bundle load], @"first load");
        expect([bundle isLoaded], @"isLoaded after load");
        expect([bundle load], @"second load of a loaded bundle");

        NSError *error = nil;
        expect([bundle loadAndReturnError:&error], @"loadAndReturnError: of a loaded bundle");
        expect(error == nil, @"no error for a loaded bundle");

        NSBundle *again = [NSBundle bundleWithPath:path];
        expect([again load], @"load through a second lookup of the same path");

        NSLog(@"PASS: nsbundle-load-already-loaded");
    }
    return 0;
}
