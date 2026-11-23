// NSCalendarDate is documented (developer.apple.com/documentation/foundation/nscalendardate, deprecated since macOS
// 10.10, introduced 10.4) as "a specialized date object with embedded calendar information", an NSDate subclass. The
// pages for its members give only the declarations: +calendarDate, +dateWithYear:month:day:hour:minute:second:timeZone:,
// -initWithYear:month:day:hour:minute:second:timeZone:, the date element accessors (dayOfCommonEra, dayOfMonth, dayOfWeek,
// dayOfYear, hourOfDay, minuteOfHour, monthOfYear, secondOfMinute, yearOfCommonEra), timeZone/setTimeZone:,
// calendarFormat/setCalendarFormat: and -dateByAddingYears:months:days:hours:minutes:seconds:. The NSDate page documents
// what a subclass needs: -timeIntervalSinceReferenceDate and -initWithTimeIntervalSinceReferenceDate: relative to the
// absolute reference date (00:00:00 UTC on 1 January 2001), and NSCopying. Behaviors that the pages do not state are
// observed on macOS 10.14.4 and 26.7.3 (both give the same results for every line below; probes of batch11b). The dates asserted are calendar arithmetic: 2001-01-01 is the reference date, 2000-01-01 was a Saturday
// and 2024-07-19 a Friday.
#import <Foundation/Foundation.h>
#include <math.h>
#include <stdio.h>

static int failures;

static void report(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

// A subclass with its own instance variable, declared in the @interface as an application on the i386 fragile ABI would.
@interface TaggedCalendarDate : NSCalendarDate
{
    NSInteger tag;
}
- (NSInteger)tag;
- (void)setTag:(NSInteger)newTag;
@end

@implementation TaggedCalendarDate
- (NSInteger)tag { return tag; }
- (void)setTag:(NSInteger)newTag { tag = newTag; }
@end

static BOOL isDate(NSCalendarDate *date, NSInteger year, NSInteger month, NSInteger day, NSInteger hour, NSInteger minute, NSInteger second)
{
    return [date yearOfCommonEra] == year && [date monthOfYear] == month && [date dayOfMonth] == day &&
           [date hourOfDay] == hour && [date minuteOfHour] == minute && [date secondOfMinute] == second;
}

int main(void)
{
    @autoreleasepool
    {
        NSTimeZone *gmt = [NSTimeZone timeZoneForSecondsFromGMT:0];
        NSTimeZone *plus530 = [NSTimeZone timeZoneForSecondsFromGMT:19800];
        NSTimeZone *minus5 = [NSTimeZone timeZoneForSecondsFromGMT:-5 * 3600];

        SEL accessors[] = {
            @selector(dayOfCommonEra), @selector(dayOfMonth), @selector(dayOfWeek), @selector(dayOfYear),
            @selector(hourOfDay), @selector(minuteOfHour), @selector(monthOfYear), @selector(secondOfMinute),
            @selector(yearOfCommonEra), @selector(timeZone), @selector(setTimeZone:), @selector(calendarFormat),
            @selector(setCalendarFormat:), @selector(dateByAddingYears:months:days:hours:minutes:seconds:),
            @selector(initWithYear:month:day:hour:minute:second:timeZone:),
        };
        BOOL responds = [NSCalendarDate respondsToSelector:@selector(calendarDate)] &&
                        [NSCalendarDate respondsToSelector:@selector(dateWithYear:month:day:hour:minute:second:timeZone:)];
        for (size_t i = 0; i < sizeof(accessors) / sizeof(accessors[0]); i++)
            responds = responds && [NSCalendarDate instancesRespondToSelector:accessors[i]];
        report("NSCalendarDate responds to the documented factories and instance methods", responds);

        // +distantFuture and +distantPast, called before any NSDate version so that a cache shared with NSDate would show.
        NSCalendarDate *farFuture = [NSCalendarDate distantFuture];
        NSCalendarDate *farPast = [NSCalendarDate distantPast];
        report("+distantFuture and +distantPast give NSCalendarDate objects", [farFuture isKindOfClass:[NSCalendarDate class]] && [farPast isKindOfClass:[NSCalendarDate class]]);
        report("+distantFuture is after +distantPast", [farFuture compare:farPast] == NSOrderedDescending && [farPast compare:farFuture] == NSOrderedAscending);
        report("the elements of the distant dates can be read", [farFuture dayOfWeek] >= 0 && [farFuture dayOfWeek] <= 6 && [farPast dayOfWeek] >= 0 && [farPast dayOfWeek] <= 6);
        NSDate *plainFuture = [NSDate distantFuture];
        NSDate *plainPast = [NSDate distantPast];
        report("+[NSDate distantFuture] is still not an NSCalendarDate after +[NSCalendarDate distantFuture]", ![plainFuture isKindOfClass:[NSCalendarDate class]] && ![plainPast isKindOfClass:[NSCalendarDate class]]);
        report("the distant dates are ordered against NSDate ones and a current date", [farFuture compare:[NSDate date]] == NSOrderedDescending && [farPast compare:[NSDate date]] == NSOrderedAscending &&
               [plainFuture compare:farPast] == NSOrderedDescending && [plainPast compare:farFuture] == NSOrderedAscending);

        // The reference date.
        NSCalendarDate *reference = [NSCalendarDate dateWithYear:2001 month:1 day:1 hour:0 minute:0 second:0 timeZone:gmt];
        report("+dateWithYear:...timeZone: gives an object", reference != nil);
        report("the object is an NSCalendarDate and an NSDate", [reference isKindOfClass:[NSCalendarDate class]] && [reference isKindOfClass:[NSDate class]]);
        report("2001-01-01 00:00:00 GMT is the reference date", [reference timeIntervalSinceReferenceDate] == 0.0);
        report("timeZone is the zone passed in", [[reference timeZone] isEqual:gmt]);
        report("2001-01-01 00:00:00 GMT elements", isDate(reference, 2001, 1, 1, 0, 0, 0));
        // the pages give no numbering for the weekday and day counts.
        report("2001-01-01 (a Monday) has dayOfWeek 1 (Sunday is 0)", [reference dayOfWeek] == 1);
        report("2001-01-01 has dayOfYear 1", [reference dayOfYear] == 1);
        report("2001-01-01 has dayOfCommonEra 730486 (1 January 1 CE is day 1)", [reference dayOfCommonEra] == 730486);

        // Every accessor on a date in the middle of a year.
        NSCalendarDate *friday = [NSCalendarDate dateWithYear:2024 month:7 day:19 hour:15 minute:42 second:9 timeZone:gmt];
        report("2024-07-19 15:42:09 GMT elements round trip", isDate(friday, 2024, 7, 19, 15, 42, 9));
        report("2024-07-19 15:42:09 GMT is 743096529 s after the reference date", [friday timeIntervalSinceReferenceDate] == 743096529.0);
        report("2024-07-19 (a Friday) has dayOfWeek 5", [friday dayOfWeek] == 5);
        report("2024-07-19 (leap year) has dayOfYear 201", [friday dayOfYear] == 201);
        NSCalendarDate *saturday = [NSCalendarDate dateWithYear:2000 month:1 day:1 hour:12 minute:0 second:0 timeZone:gmt];
        report("2000-01-01 (a Saturday) has dayOfWeek 6", [saturday dayOfWeek] == 6);
        report("2000-01-01 has dayOfCommonEra 730120", [saturday dayOfCommonEra] == 730120);
        NSCalendarDate *nextDay = [NSCalendarDate dateWithYear:2000 month:1 day:2 hour:12 minute:0 second:0 timeZone:gmt];
        report("dayOfCommonEra grows by one from one day to the next", [nextDay dayOfCommonEra] - [saturday dayOfCommonEra] == 1);
        NSCalendarDate *newYear = [NSCalendarDate dateWithYear:2001 month:1 day:1 hour:12 minute:0 second:0 timeZone:gmt];
        report("dayOfCommonEra grows by 366 across the leap year 2000", [newYear dayOfCommonEra] - [saturday dayOfCommonEra] == 366);

        // A fixed offset zone: the instant is the wall-clock time minus the offset.
        NSCalendarDate *india = [NSCalendarDate dateWithYear:2001 month:1 day:1 hour:0 minute:0 second:0 timeZone:plus530];
        report("the same wall-clock time in a +05:30 zone is 19800 s earlier", [india timeIntervalSinceReferenceDate] == -19800.0);
        report("+05:30 zone elements", isDate(india, 2001, 1, 1, 0, 0, 0) && [[india timeZone] isEqual:plus530]);

        // a nil time zone means the default time zone (observed).
        NSTimeZone *savedDefault = [NSTimeZone defaultTimeZone];
        [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:3600]];
        NSCalendarDate *defaulted = [NSCalendarDate dateWithYear:2001 month:1 day:1 hour:0 minute:0 second:0 timeZone:nil];
        report("a nil time zone gives the default time zone", [[defaulted timeZone] isEqual:[NSTimeZone defaultTimeZone]]);
        report("a nil time zone reads the wall-clock time in the default zone", [defaulted timeIntervalSinceReferenceDate] == -3600.0);
        NSCalendarDate *fromInterval = [[NSCalendarDate alloc] initWithTimeIntervalSinceReferenceDate:0.0];
        report("initWithTimeIntervalSinceReferenceDate: starts in the default time zone",
               [[fromInterval timeZone] isEqual:[NSTimeZone defaultTimeZone]] && isDate(fromInterval, 2001, 1, 1, 1, 0, 0));
        [NSTimeZone setDefaultTimeZone:savedDefault];

        // The NSDate designated initializer and inherited factories.
        report("initWithTimeIntervalSinceReferenceDate: keeps the interval", [fromInterval timeIntervalSinceReferenceDate] == 0.0);
        [fromInterval release];
        NSDate *nsdateFactory = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:86400.0];
        report("the inherited +dateWithTimeIntervalSinceReferenceDate: gives an NSCalendarDate",
               [nsdateFactory isKindOfClass:[NSCalendarDate class]] && [nsdateFactory timeIntervalSinceReferenceDate] == 86400.0);
        NSCalendarDate *now = [NSCalendarDate calendarDate];
        report("+calendarDate is the current time", now != nil && [now isKindOfClass:[NSCalendarDate class]] &&
               fabs([now timeIntervalSinceNow]) < 60.0);
        NSCalendarDate *plainInit = [[NSCalendarDate alloc] init];
        report("-init is the current time", plainInit != nil && fabs([plainInit timeIntervalSinceNow]) < 60.0);
        [plainInit release];
        NSCalendarDate *instance = [[NSCalendarDate alloc] initWithYear:2001 month:1 day:2 hour:0 minute:0 second:0 timeZone:gmt];
        report("-initWithYear:...timeZone: gives 2001-01-02 00:00:00 GMT", instance != nil && [instance timeIntervalSinceReferenceDate] == 86400.0);
        [instance release];

        // setTimeZone: changes the wall clock, not the instant.
        NSCalendarDate *moving = [NSCalendarDate dateWithYear:2001 month:1 day:1 hour:0 minute:0 second:0 timeZone:gmt];
        [moving setTimeZone:plus530];
        report("setTimeZone: +05:30 changes the elements to 05:30", isDate(moving, 2001, 1, 1, 5, 30, 0) && [[moving timeZone] isEqual:plus530]);
        report("setTimeZone: leaves the instant alone", [moving timeIntervalSinceReferenceDate] == 0.0);
        [moving setTimeZone:minus5];
        report("setTimeZone: -05:00 moves back to the previous year", isDate(moving, 2000, 12, 31, 19, 0, 0));
        report("setTimeZone: -05:00 changes dayOfYear to 366 (2000 was a leap year)", [moving dayOfYear] == 366);
        [moving setTimeZone:nil];
        report("setTimeZone:nil gives the default time zone", [[moving timeZone] isEqual:[NSTimeZone defaultTimeZone]]);

        // calendarFormat.
        NSCalendarDate *formatted = [NSCalendarDate dateWithYear:2001 month:1 day:1 hour:0 minute:0 second:0 timeZone:gmt];
        report("the default calendar format is %Y-%m-%d %H:%M:%S %z", [[formatted calendarFormat] isEqualToString:@"%Y-%m-%d %H:%M:%S %z"]);
        [formatted setCalendarFormat:@"%Y/%m/%d"];
        report("setCalendarFormat: is read back", [[formatted calendarFormat] isEqualToString:@"%Y/%m/%d"]);
        NSMutableString *mutableFormat = [NSMutableString stringWithString:@"%H"];
        [formatted setCalendarFormat:mutableFormat];
        [mutableFormat appendString:@":%M"];
        report("the format is copied", [[formatted calendarFormat] isEqualToString:@"%H"]);
        [formatted setCalendarFormat:@"%Y/%m/%d"];

        // dateByAddingYears:months:days:hours:minutes:seconds:.
        NSCalendarDate *base = [NSCalendarDate dateWithYear:2001 month:1 day:15 hour:10 minute:20 second:30 timeZone:plus530];
        [base setCalendarFormat:@"%Y"];
        NSCalendarDate *added = [base dateByAddingYears:1 months:2 days:3 hours:4 minutes:5 seconds:6];
        report("adding 1y 2m 3d 4h 5m 6s", added != nil && isDate(added, 2002, 3, 18, 14, 25, 36));
        report("the result is an NSCalendarDate", [added isKindOfClass:[NSCalendarDate class]]);
        report("the result keeps the time zone and calendar format", [[added timeZone] isEqual:plus530] && [[added calendarFormat] isEqualToString:@"%Y"]);
        report("the receiver is not changed", isDate(base, 2001, 1, 15, 10, 20, 30));
        report("adding zero gives the same instant", [[base dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:0] isEqualToDate:base]);
        NSCalendarDate *back = [added dateByAddingYears:-1 months:-2 days:-3 hours:-4 minutes:-5 seconds:-6];
        report("adding the negated values goes back", isDate(back, 2001, 1, 15, 10, 20, 30));
        NSCalendarDate *marchFirst = [NSCalendarDate dateWithYear:2001 month:3 day:1 hour:0 minute:0 second:0 timeZone:gmt];
        report("one day before 2001-03-01 is 2001-02-28", isDate([marchFirst dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0], 2001, 2, 28, 0, 0, 0));
        NSCalendarDate *leapMarch = [NSCalendarDate dateWithYear:2000 month:3 day:1 hour:0 minute:0 second:0 timeZone:gmt];
        report("one day before 2000-03-01 is 2000-02-29", isDate([leapMarch dateByAddingYears:0 months:0 days:-1 hours:0 minutes:0 seconds:0], 2000, 2, 29, 0, 0, 0));
        NSCalendarDate *monthEnd = [NSCalendarDate dateWithYear:2001 month:1 day:31 hour:0 minute:0 second:0 timeZone:gmt];
        report("one day after 2001-01-31 is 2001-02-01", isDate([monthEnd dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0], 2001, 2, 1, 0, 0, 0));
        report("two days after 2000-02-28 is 2000-03-01 (the 29th exists)",
               isDate([[NSCalendarDate dateWithYear:2000 month:2 day:28 hour:0 minute:0 second:0 timeZone:gmt] dateByAddingYears:0 months:0 days:2 hours:0 minutes:0 seconds:0], 2000, 3, 1, 0, 0, 0));
        report("hours carry into the day: 23:00 plus 2 hours", isDate([[NSCalendarDate dateWithYear:2001 month:1 day:1 hour:23 minute:0 second:0 timeZone:gmt] dateByAddingYears:0 months:0 days:0 hours:2 minutes:0 seconds:0], 2001, 1, 2, 1, 0, 0));
        report("seconds carry into the minute: 90 seconds", isDate([reference dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:90], 2001, 1, 1, 0, 1, 30));
        report("months carry into the year: 13 months", isDate([reference dateByAddingYears:0 months:13 days:0 hours:0 minutes:0 seconds:0], 2002, 2, 1, 0, 0, 0));
        // the pages do not say what 31 January plus one month is (the last day of February or a day of March); it must be a valid date.
        NSCalendarDate *jan31PlusMonth = [monthEnd dateByAddingYears:0 months:1 days:0 hours:0 minutes:0 seconds:0];
        report("2001-01-31 plus one month is in February or March", [jan31PlusMonth monthOfYear] == 2 || [jan31PlusMonth monthOfYear] == 3);

        // Comparison with plain NSDate objects (the reference date and a day later).
        NSDate *plainReference = [NSDate dateWithTimeIntervalSinceReferenceDate:0.0];
        NSDate *plainLater = [NSDate dateWithTimeIntervalSinceReferenceDate:86400.0];
        report("isEqual: with a plain NSDate of the same instant, both ways", [reference isEqual:plainReference] && [plainReference isEqual:reference]);
        report("isEqualToDate: with a plain NSDate of the same instant", [reference isEqualToDate:plainReference] && [plainReference isEqualToDate:reference]);
        report("hash matches a plain NSDate of the same instant", [reference hash] == [plainReference hash]);
        report("compare: with a plain NSDate", [reference compare:plainReference] == NSOrderedSame && [reference compare:plainLater] == NSOrderedAscending &&
               [plainLater compare:reference] == NSOrderedDescending);
        report("timeIntervalSinceDate: with a plain NSDate", [plainLater timeIntervalSinceDate:reference] == 86400.0 && [reference timeIntervalSinceDate:plainLater] == -86400.0);
        report("earlierDate: and laterDate: pick the right object", [reference earlierDate:plainLater] == reference && [reference laterDate:plainLater] == plainLater);
        report("different time zones, same instant: isEqual:", [india isEqual:[NSCalendarDate dateWithYear:2000 month:12 day:31 hour:18 minute:30 second:0 timeZone:gmt]]);

        // NSCopying.
        NSCalendarDate *original = [NSCalendarDate dateWithYear:2024 month:7 day:19 hour:15 minute:42 second:9 timeZone:plus530];
        [original setCalendarFormat:@"%Y"];
        NSCalendarDate *copy = [original copy];
        report("copy is an NSCalendarDate of the same instant, zone and format", [copy isKindOfClass:[NSCalendarDate class]] &&
               [copy isEqualToDate:original] && [[copy timeZone] isEqual:plus530] && [[copy calendarFormat] isEqualToString:@"%Y"]);
        [copy setTimeZone:minus5];
        [copy setCalendarFormat:@"%H"];
        report("changing the copy does not change the original", [[original timeZone] isEqual:plus530] && [[original calendarFormat] isEqualToString:@"%Y"] &&
               isDate(original, 2024, 7, 19, 15, 42, 9));
        [copy release];

        // An application subclass with an instance variable of its own.
        TaggedCalendarDate *tagged = [TaggedCalendarDate dateWithYear:2024 month:7 day:19 hour:15 minute:42 second:9 timeZone:gmt];
        report("the factory on a subclass gives an instance of the subclass", [tagged isKindOfClass:[TaggedCalendarDate class]]);
        [tagged setTag:0x5a5a];
        [tagged setTimeZone:plus530];
        [tagged setCalendarFormat:@"%Y"];
        report("the subclass instance variable is not overwritten by the superclass state", [tagged tag] == 0x5a5a);
        report("the subclass instance still has its elements", isDate(tagged, 2024, 7, 19, 21, 12, 9) && [[tagged timeZone] isEqual:plus530]);
        report("dateByAddingYears: on a subclass gives the subclass", [[tagged dateByAddingYears:0 months:0 days:1 hours:0 minutes:0 seconds:0] isKindOfClass:[TaggedCalendarDate class]]);
        NSCalendarDate *taggedCopy = [tagged copy];
        report("copy of a subclass instance is the subclass", [taggedCopy isKindOfClass:[TaggedCalendarDate class]] && [taggedCopy isEqualToDate:tagged]);
        [taggedCopy release];
    }
    @autoreleasepool {
        // Secure coding: macOS decodes a calendar date with requiresSecureCoding when NSCalendarDate or its superclass
        // NSDate is allowed, and refuses it when only an unrelated class is.
        NSCalendarDate *source = [NSCalendarDate dateWithYear:2020 month:5 day:6 hour:7 minute:8 second:9 timeZone:[NSTimeZone timeZoneForSecondsFromGMT:3600]];
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:source requiringSecureCoding:YES error:&error];
        report("a secure archive of a calendar date is written", data != nil);
        report("the class answers YES to +supportsSecureCoding", [NSCalendarDate supportsSecureCoding]);
        id back = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSCalendarDate class] fromData:data error:&error];
        report("secure decoding with NSCalendarDate allowed gives the date", [back isKindOfClass:[NSCalendarDate class]] && [back isEqualToDate:source] && [[back timeZone] isEqual:[source timeZone]]);
        back = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObject:[NSDate class]] fromData:data error:&error];
        report("secure decoding with NSDate allowed gives the date", [back isKindOfClass:[NSCalendarDate class]] && [back isEqualToDate:source]);
        error = nil;
        back = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObject:[NSString class]] fromData:data error:&error];
        report("secure decoding with only NSString allowed is refused (4864)", back == nil && [error code] == 4864);
    }
    printf("%s: %d failure(s)\n", failures ? "FAIL" : "PASS", failures);
    return failures ? 1 : 0;
}
