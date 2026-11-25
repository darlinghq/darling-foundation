// +[NSCalendar calendarWithIdentifier:] is documented (developer.apple.com/documentation/foundation/nscalendar/init(identifier:),
// shown as calendarWithIdentifier: in the Objective-C language variant) as creating a new calendar for an identifier from the
// NSCalendarIdentifier constants, available since macOS 10.9: the result is nil if the identifier is unknown, and the new
// calendar uses the current locale and the default time zone (macOS 10.14.4 and 26.7.3 actually give it the system locale, which the
// test follows). The page does not say what -calendarIdentifier returns for the
// new calendar or when two calendars are equal; those checks are marked GUESS.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void report(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

int main(void)
{
    @autoreleasepool
    {
        report("NSCalendar responds to +calendarWithIdentifier:",
               [NSCalendar respondsToSelector:@selector(calendarWithIdentifier:)]);

        NSCalendar *gregorian = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        report("gregorian is non-nil", gregorian != nil);

        // GUESS: the page documents -calendarIdentifier only as "an identifier for the calendar"; the identifier the
        // calendar was created with is the obvious reading.
        report("gregorian calendarIdentifier equals the constant",
               [[gregorian calendarIdentifier] isEqual:NSCalendarIdentifierGregorian]);

        // GUESS: equality is not described on the page; two calendars made the same way (same identifier, current locale,
        // default time zone) are expected to compare equal.
        NSCalendar *again = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        report("a second gregorian calendar is non-nil", again != nil);
        report("two gregorian calendars are isEqual", [gregorian isEqual:again]);

        // Documented: the calendar is new. Changing one does not change the other.
        NSTimeZone *utc = [NSTimeZone timeZoneForSecondsFromGMT:0];
        NSTimeZone *original = [again timeZone];
        [gregorian setTimeZone:utc];
        report("each call returns an independent calendar", [[again timeZone] isEqual:original] && [[gregorian timeZone] isEqual:utc]);

        // QUIRK test (see the QUIRK comment in src/NSCalendar.m). The documentation says the new calendar defaults to the current locale and the default time zone. Observed on macOS
        // 10.14.4 and 26.7.3 (the locale differs from the documentation): the locale is the system locale, the same as
        // -initWithCalendarIdentifier: gives, whatever the current locale is.
        NSCalendar *fresh = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        NSCalendar *viaInitForLocale = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
        report("default locale is the system locale",
               [[[fresh locale] localeIdentifier] isEqual:[[NSLocale systemLocale] localeIdentifier]]);
        report("default locale equals the one -initWithCalendarIdentifier: gives",
               [[[fresh locale] localeIdentifier] isEqual:[[viaInitForLocale locale] localeIdentifier]]);
        report("default time zone is the default time zone", [[fresh timeZone] isEqual:[NSTimeZone defaultTimeZone]]);

        // The other calendars named by the NSCalendarIdentifier constants are available. GUESS: the identifier round trip,
        // as for gregorian.
        NSArray<NSCalendarIdentifier> *others = @[ NSCalendarIdentifierISO8601, NSCalendarIdentifierHebrew,
                                                   NSCalendarIdentifierBuddhist, NSCalendarIdentifierJapanese ];
        for (NSCalendarIdentifier identifier in others)
        {
            NSCalendar *calendar = [NSCalendar calendarWithIdentifier:identifier];
            char label[96];
            snprintf(label, sizeof label, "%s is non-nil with a matching calendarIdentifier", [identifier UTF8String]);
            report(label, calendar != nil && [[calendar calendarIdentifier] isEqual:identifier]);
        }

        // Documented: nil if the identifier is an unrecognized string.
        report("unknown identifier gives nil", [NSCalendar calendarWithIdentifier:@"not-a-calendar"] == nil);
        // GUESS: the empty string is an unrecognized string like any other.
        report("empty identifier gives nil", [NSCalendar calendarWithIdentifier:@""] == nil);

        // Usage pattern: a gregorian calendar in UTC turns a date into components and back. 2001-01-01 00:00:00 UTC is the
        // reference date and was a Monday (weekday 2 with Sunday as 1).
        NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
        [calendar setTimeZone:utc];
        NSDate *referenceDate = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
        NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour |
                               NSCalendarUnitMinute | NSCalendarUnitSecond | NSCalendarUnitWeekday | NSCalendarUnitTimeZone;
        NSDateComponents *parts = [calendar components:units fromDate:referenceDate];
        report("components: 2001-01-01 00:00:00",
               parts != nil && [parts year] == 2001 && [parts month] == 1 && [parts day] == 1 && [parts hour] == 0 &&
                   [parts minute] == 0 && [parts second] == 0);
        report("components: weekday is Monday (2)", [parts weekday] == 2);
        report("components: time zone is UTC", [[parts timeZone] secondsFromGMT] == 0);

        NSDateComponents *input = [[NSDateComponents alloc] init];
        [input setYear:2001];
        [input setMonth:1];
        [input setDay:1];
        NSDate *built = [calendar dateFromComponents:input];
        [input release];
        report("dateFromComponents: 2001-01-01 is the reference date",
               built != nil && [built timeIntervalSinceReferenceDate] == 0);
        report("year of the reference date via component:fromDate:", [calendar component:NSCalendarUnitYear fromDate:referenceDate] == 2001);

        // The documented initializer still works as before.
        NSCalendar *viaInit = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
        report("initWithCalendarIdentifier: still non-nil", viaInit != nil);
        [viaInit release];
        report("initWithCalendarIdentifier: unknown identifier gives nil",
               [[NSCalendar alloc] initWithCalendarIdentifier:@"not-a-calendar"] == nil);
    }
    return failures != 0;
}
