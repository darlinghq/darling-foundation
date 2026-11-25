#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdio.h>

static int failures;

static void report(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

static NSString *with_arguments(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *result = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    return result;
}

static NSString *with_locale_arguments(NSString *format, id locale, ...)
{
    va_list args;
    va_start(args, locale);
    NSString *result = [[NSString alloc] initWithFormat:format locale:locale arguments:args];
    va_end(args);
    return result;
}

static NSString *mutable_with_locale_arguments(NSString *format, id locale, ...)
{
    va_list args;
    va_start(args, locale);
    NSString *result = [[NSMutableString alloc] initWithFormat:format locale:locale arguments:args];
    va_end(args);
    return result;
}

// Runs the block and reports whether it raised NSInvalidArgumentException.
static BOOL raises_invalid_argument(void (^block)(void))
{
    @try
    {
        block();
    }
    @catch (NSException *exception)
    {
        // The reason text is the one macOS gives (10.14.4 and 26.7.3): the placeholder class, the initializer all of these end in, and "nil argument".
        NSString *reason = [exception reason];
        return [[exception name] isEqualToString:NSInvalidArgumentException] && [reason hasPrefix:@"*** -["] &&
               [reason hasSuffix:@" initWithFormat:locale:arguments:]: nil argument"];
    }
    return NO;
}

int main(void)
{
    @autoreleasepool
    {
        // The documentation says the format must not be nil; a variable typed id keeps the nil from being diagnosed as a literal at the call sites.
        id nilObject = nil;
        NSString *nilFormat = nilObject;
        NSLocale *locale = [NSLocale currentLocale];

        report("+stringWithFormat: nil raises", raises_invalid_argument(^{ (void)[NSString stringWithFormat:nilFormat, 1]; }));
        report("+[NSMutableString stringWithFormat:] nil raises", raises_invalid_argument(^{ (void)[NSMutableString stringWithFormat:nilFormat, 1]; }));
        report("+localizedStringWithFormat: nil raises", raises_invalid_argument(^{ (void)[NSString localizedStringWithFormat:nilFormat, 1]; }));
        report("-initWithFormat: nil raises", raises_invalid_argument(^{ (void)[[NSString alloc] initWithFormat:nilFormat, 1]; }));
        report("-initWithFormat:arguments: nil raises", raises_invalid_argument(^{ (void)with_arguments(nilFormat, 1); }));
        report("-initWithFormat:locale: nil raises", raises_invalid_argument(^{ (void)[[NSString alloc] initWithFormat:nilFormat locale:locale, 1]; }));
        report("-initWithFormat:locale: nil format, nil locale raises", raises_invalid_argument(^{ (void)[[NSString alloc] initWithFormat:nilFormat locale:nil, 1]; }));
        report("-initWithFormat:locale:arguments: nil raises", raises_invalid_argument(^{ (void)with_locale_arguments(nilFormat, locale, 1); }));
        report("mutable -initWithFormat:locale:arguments: nil raises", raises_invalid_argument(^{ (void)mutable_with_locale_arguments(nilFormat, locale, 1); }));
        report("-stringByAppendingFormat: nil raises", raises_invalid_argument(^{ (void)[@"abc" stringByAppendingFormat:nilFormat, 1]; }));
#ifdef CHECK_APPEND_FORMAT_NIL
        // macOS 10.14.4 and 26.7.3 crash (SIGSEGV) in -[NSMutableString appendFormat:] with a nil format instead of raising, and so does
        // Darling for a CoreFoundation-backed string (it goes straight to CoreFoundation). The documented contract is to raise; build with
        // -DCHECK_APPEND_FORMAT_NIL to check it where it is implemented.
        report("-[NSMutableString appendFormat:] nil raises", raises_invalid_argument(^{ [[NSMutableString stringWithString:@"abc"] appendFormat:nilFormat, 1]; }));

        NSMutableString *untouched = [NSMutableString stringWithString:@"abc"];
        (void)raises_invalid_argument(^{ [untouched appendFormat:nilFormat, 1]; });
        report("-appendFormat: nil leaves the receiver unchanged", [untouched isEqualToString:@"abc"]);
#endif

        report("+stringWithFormat: non-nil still formats", [[NSString stringWithFormat:@"%d-%@", 7, @"x"] isEqualToString:@"7-x"]);
        report("+localizedStringWithFormat: non-nil still formats", [[NSString localizedStringWithFormat:@"%@", @"x"] isEqualToString:@"x"]);
        report("-initWithFormat: non-nil still formats", [[[NSString alloc] initWithFormat:@"%d", 7] isEqualToString:@"7"]);
        report("-initWithFormat:arguments: non-nil still formats", [with_arguments(@"%d", 7) isEqualToString:@"7"]);
        report("-initWithFormat:locale: non-nil still formats", [[[NSString alloc] initWithFormat:@"%d" locale:nil, 7] isEqualToString:@"7"]);
        report("-initWithFormat:locale:arguments: non-nil still formats", [with_locale_arguments(@"%d", nil, 7) isEqualToString:@"7"]);
        report("mutable -initWithFormat:locale:arguments: non-nil still formats", [mutable_with_locale_arguments(@"%d", nil, 7) isEqualToString:@"7"]);
        report("-stringByAppendingFormat: non-nil still formats", [[@"a" stringByAppendingFormat:@"%d", 7] isEqualToString:@"a7"]);
        NSMutableString *appended = [NSMutableString stringWithString:@"a"];
        [appended appendFormat:@"%d", 7];
        report("-appendFormat: non-nil still formats", [appended isEqualToString:@"a7"]);
        report("empty format is not nil and yields empty string", [[NSString stringWithFormat:@"", 1] isEqualToString:@""]);
    }
    return failures != 0;
}
