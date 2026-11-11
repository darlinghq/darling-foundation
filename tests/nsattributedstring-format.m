#import <Foundation/Foundation.h>
#include <stdarg.h>

// Expected behavior follows Apple's documentation for -[NSAttributedString
// initWithFormat:options:locale:arguments:] and NSAttributedStringFormattingOptions.

static int failures = 0;

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        failures++;
    }
}

static id attr(NSAttributedString *s, NSString *key, NSUInteger index)
{
    return [s attribute:key atIndex:index effectiveRange:NULL];
}

static NSAttributedString *formatWithArguments(NSAttributedString *format, NSAttributedStringFormattingOptions options, NSLocale *locale, ...)
{
    va_list args;
    va_start(args, locale);
    NSAttributedString *result = [[NSAttributedString alloc] initWithFormat:format options:options locale:locale arguments:args];
    va_end(args);
    return result;
}

static void testLiteralAndReplacementAttributes(void)
{
    NSMutableAttributedString *format = [[NSMutableAttributedString alloc] initWithString:@"Hi %@, %d items"];
    [format addAttribute:@"A" value:@"lead" range:NSMakeRange(0, 3)];
    [format addAttribute:@"B" value:@"spec" range:NSMakeRange(3, 2)];
    [format addAttribute:@"C" value:@"tail" range:NSMakeRange(5, 10)];

    NSAttributedString *s = formatWithArguments(format, 0, nil, @"Bob", 42);
    expect([[s string] isEqualToString:@"Hi Bob, 42 items"], [NSString stringWithFormat:@"plain substitution: %@", [s string]]);
    expect([attr(s, @"A", 0) isEqual:@"lead"] && [attr(s, @"A", 2) isEqual:@"lead"], @"literal prefix keeps its attributes");
    expect(attr(s, @"A", 3) == nil, @"prefix attribute does not leak into the replacement");
    for (NSUInteger i = 3; i < 6; i++)
    {
        expect([attr(s, @"B", i) isEqual:@"spec"], @"plain %@ replacement takes the specifier's attributes");
    }
    expect(attr(s, @"B", 6) == nil, @"specifier attribute stops at the replacement end");
    expect([attr(s, @"C", 6) isEqual:@"tail"], @"literal after the replacement keeps its attributes");
    expect([attr(s, @"C", 8) isEqual:@"tail"] && [attr(s, @"C", 9) isEqual:@"tail"], @"%d replacement takes the specifier's attributes");
    expect([attr(s, @"C", 15) isEqual:@"tail"], @"trailing literal keeps its attributes");
}

static void testAttributedArgument(void)
{
    NSMutableAttributedString *format = [[NSMutableAttributedString alloc] initWithString:@"Name: %@!"];
    [format addAttribute:@"color" value:@"red" range:NSMakeRange(6, 2)];

    NSMutableAttributedString *name = [[NSMutableAttributedString alloc] initWithString:@"Ann Lee"];
    [name addAttribute:@"color" value:@"green" range:NSMakeRange(0, 7)];
    [name addAttribute:@"weight" value:@"bold" range:NSMakeRange(0, 3)];

    NSAttributedString *merged = formatWithArguments(format, 0, nil, name);
    expect([[merged string] isEqualToString:@"Name: Ann Lee!"], [NSString stringWithFormat:@"attributed %%@ inserts the plain text: %@", [merged string]]);
    expect([attr(merged, @"color", 6) isEqual:@"red"], @"by default the format's attributes win over the argument's");
    expect([attr(merged, @"weight", 6) isEqual:@"bold"] && [attr(merged, @"weight", 8) isEqual:@"bold"], @"argument-only attributes are kept");
    expect(attr(merged, @"weight", 9) == nil, @"argument attribute runs keep their own ranges");
    expect([attr(merged, @"color", 12) isEqual:@"red"], @"format attribute covers the whole replacement");
    expect(attr(merged, @"color", 13) == nil, @"literal after the replacement has no color");

    NSAttributedString *argumentWins = formatWithArguments(format, NSAttributedStringFormattingInsertArgumentAttributesWithoutMerging, nil, name);
    expect([attr(argumentWins, @"color", 6) isEqual:@"green"] && [attr(argumentWins, @"color", 12) isEqual:@"green"], @"InsertArgumentAttributesWithoutMerging prefers the argument's attributes");
    expect([attr(argumentWins, @"weight", 7) isEqual:@"bold"], @"argument-only attributes are kept without merging too");
}

static void testPositionalAndReplacementIndex(void)
{
    NSMutableAttributedString *format = [[NSMutableAttributedString alloc] initWithString:@"%2$@ -- %1$@"];
    [format addAttribute:@"first" value:@YES range:NSMakeRange(0, 4)];
    [format addAttribute:@"second" value:@YES range:NSMakeRange(8, 4)];
    NSAttributedString *second = [[NSAttributedString alloc] initWithString:@"two" attributes:@{ @"arg" : @2 }];

    NSAttributedString *s = formatWithArguments(format, NSAttributedStringFormattingApplyReplacementIndexAttribute, nil, @"one", second);
    expect([[s string] isEqualToString:@"two -- one"], [NSString stringWithFormat:@"positional specifiers: %@", [s string]]);
    expect([attr(s, @"first", 0) boolValue] && [attr(s, @"arg", 2) isEqual:@2], @"first replacement merges spec and argument attributes");
    expect([attr(s, @"second", 7) boolValue] && attr(s, @"arg", 7) == nil, @"second replacement uses its own specifier's attributes");
    expect([attr(s, NSReplacementIndexAttributeName, 0) isEqual:@2], @"replacement index reflects the positional marker (2)");
    expect([attr(s, NSReplacementIndexAttributeName, 9) isEqual:@1], @"replacement index reflects the positional marker (1)");
    expect(attr(s, NSReplacementIndexAttributeName, 4) == nil, @"literal text has no replacement index");
    expect([NSReplacementIndexAttributeName isEqualToString:@"NSReplacementIndex"], @"NSReplacementIndexAttributeName value");

    NSAttributedString *plain = formatWithArguments(format, 0, nil, @"one", second);
    expect(attr(plain, NSReplacementIndexAttributeName, 0) == nil, @"no replacement index without the option");
}

static void testPercentLiteral(void)
{
    NSMutableAttributedString *format = [[NSMutableAttributedString alloc] initWithString:@"100%% of %@ done"];
    [format addAttribute:@"pct" value:@YES range:NSMakeRange(3, 2)];
    [format addAttribute:@"end" value:@YES range:NSMakeRange(11, 5)];
    NSAttributedString *s = formatWithArguments(format, NSAttributedStringFormattingApplyReplacementIndexAttribute, nil, @"it");
    expect([[s string] isEqualToString:@"100% of it done"], [NSString stringWithFormat:@"%%%% becomes %%: %@", [s string]]);
    expect([attr(s, @"pct", 3) boolValue] && attr(s, @"pct", 4) == nil, @"%% keeps the attributes of its specifier");
    expect(attr(s, NSReplacementIndexAttributeName, 3) == nil, @"%% is not an argument replacement");
    expect([attr(s, NSReplacementIndexAttributeName, 8) isEqual:@1], @"argument after %% is replacement 1");
    expect([attr(s, @"end", 10) boolValue] && attr(s, @"end", 9) == nil, @"literal after %@ stays aligned with the format");

    NSMutableAttributedString *flagged = [[NSMutableAttributedString alloc] initWithString:@"a%5%b%@"];
    [flagged addAttribute:@"arg" value:@YES range:NSMakeRange(5, 2)];
    NSString *plain = [NSString stringWithFormat:@"a%5%b%@", @"z"];
    NSAttributedString *t = formatWithArguments(flagged, 0, nil, @"z");
    expect([[t string] isEqualToString:plain], [NSString stringWithFormat:@"literal specifier with a width matches NSString: %@ vs %@", [t string], plain]);
    expect([attr(t, @"arg", [plain length] - 1) boolValue] && attr(t, @"arg", [plain length] - 2) == nil, @"replacement after a literal specifier with a width stays aligned");
}

static void testLocale(void)
{
    NSAttributedString *format = [[NSAttributedString alloc] initWithString:@"%d / %.2f" attributes:@{ @"k" : @"v" }];
    NSAttributedString *none = formatWithArguments(format, 0, nil, 1234567, 1234.5);
    expect([[none string] isEqualToString:@"1234567 / 1234.50"], [NSString stringWithFormat:@"nil locale is not localized: %@", [none string]]);

    NSAttributedString *us = formatWithArguments(format, 0, [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"], 1234567, 1234.5);
    expect([[us string] isEqualToString:@"1,234,567 / 1,234.50"], [NSString stringWithFormat:@"en_US numbers: %@", [us string]]);

    NSAttributedString *de = formatWithArguments(format, 0, [[NSLocale alloc] initWithLocaleIdentifier:@"de_DE"], 1234567, 1234.5);
    expect([[de string] isEqualToString:@"1.234.567 / 1.234,50"], [NSString stringWithFormat:@"de_DE numbers: %@", [de string]]);
    expect([attr(de, @"k", [[de string] length] - 1) isEqual:@"v"], @"localized replacements keep the format attributes to the end");

    NSAttributedString *current = [NSAttributedString localizedAttributedStringWithFormat:format, 1234567, 1234.5];
    NSAttributedString *expected = formatWithArguments(format, 0, [NSLocale currentLocale], 1234567, 1234.5);
    expect([current isEqualToAttributedString:expected], @"localizedAttributedStringWithFormat: uses the current locale");
    NSAttributedString *currentIndexed = [NSAttributedString localizedAttributedStringWithFormat:format options:NSAttributedStringFormattingApplyReplacementIndexAttribute, 1234567, 1234.5];
    expect([attr(currentIndexed, NSReplacementIndexAttributeName, 0) isEqual:@1], @"localizedAttributedStringWithFormat:options: applies options");
}

static void testVariadicAndMutable(void)
{
    NSAttributedString *format = [[NSAttributedString alloc] initWithString:@"<%@:%ld>" attributes:@{ @"k" : @1 }];
    NSAttributedString *s = [[NSAttributedString alloc] initWithFormat:format options:0 locale:nil, @"x", 7L];
    expect([[s string] isEqualToString:@"<x:7>"], [NSString stringWithFormat:@"variadic initializer: %@", [s string]]);

    NSMutableAttributedString *m = [[NSMutableAttributedString alloc] initWithFormat:format options:0 locale:nil, @"y", 8L];
    expect([m isKindOfClass:[NSMutableAttributedString class]], @"NSMutableAttributedString initializer returns a mutable string");
    [m appendLocalizedFormat:format, @"z", 9L];
    expect([[m string] isEqualToString:@"<y:8><z:9>"], [NSString stringWithFormat:@"appendLocalizedFormat: %@", [m string]]);
    expect([attr(m, @"k", 9) isEqual:@1], @"appended text keeps the format attributes");
}

static void testUnusableFormatRaises(void)
{
    NSAttributedString *format = [[NSAttributedString alloc] initWithString:@"%6$@"];
    BOOL raised = NO;
    @try
    {
        formatWithArguments(format, 0, nil, @"a");
    }
    @catch (NSException *e)
    {
        raised = [[e name] isEqualToString:NSInvalidArgumentException];
    }
    expect(raised, @"a format CoreFoundation cannot apply raises NSInvalidArgumentException");
}

int main(void)
{
    @autoreleasepool
    {
        testLiteralAndReplacementAttributes();
        testAttributedArgument();
        testPositionalAndReplacementIndex();
        testPercentLiteral();
        testLocale();
        testVariadicAndMutable();
        testUnusableFormatRaises();
    }
    if (failures)
    {
        NSLog(@"%d failure(s)", failures);
        return 1;
    }
    NSLog(@"PASS");
    return 0;
}
