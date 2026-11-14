// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: -[NSValue getValue:size:] copies the value when the size matches
// the encoded type and raises NSInvalidArgumentException otherwise (the size
// check is a quirk, observed on macOS 26.7.3 with the same inputs). Also checks
// that objCType is usable as a property.
#import <Foundation/Foundation.h>
#include <string.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

// Returns YES if getValue:size: raised NSInvalidArgumentException. On success
// checks that the byte after the copied value is untouched.
static BOOL raises(NSValue *v, NSUInteger size, BOOL *untouched)
{
    unsigned char buf[64];
    memset(buf, 0xAA, sizeof buf);
    @try {
        [v getValue:buf size:size];
    } @catch (NSException *e) {
        return [[e name] isEqualToString:NSInvalidArgumentException];
    }
    if (untouched)
        *untouched = size < sizeof buf && buf[size] == 0xAA;
    return NO;
}

int main(void)
{
    @autoreleasepool {
        int i = 7;
        NSRect r = NSMakeRect(1, 2, 3, 4);
        NSValue *vi = [NSValue valueWithBytes:&i objCType:@encode(int)];
        NSValue *vr = [NSValue valueWithRect:r];
        NSNumber *n = [NSNumber numberWithInt:5];
        BOOL untouched = NO;

        int got = 0;
        [vi getValue:&got size:sizeof got];
        report("int: matching size copies the value", got == 7);
        report("int: matching size writes only the value", !raises(vi, sizeof(int), &untouched) && untouched);
        report("int: larger size raises", raises(vi, 8, NULL));
        report("int: smaller size raises", raises(vi, 2, NULL));
        report("int: zero size raises", raises(vi, 0, NULL));

        NSRect gotRect = NSZeroRect;
        [vr getValue:&gotRect size:sizeof gotRect];
        report("rect: matching size copies the value", NSEqualRects(gotRect, r));
        report("rect: half size raises", raises(vr, sizeof(NSRect) / 2, NULL));

        report("NSNumber: matching size copies", !raises(n, sizeof(int), NULL));
        report("NSNumber: larger size raises", raises(n, 8, NULL));

        report("objCType property", strcmp(vi.objCType, @encode(int)) == 0);
    }
    return failures ? 1 : 0;
}
