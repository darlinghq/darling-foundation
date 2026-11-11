// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: -[NSCalendar dateByAddingUnit:value:toDate:options:] and the
// NSDateComponentUndefined name. Expected values were observed on macOS 27
// (arm64) with the same inputs; see vd-upstream mac-probes/v372-calendar-add-unit.m.
#import <Foundation/Foundation.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

static NSCalendar *cal(NSString *tz)
{
    NSCalendar *c = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    [c setTimeZone:[NSTimeZone timeZoneWithName:tz]];
    [c setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    return c;
}

static NSDate *at(NSCalendar *c, int y, int m, int d, int h, int mi, int s)
{
    NSDateComponents *dc = [[NSDateComponents alloc] init];
    [dc setYear:y]; [dc setMonth:m]; [dc setDay:d];
    [dc setHour:h]; [dc setMinute:mi]; [dc setSecond:s];
    return [c dateFromComponents:dc];
}

// Adds and compares the result with an expected wall-clock time and UTC offset (seconds).
static void expect(const char *name, NSCalendar *c, NSDate *start, NSCalendarUnit unit, NSInteger value,
                   NSCalendarOptions opts, int y, int m, int d, int h, int mi, int s, int offset)
{
    NSDate *r = [c dateByAddingUnit:unit value:value toDate:start options:opts];
    if (r == nil) {
        report(name, NO);
        return;
    }
    NSDateComponents *p = [c components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                           NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:r];
    BOOL ok = [p year] == y && [p month] == m && [p day] == d && [p hour] == h && [p minute] == mi &&
              [p second] == s && [[c timeZone] secondsFromGMTForDate:r] == offset;
    if (!ok)
        printf("  got %ld-%02ld-%02ld %02ld:%02ld:%02ld offset %ld\n", (long)[p year], (long)[p month], (long)[p day],
               (long)[p hour], (long)[p minute], (long)[p second], (long)[[c timeZone] secondsFromGMTForDate:r]);
    report(name, ok);
}

int main(void)
{
    @autoreleasepool {
        NSCalendar *utc = cal(@"UTC");
        NSCalendar *ny = cal(@"America/New_York");
        NSCalendarOptions W = NSCalendarWrapComponents;
        const int EST = -5 * 3600, EDT = -4 * 3600;

        report("NSDateComponentUndefined is NSIntegerMax", NSDateComponentUndefined == NSIntegerMax);
        report("unset component is NSDateComponentUndefined", [[[NSDateComponents alloc] init] month] == NSDateComponentUndefined);
        report("NSCalendarWrapComponents equals NSWrapCalendarComponents", NSCalendarWrapComponents == NSWrapCalendarComponents);

        // Month end: the day is clamped to the last day of the target month.
        expect("jan31 +1 month", utc, at(utc, 2023, 1, 31, 12, 0, 0), NSCalendarUnitMonth, 1, 0, 2023, 2, 28, 12, 0, 0, 0);
        expect("jan31 +1 month wrap", utc, at(utc, 2023, 1, 31, 12, 0, 0), NSCalendarUnitMonth, 1, W, 2023, 2, 28, 12, 0, 0, 0);
        expect("leap jan31 +1 month", utc, at(utc, 2024, 1, 31, 12, 0, 0), NSCalendarUnitMonth, 1, 0, 2024, 2, 29, 12, 0, 0, 0);
        expect("feb29 +1 year", utc, at(utc, 2024, 2, 29, 12, 0, 0), NSCalendarUnitYear, 1, 0, 2025, 2, 28, 12, 0, 0, 0);
        expect("nov30 +3 months carries into the year", utc, at(utc, 2023, 11, 30, 12, 0, 0), NSCalendarUnitMonth, 3, 0, 2024, 2, 29, 12, 0, 0, 0);

        // Negative values.
        expect("mar31 -1 month", utc, at(utc, 2023, 3, 31, 12, 0, 0), NSCalendarUnitMonth, -1, 0, 2023, 2, 28, 12, 0, 0, 0);
        expect("mar31 -1 month wrap", utc, at(utc, 2023, 3, 31, 12, 0, 0), NSCalendarUnitMonth, -1, W, 2023, 2, 28, 12, 0, 0, 0);
        expect("jan01 -1 day", utc, at(utc, 2023, 1, 1, 12, 0, 0), NSCalendarUnitDay, -1, 0, 2022, 12, 31, 12, 0, 0, 0);
        expect("-90 minutes", utc, at(utc, 2023, 1, 31, 12, 0, 0), NSCalendarUnitMinute, -90, 0, 2023, 1, 31, 10, 30, 0, 0);

        // Wrapping: the larger units stay fixed.
        expect("nov30 +3 months wrap", utc, at(utc, 2023, 11, 30, 12, 0, 0), NSCalendarUnitMonth, 3, W, 2023, 2, 28, 12, 0, 0, 0);
        expect("dec31 +1 day", utc, at(utc, 2023, 12, 31, 12, 0, 0), NSCalendarUnitDay, 1, 0, 2024, 1, 1, 12, 0, 0, 0);
        expect("dec31 +1 day wrap", utc, at(utc, 2023, 12, 31, 12, 0, 0), NSCalendarUnitDay, 1, W, 2023, 12, 1, 12, 0, 0, 0);
        expect("jan01 -1 day wrap", utc, at(utc, 2023, 1, 1, 12, 0, 0), NSCalendarUnitDay, -1, W, 2023, 1, 31, 12, 0, 0, 0);
        expect("jan01 -2 months wrap", utc, at(utc, 2023, 1, 1, 12, 0, 0), NSCalendarUnitMonth, -2, W, 2023, 11, 1, 12, 0, 0, 0);
        expect("dec01 +2 months wrap", utc, at(utc, 2023, 12, 1, 12, 0, 0), NSCalendarUnitMonth, 2, W, 2023, 2, 1, 12, 0, 0, 0);

        // Other units and zero.
        expect("zero value", utc, at(utc, 2023, 1, 31, 12, 0, 0), NSCalendarUnitDay, 0, 0, 2023, 1, 31, 12, 0, 0, 0);
        expect("+36 hours", utc, at(utc, 2023, 1, 31, 12, 0, 0), NSCalendarUnitHour, 36, 0, 2023, 2, 2, 0, 0, 0, 0);

        // Daylight saving time (America/New_York: 2023-03-12 02:00 -> 03:00, 2023-11-05 02:00 -> 01:00).
        expect("dst spring: 02:30 on the 11th +1 day lands after the gap", ny, at(ny, 2023, 3, 11, 2, 30, 0), NSCalendarUnitDay, 1, 0, 2023, 3, 12, 3, 30, 0, EDT);
        expect("dst spring: noon +1 day keeps wall clock", ny, at(ny, 2023, 3, 11, 12, 0, 0), NSCalendarUnitDay, 1, 0, 2023, 3, 12, 12, 0, 0, EDT);
        expect("dst spring: noon -1 day keeps wall clock", ny, at(ny, 2023, 3, 12, 12, 0, 0), NSCalendarUnitDay, -1, 0, 2023, 3, 11, 12, 0, 0, EST);
        expect("dst spring: +24 hours is elapsed time", ny, at(ny, 2023, 3, 11, 12, 0, 0), NSCalendarUnitHour, 24, 0, 2023, 3, 12, 13, 0, 0, EDT);
        expect("dst spring: 01:30 +1 hour skips the gap", ny, at(ny, 2023, 3, 12, 1, 30, 0), NSCalendarUnitHour, 1, 0, 2023, 3, 12, 3, 30, 0, EDT);
        expect("dst spring: 03:30 -1 hour", ny, at(ny, 2023, 3, 12, 3, 30, 0), NSCalendarUnitHour, -1, 0, 2023, 3, 12, 1, 30, 0, EST);
        expect("dst spring: 01:30 +1 hour wrap", ny, at(ny, 2023, 3, 12, 1, 30, 0), NSCalendarUnitHour, 1, W, 2023, 3, 12, 3, 30, 0, EDT);
        expect("dst spring: month addition into the gap", ny, at(ny, 2023, 2, 12, 2, 30, 0), NSCalendarUnitMonth, 1, 0, 2023, 3, 12, 3, 30, 0, EDT);
        expect("dst fall: noon +1 day keeps wall clock", ny, at(ny, 2023, 11, 4, 12, 0, 0), NSCalendarUnitDay, 1, 0, 2023, 11, 5, 12, 0, 0, EST);
        expect("dst fall: noon -1 day keeps wall clock", ny, at(ny, 2023, 11, 5, 12, 0, 0), NSCalendarUnitDay, -1, 0, 2023, 11, 4, 12, 0, 0, EDT);
        expect("dst fall: +24 hours is elapsed time", ny, at(ny, 2023, 11, 4, 12, 0, 0), NSCalendarUnitHour, 24, 0, 2023, 11, 5, 11, 0, 0, EST);
        expect("dst fall: 00:30 +1 hour is the first 01:30", ny, at(ny, 2023, 11, 5, 0, 30, 0), NSCalendarUnitHour, 1, 0, 2023, 11, 5, 1, 30, 0, EDT);
        expect("dst fall: 00:30 +2 hours is the second 01:30", ny, at(ny, 2023, 11, 5, 0, 30, 0), NSCalendarUnitHour, 2, 0, 2023, 11, 5, 1, 30, 0, EST);
        expect("dst fall: 03:30 -3 hours", ny, at(ny, 2023, 11, 5, 3, 30, 0), NSCalendarUnitHour, -3, 0, 2023, 11, 5, 1, 30, 0, EDT);

        // Same result as the components path.
        NSDate *d = at(utc, 2023, 1, 31, 12, 0, 0);
        NSDateComponents *one = [[NSDateComponents alloc] init];
        [one setMonth:1];
        report("equals dateByAddingComponents:toDate:options:",
              [[utc dateByAddingComponents:one toDate:d options:0] isEqual:[utc dateByAddingUnit:NSCalendarUnitMonth value:1 toDate:d options:0]]);
        NSCalendar *cur = [NSCalendar autoupdatingCurrentCalendar];
        report("works on the autoupdating calendar",
              [[cur dateByAddingUnit:NSCalendarUnitSecond value:90 toDate:d options:0] timeIntervalSinceDate:d] == 90);
    }
    printf("%s\n", failures ? "FAILED" : "PASSED");
    return failures != 0;
}
