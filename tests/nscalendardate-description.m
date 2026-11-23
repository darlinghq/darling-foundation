// Copyright (C) 2026 Lubos Dolezel
//
// NSCalendarDate (deprecated) descriptions, calendar formats, date arithmetic, copies and keyed archives, the parts
// the class page documents (calendarFormat, descriptionWithCalendarFormat:, dateByAddingYears:...) and what macOS 10.14.4 and
// 26.7.3 do for the rest (they agree unless said: probes cal2.m, cal3.m and cal4.m of batch11b). The proleptic Gregorian
// calendar, the "?" of an unknown specifier and the padding of a width are observed behaviours. A width before a
// specifier (%3H) pads on 10.14.4 and is ignored on 26.7.3: run with the argument "width" to check it (10.14.4 and
// Darling). Prints PASS when everything holds; the exit code is the number of failed checks.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static int failures;
static void expect(BOOL ok, const char *what) {
    if (!ok) {
        printf("FAIL: %s\n", what);
        failures++;
    }
}
#define EXPECT_STR(actual, wanted, what) do { NSString *a_ = (actual); if (![a_ isEqualToString:(wanted)]) { printf("FAIL: %s: got [%s], wanted [%s]\n", what, [a_ UTF8String], [(wanted) UTF8String]); failures++; } } while (0)

int main(int argc, char **argv) {
    @autoreleasepool {
        BOOL checkWidth = argc > 1 && strcmp(argv[1], "width") == 0;
        [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneWithName:@"Europe/Prague"]];
        NSTimeZone *gmt = [NSTimeZone timeZoneWithName:@"GMT"];
        NSTimeZone *ny = [NSTimeZone timeZoneWithName:@"America/New_York"];
        NSTimeZone *kolkata = [NSTimeZone timeZoneWithName:@"Asia/Kolkata"];

        /* defaults of a date made from an interval, and descriptions in the zone of the date */
        NSCalendarDate *a = [[NSCalendarDate alloc] initWithTimeIntervalSinceReferenceDate:700000000];
        EXPECT_STR([a calendarFormat], @"%Y-%m-%d %H:%M:%S %z", "default format");
        EXPECT_STR([[a timeZone] name], @"Europe/Prague", "default zone");
        EXPECT_STR([a description], @"2023-03-08 21:26:40 +0100", "description in the default zone");
        NSCalendarDate *b = [NSCalendarDate dateWithYear:2024 month:7 day:19 hour:15 minute:42 second:9 timeZone:gmt];
        EXPECT_STR([b description], @"2024-07-19 15:42:09 +0000", "description gmt");
        NSCalendarDate *c = [NSCalendarDate dateWithYear:2024 month:7 day:19 hour:15 minute:42 second:9 timeZone:ny];
        EXPECT_STR([c description], @"2024-07-19 15:42:09 -0400", "description in a zone");
        EXPECT_STR([c descriptionWithLocale:nil], @"2024-07-19 15:42:09 -0400", "descriptionWithLocale uses the calendar format");
        EXPECT_STR(([NSString stringWithFormat:@"%@", c]), @"2024-07-19 15:42:09 -0400", "%@ of a date");
        EXPECT_STR([[NSCalendarDate dateWithYear:2024 month:12 day:25 hour:0 minute:30 second:0 timeZone:kolkata] description], @"2024-12-25 00:30:00 +0530", "half-hour zone");
        EXPECT_STR([[NSCalendarDate dateWithYear:2024 month:7 day:19 hour:15 minute:42 second:9 timeZone:nil] description], @"2024-07-19 15:42:09 +0200", "nil zone is the default zone");

        /* the proleptic Gregorian calendar, with year 0 and negative years, and no calendar switch in 1582 */
        EXPECT_STR([[NSCalendarDate dateWithYear:0 month:1 day:1 hour:0 minute:0 second:0 timeZone:gmt] description], @"0-01-01 00:00:00 +0000", "year 0");
        EXPECT_STR([[NSCalendarDate dateWithYear:1 month:1 day:1 hour:0 minute:0 second:0 timeZone:gmt] description], @"1-01-01 00:00:00 +0000", "year 1");
        EXPECT_STR([[NSCalendarDate dateWithYear:-5 month:1 day:1 hour:0 minute:0 second:0 timeZone:gmt] description], @"-5-01-01 00:00:00 +0000", "year -5");
        expect([[NSCalendarDate dateWithYear:1 month:1 day:1 hour:0 minute:0 second:0 timeZone:gmt] timeIntervalSinceReferenceDate] == -63113904000.0, "year 1 is proleptic Gregorian");
        expect([[NSCalendarDate dateWithYear:1500 month:3 day:1 hour:0 minute:0 second:0 timeZone:gmt] timeIntervalSinceReferenceDate] == -15804979200.0, "1500-03-01 is proleptic Gregorian");
        expect([[NSCalendarDate dateWithYear:0 month:1 day:1 hour:0 minute:0 second:0 timeZone:gmt] timeIntervalSinceReferenceDate] == -63145526400.0, "year 0 is a leap year before year 1");
        expect([[NSCalendarDate distantPast] timeIntervalSinceReferenceDate] == -63114076800.0, "distantPast");

        /* units out of range carry into the next larger one */
        EXPECT_STR([[NSCalendarDate dateWithYear:2024 month:13 day:1 hour:0 minute:0 second:0 timeZone:gmt] description], @"2025-01-01 00:00:00 +0000", "month 13");
        EXPECT_STR([[NSCalendarDate dateWithYear:2024 month:1 day:32 hour:25 minute:61 second:61 timeZone:gmt] description], @"2024-02-02 02:02:01 +0000", "day 32, hour 25, minute 61, second 61");

        /* arithmetic: the day of the month is clamped, days keep the time of day, hours are elapsed time */
        NSCalendarDate *jan31 = [NSCalendarDate dateWithYear:2024 month:1 day:31 hour:0 minute:0 second:0 timeZone:gmt];
        EXPECT_STR([[jan31 dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:0] description], @"2024-02-29 00:00:00 +0000", "31 January plus a month");
        EXPECT_STR([[b dateByAddingYears:1 months:1 days:1 hours:1 minutes:1 seconds:1] description], @"2025-08-20 16:43:10 +0000", "all units");
        EXPECT_STR([[b dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:-1] description], @"2024-07-19 15:42:08 +0000", "minus a second");
        NSCalendarDate *beforeDST = [NSCalendarDate dateWithYear:2024 month:3 day:9 hour:12 minute:0 second:0 timeZone:ny];
        EXPECT_STR([[beforeDST dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0] description], @"2024-03-10 12:00:00 -0400", "a day across the change to summer time");
        EXPECT_STR([[beforeDST dateByAddingYears:0 months:0 days:0 hours:24 minutes:0 seconds:0] description], @"2024-03-10 13:00:00 -0400", "24 hours across the change to summer time");
        expect([[b dateByAddingYears:1 months:0 days:0 hours:0 minutes:0 seconds:0] timeZone] == gmt, "the result keeps the zone");
        NSCalendarDate *plus = (NSCalendarDate *)[b dateByAddingTimeInterval:3600];
        expect([plus isKindOfClass:[NSCalendarDate class]], "dateByAddingTimeInterval: gives a calendar date");
        EXPECT_STR([plus description], @"2024-07-19 18:42:09 +0200", "dateByAddingTimeInterval: has the default zone");

        /* the elements */
        expect([c yearOfCommonEra] == 2024 && [c monthOfYear] == 7 && [c dayOfMonth] == 19 && [c hourOfDay] == 15 && [c minuteOfHour] == 42 && [c secondOfMinute] == 9, "elements in the zone of the date");
        expect([c dayOfWeek] == 5 && [c dayOfYear] == 201 && [c dayOfCommonEra] == 739086, "dayOfWeek, dayOfYear, dayOfCommonEra");

        /* copies and the format */
        NSCalendarDate *copy = [b copy];
        [b setCalendarFormat:@"%d/%m/%Y"];
        [b setTimeZone:ny];
        EXPECT_STR([b description], @"19/07/2024", "description with the set format");
        EXPECT_STR([copy description], @"2024-07-19 15:42:09 +0000", "a copy is independent");
        NSCalendarDate *copy2 = [b copy];
        EXPECT_STR([copy2 calendarFormat], @"%d/%m/%Y", "a copy keeps the format");
        expect([copy2 timeZone] == ny, "a copy keeps the zone");
        expect([copy isEqual:copy2] && [copy2 isEqualToDate:b], "copies are equal dates");
        [b setTimeZone:nil];
        EXPECT_STR([[b timeZone] name], @"Europe/Prague", "nil zone is the default zone");
        [b setCalendarFormat:nil];
        EXPECT_STR([b calendarFormat], @"%Y-%m-%d %H:%M:%S %z", "nil format is the default format");

        /* factories of NSDate give calendar dates when sent to the class */
        expect([[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:1000] isKindOfClass:[NSCalendarDate class]], "dateWithTimeIntervalSinceReferenceDate:");
        expect([[NSCalendarDate date] isKindOfClass:[NSCalendarDate class]], "date");
        expect([[[NSCalendarDate alloc] initWithTimeInterval:1 sinceDate:[NSDate dateWithTimeIntervalSinceReferenceDate:5]] isKindOfClass:[NSCalendarDate class]], "initWithTimeInterval:sinceDate:");

        /* the calendar format specifiers */
        NSCalendarDate *d1 = [NSCalendarDate dateWithYear:2024 month:3 day:5 hour:7 minute:8 second:9 timeZone:ny];
        EXPECT_STR([d1 descriptionWithCalendarFormat:@"%A|%B|%a|%b|%d|%e|%H|%I|%i|%j|%m|%M|%p|%S|%w|%y|%Y|%Z|%z|%F|%%"],
                   @"Tuesday|March|Tue|Mar|05|5|07|07|07|065|03|08|AM|09|2|24|2024|America/New_York|-0500|000|%", "specifiers");
        EXPECT_STR([d1 descriptionWithCalendarFormat:@"%c"], @"Tue Mar 05 07:08:09 America/New_York 2024", "%c");
        EXPECT_STR([d1 descriptionWithCalendarFormat:@"%x"], @"Tue Mar 05 2024", "%x");
        EXPECT_STR([d1 descriptionWithCalendarFormat:@"%X"], @"07:08:09 America/New_York", "%X");
        NSCalendarDate *d2 = [NSCalendarDate dateWithYear:2024 month:12 day:25 hour:0 minute:30 second:0 timeZone:kolkata];
        EXPECT_STR([d2 descriptionWithCalendarFormat:@"%I %i %p %A %j %z"], @"12 00 AM Wednesday 360 +0530", "midnight, day of year, zone");
        NSCalendarDate *d3 = [NSCalendarDate dateWithYear:2023 month:10 day:1 hour:13 minute:5 second:6 timeZone:gmt];
        EXPECT_STR([d3 descriptionWithCalendarFormat:@"%I %p %w %a"], @"01 PM 0 Sun", "afternoon, Sunday");
        EXPECT_STR([d1 descriptionWithCalendarFormat:@"%d/%m/%y %I:%M %p"], @"05/03/24 07:08 AM", "a typical format");
        EXPECT_STR([d1 descriptionWithCalendarFormat:@"literal text %Z end"], @"literal text America/New_York end", "text around a specifier");
        EXPECT_STR([d1 descriptionWithCalendarFormat:@"%A %B" locale:[NSLocale localeWithLocaleIdentifier:@"fr_FR"]], @"Tuesday March", "the locale is ignored");
        EXPECT_STR([d1 descriptionWithCalendarFormat:@"abc"], @"abc", "no specifier");
        EXPECT_STR([d1 descriptionWithCalendarFormat:@""], @"", "empty format");
        EXPECT_STR([d1 descriptionWithCalendarFormat:nil], @"", "nil format");
        EXPECT_STR([d1 descriptionWithCalendarFormat:@"%Y%"], @"2024", "a lone percent sign at the end gives nothing");
        EXPECT_STR([d1 descriptionWithCalendarFormat:@"%Q|%C|%-d|%.3S"], @"?|?|?d|?3S", "unknown specifiers give a question mark and consume the character");
        if (checkWidth) {
            EXPECT_STR([d1 descriptionWithCalendarFormat:@"%3H|%02d|%5y|%10Y|%1d"], @"  7|05|   24|      2024|5", "widths");
        }

        /* a keyed archive has the layout of macOS and round trips with the zone and the format */
        [c setCalendarFormat:@"%d/%m/%Y"];
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:c requiringSecureCoding:NO error:NULL];
        expect(archive != nil, "archived");
        NSDictionary *plist = archive ? [NSPropertyListSerialization propertyListWithData:archive options:0 format:NULL error:NULL] : nil;
        NSDictionary *object = nil;
        for (id each in [plist objectForKey:@"$objects"]) {
            if ([each isKindOfClass:[NSDictionary class]] && [each objectForKey:@"NS.time"] != nil)
                object = each;
        }
        expect(object != nil, "the archived date has NS.time");
        expect([[object objectForKey:@"NS.time"] doubleValue] == [c timeIntervalSinceReferenceDate], "NS.time is the interval");
        expect([object objectForKey:@"NS.timezone"] != nil && [object objectForKey:@"NS.format"] != nil, "NS.timezone and NS.format");
        NSCalendarDate *back = archive ? [NSKeyedUnarchiver unarchiveObjectWithData:archive] : nil;
        expect([back isKindOfClass:[NSCalendarDate class]], "unarchived as NSCalendarDate");
        expect([back timeIntervalSinceReferenceDate] == [c timeIntervalSinceReferenceDate], "unarchived interval");
        EXPECT_STR([[back timeZone] name], @"America/New_York", "unarchived zone");
        EXPECT_STR([back calendarFormat], @"%d/%m/%Y", "unarchived format");

        /* the instance variables are the ones of macOS */
        unsigned count = 0;
        Ivar *ivars = class_copyIvarList([NSCalendarDate class], &count);
        const char *wanted[] = {"refCount", "_timeIntervalSinceReferenceDate", "_timeZone", "_formatString", "_reserved"};
        expect(count == 5, "five instance variables");
        for (unsigned i = 0; i < count && i < 5; i++)
            expect(strcmp(ivar_getName(ivars[i]), wanted[i]) == 0, "instance variable names and order");
        free(ivars);
    }
    if (failures == 0)
        printf("PASS\n");
    return failures;
}
