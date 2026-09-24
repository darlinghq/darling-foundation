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
    expect([actual isEqualToString:expected], [NSString stringWithFormat:@"%@: expected \"%@\", got \"%@\"", what, expected, actual]);
}

static BOOL raises(void (^block)(void))
{
    @try
    {
        block();
    }
    @catch (NSException *exception)
    {
        return [[exception name] isEqualToString:NSInvalidArgumentException];
    }
    return NO;
}

static NSCalendar *calendarFor(NSString *localeIdentifier)
{
    // The CF identifier, as Darling's NSCalendarIdentifierGregorian does not match it yet (darling#979).
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:(NSString *)kCFGregorianCalendar];
    [calendar setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [calendar setLocale:[NSLocale localeWithLocaleIdentifier:localeIdentifier]];
    return calendar;
}

static NSDateComponentsFormatter *formatterFor(NSString *localeIdentifier, NSDateComponentsFormatterUnitsStyle style)
{
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.calendar = calendarFor(localeIdentifier);
    formatter.referenceDate = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
    formatter.unitsStyle = style;
    return formatter;
}

int main(void)
{
    @autoreleasepool
    {
        NSDateComponentsFormatter *defaults = [[NSDateComponentsFormatter alloc] init];
        expect(defaults.unitsStyle == NSDateComponentsFormatterUnitsStylePositional, @"default unitsStyle");
        expect(defaults.allowedUnits == 0, @"default allowedUnits");
        expect(defaults.zeroFormattingBehavior == NSDateComponentsFormatterZeroFormattingBehaviorDefault, @"default zeroFormattingBehavior");
        expect(defaults.calendar != nil, @"default calendar");
        expect(defaults.referenceDate == nil, @"default referenceDate");
        expect(!defaults.allowsFractionalUnits && !defaults.collapsesLargestUnit, @"default BOOLs");
        expect(!defaults.includesApproximationPhrase && !defaults.includesTimeRemainingPhrase, @"default phrases");
        expect(defaults.maximumUnitCount == 0, @"default maximumUnitCount");
        expect(defaults.formattingContext == NSFormattingContextUnknown, @"default formattingContext");

        NSDateComponentsFormatter *positional = formatterFor(@"en_US", NSDateComponentsFormatterUnitsStylePositional);
        expect([positional.calendar.locale.localeIdentifier isEqualToString:@"en_US"], @"calendar keeps its locale when copied");
        expectString([positional stringFromTimeInterval:0], @"0:00", @"positional 0s");
        expectString([positional stringFromTimeInterval:5], @"0:05", @"positional 5s");
        expectString([positional stringFromTimeInterval:70], @"1:10", @"positional 70s");
        expectString([positional stringFromTimeInterval:3903], @"1:05:03", @"positional 3903s");
        expectString([positional stringFromTimeInterval:-3903], @"-1:05:03", @"positional -3903s");
        positional.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        expectString([positional stringFromTimeInterval:90061], @"1d 1:01:01", @"positional with days");
        positional.allowedUnits = NSCalendarUnitDay;
        expectString([positional stringFromTimeInterval:5], @"0d", @"positional falls back to abbreviated units");
        positional.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        expectString([positional stringFromTimeInterval:90061], @"25:01:01", @"positional hours absorb days");
        positional.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
        expectString([positional stringFromTimeInterval:70], @"00:01:10", @"positional pad");
        expectString([positional stringFromTimeInterval:3903], @"01:05:03", @"positional pad hours");
        positional.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorNone;
        expectString([positional stringFromTimeInterval:3610], @"1:00:10", @"positional keeps the clock pattern");
        positional.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle;
        expect(raises(^{ [positional stringFromTimeInterval:3610]; }), @"positional hour:second is ambiguous");
        positional.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
        positional.collapsesLargestUnit = YES;
        expectString([positional stringFromTimeInterval:3663], @"61:03", @"collapsed hours are not shown");

        NSDictionary *styles = @{
            @(NSDateComponentsFormatterUnitsStyleAbbreviated) : @"1h 5m 3s",
            @(NSDateComponentsFormatterUnitsStyleShort) : @"1 hr, 5 min, 3 sec",
            @(NSDateComponentsFormatterUnitsStyleFull) : @"1 hour, 5 minutes, 3 seconds",
            @(NSDateComponentsFormatterUnitsStyleSpellOut) : @"one hour, five minutes, three seconds",
            @(NSDateComponentsFormatterUnitsStyleBrief) : @"1hr 5min 3sec",
        };
        for (NSNumber *style in styles)
        {
            NSDateComponentsFormatter *formatter = formatterFor(@"en_US", [style integerValue]);
            expectString([formatter stringFromTimeInterval:3903], styles[style], [NSString stringWithFormat:@"style %@", style]);
        }
        expectString([formatterFor(@"de_DE", NSDateComponentsFormatterUnitsStyleFull) stringFromTimeInterval:3903],
                     @"1 Stunde, 5 Minuten und 3 Sekunden", @"German full");

        NSDateComponentsFormatter *abbreviated = formatterFor(@"en_US", NSDateComponentsFormatterUnitsStyleAbbreviated);
        expectString([abbreviated stringFromTimeInterval:3603], @"1h 3s", @"default drops zero units");
        expectString([abbreviated stringFromTimeInterval:0], @"0s", @"all zero keeps the smallest unit");
        expectString([abbreviated stringFromTimeInterval:-3903], @"-1h 5m 3s", @"negative interval");
        expectString([abbreviated stringFromTimeInterval:-0.4], @"0s", @"no negative zero");
        expect([abbreviated stringFromTimeInterval:NAN] == nil, @"NaN interval");
        NSDate *origin = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
        NSDate *later = [[abbreviated calendar] dateByAddingComponents:({
            NSDateComponents *c = [[NSDateComponents alloc] init];
            c.year = 1;
            c.month = 2;
            c;
        }) toDate:origin options:0];
        expectString([abbreviated stringFromDate:origin toDate:later], @"1y 2mo", @"years and months");
        abbreviated.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        abbreviated.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorNone;
        expectString([abbreviated stringFromTimeInterval:3603], @"1h 0m 3s", @"no zero dropping");
        abbreviated.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDefault;
        abbreviated.maximumUnitCount = 2;
        expectString([abbreviated stringFromTimeInterval:4230], @"1h 10m", @"maximumUnitCount");
        abbreviated.maximumUnitCount = 1;
        abbreviated.allowsFractionalUnits = YES;
        expectString([abbreviated stringFromTimeInterval:5400], @"1.5h", @"maximumUnitCount with fractional units");
        abbreviated.allowsFractionalUnits = NO;
        abbreviated.maximumUnitCount = 0;
        abbreviated.collapsesLargestUnit = YES;
        expectString([abbreviated stringFromTimeInterval:63], @"63s", @"collapsesLargestUnit");
        abbreviated.collapsesLargestUnit = NO;
        abbreviated.allowedUnits = NSCalendarUnitHour;
        abbreviated.allowsFractionalUnits = YES;
        expectString([abbreviated stringFromTimeInterval:5400], @"1.5h", @"allowsFractionalUnits");
        abbreviated.allowsFractionalUnits = NO;
        expectString([abbreviated stringFromTimeInterval:5400], @"1h", @"whole units only");
        expect(raises(^{ abbreviated.allowedUnits = NSCalendarUnitEra; }), @"unsupported allowed unit");
        abbreviated.allowedUnits = 0;

        NSDateComponents *components = [[NSDateComponents alloc] init];
        components.hour = 1;
        components.minute = 70;
        components.second = NSUndefinedDateComponent;
        expectString([abbreviated stringFromDateComponents:components], @"2h 10m", @"components are normalized");
        expectString([abbreviated stringForObjectValue:components], @"2h 10m", @"stringForObjectValue");
        expect([abbreviated stringForObjectValue:@60] == nil, @"stringForObjectValue needs components");
        NSDate *start = [NSDate dateWithTimeIntervalSinceReferenceDate:1000];
        expectString([abbreviated stringFromDate:start toDate:[start dateByAddingTimeInterval:125]], @"2m 5s", @"date pair");

        NSDateComponentsFormatter *copy = [abbreviated copy];
        expect(copy != abbreviated && copy.unitsStyle == NSDateComponentsFormatterUnitsStyleAbbreviated, @"copy keeps style");
        expectString([copy stringFromTimeInterval:125], @"2m 5s", @"copy formats alike");

        abbreviated.calendar = nil;
        expect(abbreviated.calendar == nil, @"calendar can be cleared");
        expectString([abbreviated stringFromTimeInterval:3903], @"1h 5m 3s", @"nil calendar is en_US_POSIX");

        abbreviated.includesTimeRemainingPhrase = YES;
        expect([abbreviated stringFromTimeInterval:60] == nil, @"time-remaining phrase is not implemented");
        abbreviated.includesTimeRemainingPhrase = NO;
        abbreviated.includesApproximationPhrase = YES;
        expect([abbreviated stringFromTimeInterval:60] == nil, @"approximation phrase is not implemented");

        NSLog(@"PASS: NSDateComponentsFormatter");
    }
    return 0;
}
