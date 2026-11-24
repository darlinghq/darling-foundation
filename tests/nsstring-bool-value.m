// Copyright (C) 2026 Lubos Dolezel
//
// -[NSString boolValue], documented at https://developer.apple.com/documentation/foundation/nsstring/boolvalue :
// the result is YES when the first character, after whitespace and after an optional sign followed by zeroes,
// is one of Y, y, T, t or a digit 1 to 9, whatever follows it; it is NO for a string that does not begin with a
// number in decimal text. The initial characters skipped are those of the whitespace character set (the public
// macOS 10.15 SDK header Foundation/NSString.h), so a newline is not skipped. The cases that neither the page nor
// the header settle are marked GUESS in src/NSString.m and here: a sign before a non-zero digit, and a letter
// after skipped zeroes.
// The old code answered NO for "Y", "T" and "Tuesday", and compared the receiver with "YES" and "TRUE" over a fixed
// range of 3 and 4 characters, which runs past the end of "NO", "0" and "no"; the short strings guard against that.
// Not yet run in a Darling guest. Built without ARC.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expectBool(NSString *input, BOOL expected)
{
    BOOL actual = NO;
    NSString *raised = nil;
    @try {
        actual = [input boolValue];
    } @catch (NSException *exception) {
        raised = [exception name];
    }
    BOOL ok = raised == nil && actual == expected;
    printf("%s: boolValue of \"%s\" is %s%s%s\n", ok ? "PASS" : "FAIL", [[input description] UTF8String],
           expected ? "YES" : "NO", raised ? ", raised " : "", raised ? [raised UTF8String] : "");
    if (!ok)
        failures++;
}

int main(void)
{
    @autoreleasepool {
        // Short strings: nothing may be read past the end.
        expectBool(@"", NO);
        expectBool(@"N", NO);
        expectBool(@"NO", NO);
        expectBool(@"no", NO);
        expectBool(@"0", NO);
        expectBool(@"Y", YES);
        expectBool(@"y", YES);
        expectBool(@"T", YES);
        expectBool(@"t", YES);
        expectBool(@"1", YES);

        // The first character decides; what follows is ignored.
        expectBool(@"YES", YES);
        expectBool(@"yes", YES);
        expectBool(@"true", YES);
        expectBool(@"Tuesday", YES);
        expectBool(@"9", YES);
        expectBool(@"5 apples", YES);
        expectBool(@"1abc", YES);
        expectBool(@"false", NO);
        expectBool(@"x", NO);
        expectBool(@"-", NO);
        expectBool(@" ", NO);

        // Leading zeroes are skipped, also after a sign.
        expectBool(@"00012", YES);
        expectBool(@"000", NO);
        expectBool(@"-0", NO);
        expectBool(@"+000", NO);
        expectBool(@"+01", YES);

        // Whitespace at the start is skipped.
        expectBool(@"  YES", YES);
        expectBool(@"\t1", YES);
        expectBool(@"  0", NO);
        expectBool(@"   ", NO);
        expectBool(@"  00012", YES);
        expectBool(@"  N", NO);

        // A newline is not whitespace here (the header names the whitespace set).
        expectBool(@"\n1", NO);

        // GUESS (neither the page nor the header settle these).
        expectBool(@"-5", YES);    // a sign is skipped before a non-zero digit as well
        expectBool(@"0Y", YES);    // a letter counts after skipped zeroes
    }
    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures ? 1 : 0;
}
