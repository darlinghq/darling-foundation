// Copyright (C) 2026 Lubos Dolezel
//
// NSNumberFormatter's minimum and maximum, as observed on macOS 26.7.3 (black-box): both are nil
// by default, the setters keep the number and a copy of the formatter keeps them, and a number
// outside them is not accepted: -getObjectValue:forString:... returns NO with an NSFormattingError
// ("The value 3 is too small." / "... is too large.", the number in the decimal style of the
// current locale) and -numberFromString: returns nil. The minimum is checked first.
//
// Build: clang -framework Foundation numberformatter-minimum-maximum.m
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static NSString *expected(NSNumber *n, NSString *kind) {
    return [NSString stringWithFormat: @"The value %@ is too %@.",
            [NSNumberFormatter localizedStringFromNumber: n numberStyle: NSNumberFormatterDecimalStyle], kind];
}

int main(void) {
    @autoreleasepool {
        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
        [f setLocale: [NSLocale localeWithLocaleIdentifier: @"en_US"]];
        CHECK([f minimum] == nil && [f maximum] == nil);

        [f setMinimum: @5];
        [f setMaximum: @10];
        CHECK([[f minimum] isEqual: @5] && [[f maximum] isEqual: @10]);
        NSNumberFormatter *copy = [f copy];
        CHECK([[copy minimum] isEqual: @5] && [[copy maximum] isEqual: @10]);

        id value = nil;
        NSString *description = nil;
        CHECK([f getObjectValue: &value forString: @"7" errorDescription: &description]);
        CHECK([value isEqual: @7] && description == nil);
        CHECK([[f numberFromString: @"10"] isEqual: @10]);
        CHECK([[f numberFromString: @"5"] isEqual: @5]);

        value = nil;
        CHECK(![f getObjectValue: &value forString: @"3" errorDescription: &description]);
        CHECK(value == nil && [description isEqualToString: expected(@3, @"small")]);
        CHECK(![f getObjectValue: &value forString: @"12" errorDescription: &description]);
        CHECK(value == nil && [description isEqualToString: expected(@12, @"large")]);

        NSError *error = nil;
        NSRange range = NSMakeRange(0, 1);
        CHECK(![f getObjectValue: &value forString: @"3" range: &range error: &error]);
        CHECK([[error domain] isEqualToString: NSCocoaErrorDomain] && [error code] == NSFormattingError);
        CHECK([[error localizedDescription] isEqualToString: expected(@3, @"small")]);
        CHECK([f numberFromString: @"3"] == nil && [f numberFromString: @"12"] == nil);
        CHECK([copy numberFromString: @"3"] == nil);

        // a fractional minimum, and a maximum below it: below both is too small
        [f setMinimum: [NSDecimalNumber decimalNumberWithString: @"2.5"]];
        CHECK(![f getObjectValue: &value forString: @"2.4" errorDescription: &description]);
        CHECK([description isEqualToString: expected(@2.4, @"small")]);
        [f setMaximum: @1];
        CHECK(![f getObjectValue: &value forString: @"0" errorDescription: &description]);
        CHECK([description isEqualToString: expected(@0, @"small")]);
        CHECK(![f getObjectValue: &value forString: @"3" errorDescription: &description]);
        CHECK([description isEqualToString: expected(@3, @"large")]);

        // nil removes a limit
        [f setMinimum: nil];
        [f setMaximum: nil];
        CHECK([f minimum] == nil && [f maximum] == nil);
        CHECK([[f numberFromString: @"3"] isEqual: @3]);
        CHECK([f getObjectValue: &value forString: @"12" errorDescription: &description] && [value isEqual: @12]);
    }
    if (failures)
        return 1;
    printf("PASS\n");
    return 0;
}
