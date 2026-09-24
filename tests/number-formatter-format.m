// NSNumberFormatter format / positiveFormat / negativeFormat: one, two and three
// pattern forms, quoted semicolons, the zero pattern versus an explicit zeroSymbol,
// and the error for more than three patterns. Exits non-zero on failure.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures = 0;

static void expect(NSString *what, NSString *got, NSString *want)
{
    if (!(got == want || [got isEqualToString:want]))
    {
        printf("FAIL %s: got \"%s\", want \"%s\"\n", [what UTF8String], got ? [got UTF8String] : "(nil)", want ? [want UTF8String] : "(nil)");
        failures++;
    }
}

static NSNumberFormatter *posixFormatter(void)
{
    NSNumberFormatter *f = [[[NSNumberFormatter alloc] init] autorelease];
    [f setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    return f;
}

int main(void)
{
    @autoreleasepool {
        NSNumberFormatter *f = posixFormatter();
        [f setFormat:@"0.00"];
        expect(@"single positiveFormat", [f positiveFormat], @"0.00");
        expect(@"single negativeFormat", [f negativeFormat], @"-0.00");
        expect(@"single format", [f format], @"0.00;-0.00");
        expect(@"single positive", [f stringFromNumber:@1.5], @"1.50");
        expect(@"single zero", [f stringFromNumber:@0], @"0.00");
        expect(@"single negative", [f stringFromNumber:@-1.5], @"-1.50");

        f = posixFormatter();
        [f setFormat:@"#,##0.00;(#,##0.00)"];
        expect(@"two format", [f format], @"#,##0.00;(#,##0.00)");
        expect(@"two negativeFormat", [f negativeFormat], @"(#,##0.00)");
        expect(@"two positive", [f stringFromNumber:@1234.5], @"1,234.50");
        expect(@"two negative", [f stringFromNumber:@-1234.5], @"(1,234.50)");

        f = posixFormatter();
        [f setFormat:@"0.0;'none';-0.0"];
        expect(@"three format", [f format], @"0.0;'none';-0.0");
        expect(@"three negativeFormat", [f negativeFormat], @"-0.0");
        expect(@"three positive", [f stringFromNumber:@2], @"2.0");
        expect(@"three zero", [f stringFromNumber:@0], @"none");
        expect(@"three negative", [f stringFromNumber:@-2], @"-2.0");
        expect(@"zero pattern leaves zeroSymbol unset", [f zeroSymbol], nil);
        [f setFormat:@"0.0;'it''s zero';-0.0"];
        expect(@"quoted apostrophe in zero", [f stringFromNumber:@0], @"it's zero");
        [f setZeroSymbol:@"nothing"];
        expect(@"explicit zeroSymbol wins", [f stringFromNumber:@0], @"nothing");
        expect(@"explicit zeroSymbol reads back", [f zeroSymbol], @"nothing");
        [f setZeroSymbol:nil];
        expect(@"cleared zeroSymbol restores zero pattern", [f stringFromNumber:@0], @"it's zero");

        f = posixFormatter();
        [f setFormat:@"0.00;'none';(0.00)"];
        [f setNumberStyle:NSNumberFormatterDecimalStyle];
        expect(@"numberStyle replaces the format", [f stringFromNumber:@-1234.5], @"-1234.5");
        expect(@"numberStyle drops the zero pattern", [f stringFromNumber:@0], @"0");

        f = posixFormatter();
        [f setFormat:@"0.0;0.000;-0.0"];
        expect(@"zero pattern with digits", [f stringFromNumber:@0], @"0.000");
        [f setFormat:@"0.0"];
        expect(@"single format clears zero pattern", [f stringFromNumber:@0], @"0.0");
        expect(@"single format after three", [f format], @"0.0;-0.0");

        // The formats Activity Monitor sets.
        f = posixFormatter();
        [f setFormat:@"+#,##0.0;0.0;-#,##0.0"];
        expect(@"signed positive", [f stringFromNumber:@1234.56], @"+1,234.6");
        expect(@"signed zero", [f stringFromNumber:@0], @"0.0");
        expect(@"signed negative", [f stringFromNumber:@-1234.56], @"-1,234.6");
        expect(@"signed format", [f format], @"+#,##0.0;0.0;-#,##0.0");

        f = posixFormatter();
        [f setFormat:@"0' ;x'"];
        expect(@"quoted semicolon positiveFormat", [f positiveFormat], @"0' ;x'");
        expect(@"quoted semicolon output", [f stringFromNumber:@5], @"5 ;x");

        f = posixFormatter();
        [f setPositiveFormat:@"0.000"];
        expect(@"positiveFormat alone", [f stringFromNumber:@1], @"1.000");
        [f setNegativeFormat:@"0.000-"];
        expect(@"negativeFormat alone", [f stringFromNumber:@-1], @"1.000-");
        expect(@"positive after negativeFormat", [f stringFromNumber:@1], @"1.000");

        BOOL raised = NO;
        @try {
            [posixFormatter() setFormat:@"0;0;0;0"];
        } @catch (NSException *e) {
            raised = [[e name] isEqualToString:NSInvalidArgumentException];
        }
        if (!raised)
        {
            printf("FAIL four patterns did not raise NSInvalidArgumentException\n");
            failures++;
        }
    }
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
