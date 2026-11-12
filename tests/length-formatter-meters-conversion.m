// Copyright (C) 2026 Lubos Dolezel
//
// NSLengthFormatter en_US output for -stringFromMeters:. The expected strings
// were observed on macOS 27 (this file passes there); see the QUIRK note in
// NSLengthFormatter.m for the yard and mile conversion.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK_STRING(actual, expected) do { NSString *a_ = (actual); if (![a_ isEqualToString:(expected)]) { printf("FAIL line %d: got \"%s\", expected \"%s\"\n", __LINE__, [a_ UTF8String], [(expected) UTF8String]); failures++; } } while (0)

int main(void)
{
    @autoreleasepool
    {
        NSLengthFormatter *formatter = [[[NSLengthFormatter alloc] init] autorelease];
        [[formatter numberFormatter] setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US"]];

        // Yards, selected between 3 and 5280 feet.
        CHECK_STRING([formatter stringFromMeters:1000], @"1,093.6 yd");
        CHECK_STRING([formatter stringFromMeters:1], @"1.094 yd");
        CHECK_STRING([formatter stringFromMeters:9], @"9.842 yd");
        CHECK_STRING([formatter stringFromMeters:50], @"54.68 yd");
        CHECK_STRING([formatter stringFromMeters:100], @"109.36 yd");
        CHECK_STRING([formatter stringFromMeters:250], @"273.4 yd");
        CHECK_STRING([formatter stringFromMeters:500], @"546.8 yd");
        CHECK_STRING([formatter stringFromMeters:999], @"1,092.506 yd");
        CHECK_STRING([formatter stringFromMeters:1001], @"1,094.694 yd");
        CHECK_STRING([formatter stringFromMeters:1500], @"1,640.4 yd");
        // Miles, from 5280 feet.
        CHECK_STRING([formatter stringFromMeters:2000], @"1.243 mi");
        CHECK_STRING([formatter stringFromMeters:12345], @"7.671 mi");
        CHECK_STRING([formatter stringFromMeters:100000], @"62.137 mi");
        CHECK_STRING([formatter stringFromMeters:1000000], @"621.37 mi");
        // Feet and inches below that.
        CHECK_STRING([formatter stringFromMeters:0.9], @"2.953 ft");
        CHECK_STRING([formatter stringFromMeters:0.5], @"1.64 ft");
        CHECK_STRING([formatter stringFromMeters:0.3], @"11.811 in");

        // The other styles use the same value.
        [formatter setUnitStyle:NSFormattingUnitStyleLong];
        CHECK_STRING([formatter stringFromMeters:1000], @"1,093.6 yards");
        [formatter setUnitStyle:NSFormattingUnitStyleShort];
        CHECK_STRING([formatter stringFromMeters:1000], @"1,093.6yd");
        [formatter setUnitStyle:NSFormattingUnitStyleMedium];

        // -stringFromValue:unit: formats the value it is given and does not convert.
        CHECK_STRING([formatter stringFromValue:1093.613298 unit:NSLengthFormatterUnitYard], @"1,093.613 yd");
        CHECK_STRING([formatter stringFromValue:1000 unit:NSLengthFormatterUnitYard], @"1,000 yd");
        CHECK_STRING([formatter stringFromValue:2.5 unit:NSLengthFormatterUnitMile], @"2.5 mi");

        // The unit name and the unit chosen for a length.
        NSLengthFormatterUnit unit = NSLengthFormatterUnitMeter;
        NSString *name = [formatter unitStringFromMeters:1000 usedUnit:&unit];
        CHECK_STRING(name, @"yd");
        if (unit != NSLengthFormatterUnitYard) { printf("FAIL: unit %ld\n", (long)unit); failures++; }
        name = [formatter unitStringFromMeters:12345 usedUnit:&unit];
        CHECK_STRING(name, @"mi");
        if (unit != NSLengthFormatterUnitMile) { printf("FAIL: unit %ld\n", (long)unit); failures++; }

        // Metric locales divide by the exact unit sizes.
        NSLengthFormatter *german = [[[NSLengthFormatter alloc] init] autorelease];
        [[german numberFormatter] setLocale:[NSLocale localeWithLocaleIdentifier:@"de_DE"]];
        CHECK_STRING([german stringFromMeters:12.403188], @"12,403 m");
        CHECK_STRING([german stringFromMeters:1527.506], @"1,528 km");
    }
    if (failures != 0) { printf("%d failures\n", failures); return 1; }
    printf("PASS: NSLengthFormatter meters conversion\n");
    return 0;
}
