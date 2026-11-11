#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

int main(void)
{
    @autoreleasepool
    {
        NSNumberFormatter *formatter = [[[NSNumberFormatter alloc] init] autorelease];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;

        id value = nil;
        NSString *error = nil;
        BOOL ok = [formatter getObjectValue:&value forString:@"-2.5" errorDescription:&error];
        expect(ok && [value isKindOfClass:[NSNumber class]] && [value doubleValue] == -2.5,
               [NSString stringWithFormat:@"errorDescription variant parses -2.5 (%@)", value]);

        value = nil;
        ok = [formatter getObjectValue:&value forString:@"1,234" errorDescription:NULL];
        expect(ok && [value integerValue] == 1234, @"grouping separators parse");

        value = @"untouched";
        error = nil;
        ok = [formatter getObjectValue:&value forString:@"abc" errorDescription:&error];
        expect(!ok && [value isEqual:@"untouched"] && error.length > 0,
               [NSString stringWithFormat:@"non-numbers fail with a description (%@)", error]);

        ok = [formatter getObjectValue:&value forString:@"12abc" errorDescription:NULL];
        expect(!ok, @"errorDescription variant requires the whole string to parse");

        NSRange range = NSMakeRange(0, 5);
        NSError *nsError = nil;
        value = nil;
        ok = [formatter getObjectValue:&value forString:@"12abc" range:&range error:&nsError];
        expect(ok && [value integerValue] == 12 && range.location == 0 && range.length == 2,
               [NSString stringWithFormat:@"range variant reports the parsed prefix (%@, %@)", value, NSStringFromRange(range)]);

        range = NSMakeRange(4, 2);
        ok = [formatter getObjectValue:&value forString:@"abc 42 xyz" range:&range error:&nsError];
        expect(ok && [value integerValue] == 42, @"range variant parses inside the given range");

        nsError = nil;
        range = NSMakeRange(0, 3);
        ok = [formatter getObjectValue:&value forString:@"xyz" range:&range error:&nsError];
        expect(!ok && [nsError.domain isEqual:NSCocoaErrorDomain] && nsError.code == NSFormattingError,
               @"range variant fails with NSFormattingError");

        value = @"untouched";
        ok = [formatter getObjectValue:&value forString:@"" errorDescription:NULL];
        expect(ok && value == nil, @"the empty nil symbol gives nil");

        expect([[formatter stringForObjectValue:@1234] isEqual:@"1,234"] && [[formatter stringForObjectValue:nil] isEqual:@""] &&
                   [formatter stringForObjectValue:@"text"] == nil,
               [NSString stringWithFormat:@"stringForObjectValue: formats numbers (%@)", [formatter stringForObjectValue:@1234]]);

        BOOL raised = NO;
        @try
        {
            range = NSMakeRange(2, 5);
            [formatter getObjectValue:&value forString:@"123" range:&range error:NULL];
        }
        @catch (NSException *e)
        {
            raised = [e.name isEqual:NSRangeException];
        }
        expect(raised, @"a range past the end raises NSRangeException");

        formatter.allowsFloats = NO;
        ok = [formatter getObjectValue:&value forString:@"2.5" errorDescription:NULL];
        BOOL okInteger = [formatter getObjectValue:&value forString:@"7" errorDescription:NULL];
        expect(!ok && okInteger && [value integerValue] == 7, @"allowsFloats NO rejects fractions only");
        formatter.allowsFloats = YES;

        formatter.generatesDecimalNumbers = YES;
        ok = [formatter getObjectValue:&value forString:@"2.5" errorDescription:NULL];
        expect(ok && [value isKindOfClass:[NSDecimalNumber class]] && [value isEqual:[NSDecimalNumber decimalNumberWithString:@"2.5"]],
               [NSString stringWithFormat:@"generatesDecimalNumbers gives an NSDecimalNumber (%@ %@)", [value class], value]);
    }
    printf("failures=%d\n", failures);
    return failures != 0;
}
