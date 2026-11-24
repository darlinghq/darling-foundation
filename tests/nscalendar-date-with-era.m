// -[NSCalendar dateWithEra:year:month:day:hour:minute:second:nanosecond:] is documented
// (developer.apple.com/documentation/foundation/nscalendar/date(era:year:month:day:hour:minute:second:nanosecond:),
// macOS 10.9) as building a date from the eight component values, with nil for a combination that is not a date.
// The page does not say where that boundary is, what the era numbers are, or how the time zone is used. The open-source
// reference implementation (the swift-foundation sources vendored in the darling superproject, path
// src/external/swift-foundation there; Calendar_ObjC.swift) hands the eight values to
// the calendar's date-from-components method, so the checks here use dates that are valid and leave the boundary
// (month 13, April 31, hour 24) untested; era 0 meaning the era before the common era is a GUESS. The method also has to
// be there on the calendar that +autoupdatingCurrentCalendar returns (a private subclass), which is the receiver an
// application is likely to have. Sub-millisecond precision is not checked: the calendar machinery underneath takes the
// nanosecond in whole milliseconds.
// Needs no display. MRC. The calls go through a protocol so that the test builds against headers without the
// declaration and reports FAIL instead of raising when the selector is missing.
#import <Foundation/Foundation.h>
#include <stdio.h>

@protocol DateWithEra
- (NSDate *)dateWithEra:(NSInteger)era year:(NSInteger)year month:(NSInteger)month day:(NSInteger)day hour:(NSInteger)hour minute:(NSInteger)minute second:(NSInteger)second nanosecond:(NSInteger)nanosecond;
@end

static int failures;

static void report(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

static NSDate *make(NSCalendar *c, NSInteger era, NSInteger y, NSInteger m, NSInteger d, NSInteger h, NSInteger mi, NSInteger s, NSInteger ns)
{
    if (![c respondsToSelector:@selector(dateWithEra:year:month:day:hour:minute:second:nanosecond:)])
        return nil;
    return [(id<DateWithEra>)c dateWithEra:era year:y month:m day:d hour:h minute:mi second:s nanosecond:ns];
}

static NSCalendar *gregorian(NSString *zone)
{
    NSCalendar *c = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
    [c setTimeZone:[NSTimeZone timeZoneWithName:zone]];
    [c setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    return c;
}

static BOOL near(NSDate *date, NSTimeInterval seconds)
{
    return date != nil && fabs([date timeIntervalSinceReferenceDate] - seconds) < 0.0005;
}

int main(void)
{
    @autoreleasepool
    {
        NSCalendar *utc = gregorian(@"UTC");
        NSCalendar *ny = gregorian(@"America/New_York");
        NSCalendar *autoCal = [NSCalendar autoupdatingCurrentCalendar];

        report("NSCalendar responds to dateWithEra:year:month:day:hour:minute:second:nanosecond:",
               [utc respondsToSelector:@selector(dateWithEra:year:month:day:hour:minute:second:nanosecond:)]);
        report("the autoupdating current calendar responds too",
               [autoCal respondsToSelector:@selector(dateWithEra:year:month:day:hour:minute:second:nanosecond:)]);

        // The reference date is 2001-01-01 00:00:00 UTC, era 1 (the common era) in the Gregorian calendar.
        report("2001-01-01 00:00:00 UTC is the reference date", near(make(utc, 1, 2001, 1, 1, 0, 0, 0, 0), 0));
        report("2001-01-01 12:34:56 UTC is 45296 s after it", near(make(utc, 1, 2001, 1, 1, 12, 34, 56, 0), 45296));
        report("the nanosecond adds a fraction of a second", near(make(utc, 1, 2001, 1, 1, 0, 0, 0, 250000000), 0.25));
        report("2000-12-31 23:59:59 UTC is one second before it", near(make(utc, 1, 2000, 12, 31, 23, 59, 59, 0), -1));

        // The time zone of the calendar decides the instant; midnight in New York (UTC-5 in January) is five hours later.
        report("the calendar's time zone is used", near(make(ny, 1, 2001, 1, 1, 0, 0, 0, 0), 18000));

        // GUESS: era 0 is the era before the common era in the Gregorian calendar, which the components of the result show.
        NSDate *bce = make(utc, 0, 5, 3, 7, 0, 0, 0, 0);
        NSDateComponents *p = bce ? [utc components:NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:bce] : nil;
        report("era 0 year 5 March 7 reads back as the same era, year, month and day",
               p && [p era] == 0 && [p year] == 5 && [p month] == 3 && [p day] == 7);
        report("era 0 is before era 1", bce != nil && [bce timeIntervalSinceReferenceDate] < 0);

        // A leap day is a date in a leap year.
        report("2024-02-29 is a date", make(utc, 1, 2024, 2, 29, 12, 0, 0, 0) != nil);
        NSDate *leap = make(utc, 1, 2024, 2, 29, 12, 0, 0, 0);
        NSDate *next = make(utc, 1, 2024, 3, 1, 12, 0, 0, 0);
        report("2024-03-01 is a day after 2024-02-29", leap && next && [next timeIntervalSinceDate:leap] == 86400);

        // The autoupdating calendar answers like the current calendar it follows (same time zone and locale).
        NSCalendar *current = [NSCalendar currentCalendar];
        NSDate *viaAuto = make(autoCal, 1, 2010, 6, 15, 8, 30, 15, 0);
        NSDate *viaCurrent = make(current, 1, 2010, 6, 15, 8, 30, 15, 0);
        report("the autoupdating calendar gives the same date as the current calendar",
               viaAuto != nil && viaCurrent != nil && [viaAuto isEqual:viaCurrent]);
        // The autoupdating calendar's own time zone decides the instant: reading the result back through it gives the input.
        NSDateComponents *viaAutoBack = viaAuto ? [autoCal components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                                                   NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:viaAuto] : nil;
        report("the autoupdating calendar reads its result back as given",
               viaAutoBack && [viaAutoBack year] == 2010 && [viaAutoBack month] == 6 && [viaAutoBack day] == 15 &&
               [viaAutoBack hour] == 8 && [viaAutoBack minute] == 30 && [viaAutoBack second] == 15);

        // The date read back through the calendar has the components that were asked for.
        NSDate *d = make(ny, 1, 2020, 7, 4, 9, 8, 7, 0);
        NSDateComponents *back = d ? [ny components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour |
                                      NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:d] : nil;
        report("the components of the result are the ones given",
               back && [back year] == 2020 && [back month] == 7 && [back day] == 4 && [back hour] == 9 && [back minute] == 8 && [back second] == 7);
    }
    if (failures == 0)
        printf("PASS nscalendar-date-with-era\n");
    return failures != 0;
}
