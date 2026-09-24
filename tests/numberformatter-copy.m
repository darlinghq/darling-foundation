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
        NSNumberFormatter *original = [[NSNumberFormatter alloc] init];
        original.numberStyle = NSNumberFormatterDecimalStyle;
        original.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];

        NSNumberFormatter *copy = [original copy];
        expect([[copy stringFromNumber:@1234.5] isEqualToString:@"1,234.5"], @"copy keeps the settings");
        copy.locale = [NSLocale localeWithLocaleIdentifier:@"de_DE"];
        copy.numberStyle = NSNumberFormatterPercentStyle;
        NSString *percent = [copy stringFromNumber:@0.25];
        expect([percent isEqualToString:@"25\u00a0%"], [NSString stringWithFormat:@"copy can be changed, got %@", percent]);
        expect([[original stringFromNumber:@1234.5] isEqualToString:@"1,234.5"], @"original is unchanged");

        NSLog(@"PASS: NSNumberFormatter copy");
    }
    return 0;
}
