// Copyright (C) 2026 Lubos Dolezel
//
// -[NSString boolValue], documented at https://developer.apple.com/documentation/foundation/nsstring/boolvalue :
// the result is YES when the first character, after whitespace and after an optional sign followed by zeroes,
// is one of Y, y, T, t or a digit 1 to 9, whatever follows it; it is NO for a string that does not begin with a
// number in decimal text. The initial characters skipped are those of the whitespace character set (the public
// macOS 10.15 SDK header Foundation/NSString.h), so a newline is not skipped. The cases that neither the page nor
// the header settle were observed on macOS 26.7.3 and 10.14.4 (x86_64 and i386, identical; see src/NSString.m): a sign
// before a non-zero digit is skipped, and a letter after a sign or after zeroes gives NO.
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

        // Observed on macOS 26.7.3 and 10.14.4 (the page does not settle these).
        expectBool(@"-5", YES);    // a sign is skipped before a non-zero digit as well
        expectBool(@"+5", YES);
        expectBool(@"01", YES);
        expectBool(@"0Y", NO);     // a letter does not count after zeroes ...
        expectBool(@"00t", NO);
        expectBool(@"-Y", NO);     // ... nor after a sign
        expectBool(@"+T", NO);
        expectBool(@"--1", NO);    // only one sign is skipped
        expectBool(@"0 1", NO);
        expectBool(@"0.5", NO);
        expectBool(@"\u00A01", YES);  // the whitespace character set includes the Unicode space separators
        expectBool(@"\u30001", YES);
        expectBool(@"\r1", NO);       // and does not include carriage return, vertical tab or form feed
        expectBool(@"\v1", NO);
        expectBool(@"\f1", NO);
    }
    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures ? 1 : 0;
}
