#import <Foundation/Foundation.h>
#import <objc/runtime.h>
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
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.minimumFractionDigits = 1;
        formatter.maximumFractionDigits = 3;
        expect(formatter.numberStyle == NSNumberFormatterDecimalStyle, @"numberStyle");
        expect(formatter.minimumFractionDigits == 1 && [formatter minimumFractionDigits] == 1, @"minimumFractionDigits");
        expect(formatter.maximumFractionDigits == 3, @"maximumFractionDigits");
        expect([[formatter stringFromNumber:@2] isEqualToString:@"2.0"], @"minimum fraction digits applied");
        expect([[formatter stringFromNumber:@1.23456] isEqualToString:@"1.235"], @"maximum fraction digits applied");

        formatter.usesGroupingSeparator = YES;
        formatter.groupingSeparator = @"_";
        expect(formatter.usesGroupingSeparator && [formatter.groupingSeparator isEqualToString:@"_"], @"grouping properties");
        expect([[formatter stringFromNumber:@1234567] isEqualToString:@"1_234_567.0"], @"grouping applied");

        formatter.positivePrefix = @"+";
        expect([formatter.positivePrefix isEqualToString:@"+"], @"positivePrefix");
        expect([[formatter stringFromNumber:@5] isEqualToString:@"+5.0"], @"positivePrefix applied");

        formatter.lenient = YES;
        expect(formatter.isLenient && formatter.lenient, @"lenient uses the isLenient getter");

        // No inert storage behind the properties that have no implementation yet.
        expect(class_getInstanceVariable([NSNumberFormatter class], "_minimum") == NULL, @"no synthesized _minimum");
        expect(class_getInstanceVariable([NSNumberFormatter class], "_partialStringValidationEnabled") == NULL,
               @"no synthesized _partialStringValidationEnabled");

        NSBundle *bundle = [NSBundle bundleForClass:[NSNumberFormatter class]];
        NSDictionary<NSString *, id> *info = bundle.infoDictionary;
        expect(info != nil && info == [bundle infoDictionary], @"infoDictionary");
        expect([info[@"CFBundleIdentifier"] isEqual:bundle.bundleIdentifier], @"infoDictionary contents");
        NSDictionary<NSString *, id> *localized = bundle.localizedInfoDictionary;
        expect(localized == [bundle localizedInfoDictionary], @"localizedInfoDictionary");

        NSLog(@"PASS: NSNumberFormatter and NSBundle info properties");
    }
    return 0;
}
