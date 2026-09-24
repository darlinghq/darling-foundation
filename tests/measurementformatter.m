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
        NSMeasurementFormatter *formatter = [[NSMeasurementFormatter alloc] init];
        expect(formatter.unitOptions == 0, @"default unitOptions");
        expect(formatter.unitStyle == NSFormattingUnitStyleMedium, @"default unitStyle");
        expect([formatter.locale.localeIdentifier isEqualToString:[(NSLocale *)[NSLocale currentLocale] localeIdentifier]], @"default locale is the current locale");
        expect(formatter.numberFormatter.numberStyle == NSNumberFormatterDecimalStyle, @"default number formatter is decimal");

        formatter.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit | NSMeasurementFormatterUnitOptionsNaturalScale;
        formatter.unitStyle = NSFormattingUnitStyleLong;
        NSLocale *german = [NSLocale localeWithLocaleIdentifier:@"de_DE"];
        formatter.locale = german;
        formatter.numberFormatter.locale = german;
        expect(formatter.unitOptions == (NSMeasurementFormatterUnitOptionsProvidedUnit | NSMeasurementFormatterUnitOptionsNaturalScale), @"unitOptions");
        expect(formatter.unitStyle == NSFormattingUnitStyleLong, @"unitStyle");
        expect([formatter.locale.localeIdentifier isEqualToString:@"de_DE"], @"locale");
        expect([[formatter.numberFormatter stringFromNumber:@1234.5] isEqualToString:@"1.234,5"], @"number formatter keeps its locale");

        NSNumberFormatter *percent = [[NSNumberFormatter alloc] init];
        percent.numberStyle = NSNumberFormatterPercentStyle;
        formatter.numberFormatter = percent;
        expect(formatter.numberFormatter != percent && formatter.numberFormatter.numberStyle == NSNumberFormatterPercentStyle, @"numberFormatter is copied");

        NSMeasurementFormatter *copy = [formatter copy];
        expect(copy.unitStyle == NSFormattingUnitStyleLong && copy.unitOptions == formatter.unitOptions, @"copy keeps options");
        expect([copy.locale.localeIdentifier isEqualToString:@"de_DE"], @"copy keeps locale");
        expect(copy.numberFormatter.numberStyle == NSNumberFormatterPercentStyle, @"copy keeps number formatter");
        expect(copy.numberFormatter != formatter.numberFormatter, @"copy has its own number formatter");
        copy.numberFormatter.numberStyle = NSNumberFormatterScientificStyle;
        expect(formatter.numberFormatter.numberStyle == NSNumberFormatterPercentStyle, @"copy is independent");

        formatter.locale = nil;
        formatter.numberFormatter = nil;
        expect([formatter.locale.localeIdentifier isEqualToString:[(NSLocale *)[NSLocale currentLocale] localeIdentifier]], @"nil locale resets");
        expect(formatter.numberFormatter.numberStyle == NSNumberFormatterDecimalStyle, @"nil numberFormatter resets");

        NSLog(@"PASS: NSMeasurementFormatter");
    }
    return 0;
}
