#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(cond, label) do { if (!(cond)) { printf("FAIL %s (line %d)\n", label, __LINE__); failures++; } } while (0)

int main(void)
{
    @autoreleasepool {
        NSValue *vp = [NSValue alloc];
        CHECK([vp retainCount] == NSUIntegerMax, "NSPlaceholderValue retainCount");
        CHECK([vp retain] == vp, "NSPlaceholderValue retain");
        CHECK([vp autorelease] == vp, "NSPlaceholderValue autorelease");
        [vp release];
        [vp release];

        NSNumber *np = [NSNumber alloc];
        CHECK([np retainCount] == NSUIntegerMax, "NSPlaceholderNumber retainCount");
        CHECK([np retain] == np, "NSPlaceholderNumber retain");
        CHECK([np autorelease] == np, "NSPlaceholderNumber autorelease");
        [np release];
        [np release];
    }

    @autoreleasepool {
        int x = 42;
        NSValue *v = [NSValue valueWithBytes:&x objCType:@encode(int)];
        int out = 0;
        [v getValue:&out];
        CHECK(out == 42, "NSValue still works after placeholder release/autorelease");

        NSNumber *n = [NSNumber numberWithInt:7];
        CHECK([n intValue] == 7, "NSNumber still works after placeholder release/autorelease");
    }

    if (failures == 0)
        puts("PASS");
    return failures ? 1 : 0;
}
