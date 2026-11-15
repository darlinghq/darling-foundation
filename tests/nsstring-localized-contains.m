// Copyright (C) 2026 Lubos Dolezel
//
// NSString locale-aware searching and case mapping: -localizedCaseInsensitiveContainsString:,
// -localizedStandardContainsString:, -localizedStandardRangeOfString: and the localized
// upper/lower/capitalized properties. Expected values were observed on macOS (see the
// notes in the commit); the same program is an oracle on a real Mac.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expectTrue(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

static void expectRange(const char *label, NSRange got, NSUInteger loc, NSUInteger len)
{
    BOOL ok = got.location == loc && (loc == NSNotFound || got.length == len);
    printf("%s %s ({%lu,%lu})\n", ok ? "PASS" : "FAIL", label,
           (unsigned long)(got.location == NSNotFound ? (NSUInteger)-1 : got.location), (unsigned long)got.length);
    failures += !ok;
}

int main(void)
{
    @autoreleasepool {
        NSString *s = @"Résumé Café Straße";

        // localizedCaseInsensitiveContainsString: ignores case but not diacritics
        expectTrue("ci contains exact accented, other case", [s localizedCaseInsensitiveContainsString:@"RÉSUMÉ"]);
        expectTrue("ci contains unaccented does not match accented", ![s localizedCaseInsensitiveContainsString:@"resume"]);
        expectTrue("ci contains accented lower", [s localizedCaseInsensitiveContainsString:@"café"]);
        expectTrue("ci contains ascii different case", [@"abc" localizedCaseInsensitiveContainsString:@"B"]);
        expectTrue("ci contains whole string", [@"abc" localizedCaseInsensitiveContainsString:@"ABC"]);
        expectTrue("ci contains longer needle", ![@"abc" localizedCaseInsensitiveContainsString:@"abcd"]);
        expectTrue("ci contains empty receiver", ![@"" localizedCaseInsensitiveContainsString:@"a"]);
        expectTrue("ci contains empty needle is NO", ![s localizedCaseInsensitiveContainsString:@""]);
        expectTrue("containsString: empty needle is NO", ![s containsString:@""]);

        // localizedStandardContainsString: ignores case and diacritics
        expectTrue("standard contains unaccented", [s localizedStandardContainsString:@"resume"]);
        expectTrue("standard contains upper unaccented", [s localizedStandardContainsString:@"CAFE"]);
        expectTrue("standard contains empty needle is NO", ![s localizedStandardContainsString:@""]);
        expectTrue("standard contains absent", ![s localizedStandardContainsString:@"zzz"]);

        // localizedStandardRangeOfString:
        expectRange("standard range cafe", [s localizedStandardRangeOfString:@"cafe"], 7, 4);
        expectRange("standard range RESUME", [s localizedStandardRangeOfString:@"RESUME"], 0, 6);
        expectRange("standard range absent", [s localizedStandardRangeOfString:@"zzz"], NSNotFound, 0);
        expectRange("standard range empty needle", [s localizedStandardRangeOfString:@""], NSNotFound, 0);
        // a match never ends inside a composed character sequence
        expectRange("standard range covers combining mark", [@"áb" localizedStandardRangeOfString:@"a"], 0, 2);
        expectRange("standard range after combining mark", [@"áb" localizedStandardRangeOfString:@"b"], 2, 1);

        // locale-aware search with an explicit locale
        expectRange("rangeOfString:options:range:locale:",
                   [@"Hello" rangeOfString:@"ELL" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 5)
                                     locale:[NSLocale currentLocale]], 1, 3);

        // localized case mapping
        expectTrue("localizedUppercaseString", [[@"hello world" localizedUppercaseString] isEqualToString:@"HELLO WORLD"]);
        expectTrue("localizedLowercaseString", [[@"HELLO World" localizedLowercaseString] isEqualToString:@"hello world"]);
        expectTrue("localizedCapitalizedString", [[@"hello world" localizedCapitalizedString] isEqualToString:@"Hello World"]);
    }
    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures ? 1 : 0;
}
