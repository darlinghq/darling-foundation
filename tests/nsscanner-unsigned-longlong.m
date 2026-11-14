/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// -[NSScanner scanUnsignedLongLong:]: decimal digits, skipped leading characters, clamping
// on overflow, and the sign handling pinned as a QUIRK in NSScanner.m.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

static BOOL scan(NSString *text, unsigned long long *value, NSUInteger *location)
{
    NSScanner *s = [NSScanner scannerWithString: text];
    BOOL ok = [s scanUnsignedLongLong: value];
    *location = [s scanLocation];
    return ok;
}

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    unsigned long long v = 777;
    NSUInteger loc = 99;

    expect(scan(@"42", &v, &loc) && v == 42 && loc == 2, @"plain number");
    expect(scan(@"  42x", &v, &loc) && v == 42 && loc == 4, @"leading whitespace is skipped, scanning stops at a non-digit");
    expect(scan(@"007", &v, &loc) && v == 7 && loc == 3, @"leading zeros");
    expect(scan(@"4 2", &v, &loc) && v == 4 && loc == 1, @"stops at a space");
    expect(scan(@"18446744073709551615", &v, &loc) && v == 18446744073709551615ULL && loc == 20, @"maximum value");
    expect(scan(@"1e3", &v, &loc) && v == 1 && loc == 1, @"no exponent");

    v = 777;
    expect(!scan(@"abc", &v, &loc) && v == 777 && loc == 0, @"no digits fails and leaves the value");
    expect(!scan(@"", &v, &loc), @"empty string fails");

    // QUIRK tests (sign and overflow)
    expect(scan(@"+5", &v, &loc) && v == 5 && loc == 2, @"quirk: a plus sign is accepted");
    v = 777;
    expect(!scan(@"-5", &v, &loc) && v == 777 && loc == 0, @"quirk: a minus sign fails with the location unchanged");
    expect(scan(@"18446744073709551616", &v, &loc) && v == 18446744073709551615ULL && loc == 20, @"quirk: overflow clamps to the maximum and consumes the digits");
    expect(scan(@"99999999999999999999999", &v, &loc) && v == 18446744073709551615ULL && loc == 23, @"quirk: long overflow consumes all digits");

    NSScanner *s = [NSScanner scannerWithString: @"12 34"];
    unsigned long long a = 0, b = 0;
    expect([s scanUnsignedLongLong: &a] && [s scanUnsignedLongLong: &b] && a == 12 && b == 34 && [s isAtEnd], @"two numbers in sequence");
    s = [NSScanner scannerWithString: @"15"];
    expect([s scanUnsignedLongLong: NULL] && [s scanLocation] == 2, @"a NULL result pointer scans past the number");

    [pool drain];
    return failures ? 1 : 0;
}
