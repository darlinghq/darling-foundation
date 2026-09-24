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

static void expectString(NSString *actual, NSString *expected, NSString *what)
{
    expect([actual isEqualToString:expected], [NSString stringWithFormat:@"%@: got %@, want %@", what, actual, expected]);
}

int main(void)
{
    @autoreleasepool
    {
        // 2021-07-15T12:00:00Z, a Thursday in ISO week 28, day 196 of the year.
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:1626350400];
        NSTimeZone *plusTwo = [NSTimeZone timeZoneForSecondsFromGMT:7200];

        NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
        expect(formatter.formatOptions == NSISO8601DateFormatWithInternetDateTime, @"default options");
        expect(formatter.timeZone.secondsFromGMT == 0, @"default time zone is GMT");
        expectString([formatter stringFromDate:date], @"2021-07-15T12:00:00Z", @"internet date time");

        formatter.timeZone = plusTwo;
        expectString([formatter stringFromDate:date], @"2021-07-15T14:00:00+02:00", @"time zone offset");
        formatter.timeZone = nil;
        expect(formatter.timeZone != nil && formatter.timeZone.secondsFromGMT == 0, @"nil resets the time zone to GMT");

        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        NSDate *fractional = [date dateByAddingTimeInterval:0.25];
        expectString([formatter stringFromDate:fractional], @"2021-07-15T12:00:00.250Z", @"fractional seconds");
        expect([[formatter dateFromString:@"2021-07-15T12:00:00.250Z"] isEqualToDate:fractional], @"parse fractional seconds");

        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        expect([[formatter dateFromString:@"2021-07-15T14:00:00+02:00"] isEqualToDate:date], @"parse offset");
        expect([[formatter dateFromString:@"2021-07-15T12:00:00Z"] isEqualToDate:date], @"parse Z");
        expect([formatter dateFromString:@"not a date"] == nil, @"reject garbage");
        expect([formatter dateFromString:@"2021-07-15"] == nil, @"reject a date without time");

        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithSpaceBetweenDateAndTime;
        expectString([formatter stringFromDate:date], @"2021-07-15 12:00:00Z", @"space separator");

        formatter.timeZone = plusTwo;
        formatter.formatOptions = NSISO8601DateFormatWithFullDate | NSISO8601DateFormatWithTime |
                                  NSISO8601DateFormatWithColonSeparatorInTime | NSISO8601DateFormatWithTimeZone;
        expectString([formatter stringFromDate:date], @"2021-07-15T14:00:00+0200", @"basic time zone");
        formatter.formatOptions = NSISO8601DateFormatWithYear | NSISO8601DateFormatWithMonth | NSISO8601DateFormatWithDay |
                                  NSISO8601DateFormatWithTime | NSISO8601DateFormatWithTimeZone;
        expectString([formatter stringFromDate:date], @"20210715T140000+0200", @"basic format");
        expect([[formatter dateFromString:@"20210715T140000+0200"] isEqualToDate:date], @"parse basic format");
        formatter.timeZone = nil;

        formatter.formatOptions = NSISO8601DateFormatWithFullDate;
        expectString([formatter stringFromDate:date], @"2021-07-15", @"full date");
        formatter.formatOptions = NSISO8601DateFormatWithYear | NSISO8601DateFormatWithDay | NSISO8601DateFormatWithDashSeparatorInDate;
        expectString([formatter stringFromDate:date], @"2021-196", @"ordinal date");
        formatter.formatOptions = NSISO8601DateFormatWithYear | NSISO8601DateFormatWithWeekOfYear | NSISO8601DateFormatWithDay |
                                  NSISO8601DateFormatWithDashSeparatorInDate;
        expectString([formatter stringFromDate:date], @"2021-W28-04", @"week date");
        // 2021-01-01 is a Friday in the last ISO week of 2020.
        expectString([formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:1609459200]], @"2020-W53-05", @"week-year boundary");
        formatter.formatOptions = NSISO8601DateFormatWithFullTime;
        expectString([formatter stringFromDate:date], @"12:00:00Z", @"full time");
        formatter.formatOptions = NSISO8601DateFormatWithYear;
        expectString([formatter stringFromDate:date], @"2021", @"year only");

        expectString([NSISO8601DateFormatter stringFromDate:date timeZone:plusTwo formatOptions:NSISO8601DateFormatWithInternetDateTime],
                     @"2021-07-15T14:00:00+02:00", @"class method");

        formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime;
        expect([formatter stringForObjectValue:@"not a date"] == nil, @"stringForObjectValue: non-date");
        expectString([formatter stringForObjectValue:date], @"2021-07-15T12:00:00Z", @"stringForObjectValue:");
        id parsed = nil;
        NSString *reason = nil;
        expect([formatter getObjectValue:&parsed forString:@"2021-07-15T12:00:00Z" errorDescription:&reason] &&
               [parsed isEqualToDate:date], @"getObjectValue: parses");
        parsed = nil;
        expect(![formatter getObjectValue:&parsed forString:@"garbage" errorDescription:&reason] && parsed == nil && reason != nil,
               @"getObjectValue: rejects garbage");

        formatter.timeZone = plusTwo;
        formatter.formatOptions = NSISO8601DateFormatWithFullDate | NSISO8601DateFormatWithFullTime | NSISO8601DateFormatWithFractionalSeconds;
        NSISO8601DateFormatter *copy = [formatter copy];
        expect(copy != formatter && copy.formatOptions == formatter.formatOptions &&
               copy.timeZone.secondsFromGMT == 7200, @"copy keeps state");
        copy.formatOptions = NSISO8601DateFormatWithFullDate;
        expect(formatter.formatOptions != NSISO8601DateFormatWithFullDate, @"copy is independent");

        expect([NSISO8601DateFormatter supportsSecureCoding], @"supportsSecureCoding");
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:formatter];
        NSISO8601DateFormatter *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
        expect([decoded isKindOfClass:[NSISO8601DateFormatter class]], @"decode class");
        expect(decoded.formatOptions == formatter.formatOptions, @"decode options");
        expect(decoded.timeZone.secondsFromGMT == 7200, @"decode time zone");
        expectString([decoded stringFromDate:fractional], @"2021-07-15T14:00:00.250+02:00", @"decoded formatter formats");

        [copy release];
        [formatter release];
    }
    NSLog(@"PASS: NSISO8601DateFormatter");
    return 0;
}
