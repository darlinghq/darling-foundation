#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdio.h>

static int failures;

static void check_string(const char *label, NSString *actual, NSString *expected)
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

int main(void)
{
    @autoreleasepool
    {
        NSLocale *german = [[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"];
        NSLocale *french = [[NSLocale alloc] initWithLocaleIdentifier:@"fr_FR"];

        check_string("arguments, fr_FR %.1f", format_with_arguments(@"%.1f", french, 1.5), @"1,5");
        check_string("arguments, de_DE %d / %.2f", format_with_arguments(@"%d / %.2f", german, 1234567, 1234.5), @"1.234.567 / 1.234,50");
        check_string("arguments, nil locale", format_with_arguments(@"%.1f", nil, 1.5), @"1.5");
        check_string("mutable arguments, de_DE %.2f", mutable_format_with_arguments(@"%.2f", german, 1234.5), @"1.234,50");
    }
    return failures != 0;
}
