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

int main(void)
{
    @autoreleasepool
    {
        NSCalendar *calendar = [NSCalendar currentCalendar];
        calendar.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        NSDateComponents *parts = [[NSDateComponents alloc] init];
        parts.year = 2024;
        parts.month = 7;
        parts.day = 19;
        parts.hour = 15;
        parts.minute = 42;
        NSDate *date = [calendar dateFromComponents:parts];
        expect(date != nil, @"calendar must create the fixture date");
        expect([calendar component:NSCalendarUnitYear fromDate:date] == 2024, @"year");
        expect([calendar component:NSCalendarUnitMonth fromDate:date] == 7, @"month");
        expect([calendar component:NSCalendarUnitDay fromDate:date] == 19, @"day");
        expect([calendar component:NSCalendarUnitMinute fromDate:date] == 42, @"minute");
        expect([calendar component:NSCalendarUnitCalendar fromDate:date] == NSUndefinedDateComponent,
              @"non-numeric unit");

        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease];
        [formatter setLocalizedDateFormatFromTemplate:@"yMMMd"];
        NSString *expectedFormat = [NSDateFormatter dateFormatFromTemplate:@"yMMMd" options:0 locale:formatter.locale];
        expect([formatter.dateFormat isEqualToString:expectedFormat], @"localized template pattern");
        NSString *rendered = [formatter stringFromDate:date];
        expect([rendered rangeOfString:@"2024"].location != NSNotFound, @"formatted year");
        expect([rendered rangeOfString:@"19"].location != NSNotFound, @"formatted day");

        expect(formatter.formattingContext == NSFormattingContextUnknown, @"default formatting context");
        formatter.locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"fr_FR"] autorelease];
        formatter.dateFormat = @"MMMM";
        formatter.formattingContext = NSFormattingContextStandalone;
        expect(formatter.formattingContext == NSFormattingContextStandalone, @"standalone context getter");
        NSString *standalone = [formatter stringFromDate:date];
        formatter.formattingContext = NSFormattingContextBeginningOfSentence;
        NSString *beginning = [formatter stringFromDate:date];
        formatter.formattingContext = NSFormattingContextMiddleOfSentence;
        NSString *middle = [formatter stringFromDate:date];
        expect(![beginning isEqualToString:middle], @"sentence context changes French capitalization");
        formatter.formattingContext = NSFormattingContextBeginningOfSentence;
        NSDateFormatter *copy = [formatter copy];
        expect(copy.formattingContext == NSFormattingContextBeginningOfSentence, @"copy preserves context");
        expect([standalone length] > 0 && [beginning length] > 0, @"contextual date formatting");
        NSLog(@"French month context: standalone=%@ beginning=%@ middle=%@", standalone, beginning, middle);
        [copy release];
        NSLog(@"PASS: calendar components and localized date template: %@", rendered);
        [formatter release];
        [parts release];
    }
    return 0;
}
