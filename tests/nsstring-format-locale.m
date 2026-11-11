#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdio.h>

static int failures;

static void check_str(const char *label, NSString *actual, NSString *expected)
{
    BOOL ok = [actual isEqualToString:expected];
    printf("%s %s (got %s)\n", ok ? "PASS" : "FAIL", label, actual ? [actual UTF8String] : "nil");
    failures += !ok;
}

static NSString *format_with_arguments(NSString *format, id locale, ...)
{
    va_list args;
    va_start(args, locale);
    NSString *result = [[NSString alloc] initWithFormat:format locale:locale arguments:args];
    va_end(args);
    return result;
}

static NSString *mutable_format_with_arguments(NSString *format, id locale, ...)
{
    va_list args;
    va_start(args, locale);
    NSString *result = [[NSMutableString alloc] initWithFormat:format locale:locale arguments:args];
    va_end(args);
    return result;
}

static NSString *format_with_locale(NSString *format, id locale, double value)
{
    return [[NSString alloc] initWithFormat:format locale:locale, value];
}

int main(void)
{
    @autoreleasepool
    {
        NSLocale *german = [[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"];
        NSLocale *french = [[NSLocale alloc] initWithLocaleIdentifier:@"fr_FR"];

        check_str("arguments, fr_FR %.1f", format_with_arguments(@"%.1f", french, 1.5), @"1,5");
        check_str("arguments, de_DE %d / %.2f", format_with_arguments(@"%d / %.2f", german, 1234567, 1234.5), @"1.234.567 / 1.234,50");
        check_str("arguments, nil locale", format_with_arguments(@"%.1f", nil, 1.5), @"1.5");
        check_str("mutable arguments, de_DE %.2f", mutable_format_with_arguments(@"%.2f", german, 1234.5), @"1.234,50");

        check_str("locale variadic, fr_FR %.1f", format_with_locale(@"%.1f", french, 1.5), @"1,5");
        check_str("locale variadic, nil", format_with_locale(@"%.1f", nil, 1.5), @"1.5");

        NSNumber *number = [NSNumber numberWithDouble:1.5];
        check_str("object %@, fr_FR", [[NSString alloc] initWithFormat:@"%@" locale:french, number], @"1,5");
        check_str("object %@, nil locale", [[NSString alloc] initWithFormat:@"%@" locale:nil, number], @"1.5");
        check_str("array %@, fr_FR", [[NSString alloc] initWithFormat:@"%@" locale:french, @[number]], @"(\n    1,5\n)");

        NSString *localized = [NSString localizedStringWithFormat:@"%d / %.2f", 1234567, 1234.5];
        NSString *current = [[NSString alloc] initWithFormat:@"%d / %.2f" locale:[NSLocale currentLocale], 1234567, 1234.5];
        check_str("localizedStringWithFormat is non-nil", localized ? @"ok" : @"nil", @"ok");
        check_str("localizedStringWithFormat uses the current locale", localized, current);
    }
    return failures != 0;
}
