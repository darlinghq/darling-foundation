// Copyright (C) 2026 Lubos Dolezel
//
// -[NSObject isLike:] and -[NSObject isCaseInsensitiveLike:] (NSComparisonMethods), documented at
// https://developer.apple.com/documentation/objectivec/nsobject-swift.class/islike(_:) and
// .../iscaseinsensitivelike(_:) : the NSObject default returns NO, NSString returns YES when the receiver matches
// the pattern given as the argument (the second form ignoring the case of the receiver's characters). The public
// NSScriptWhoseTests.h comment says the pattern uses simple shell wildcards, '*' and '?', and that the result is
// NO when the receiver is not an NSString (examples there: "Stev*" and "N?XT").
//
// The cases marked GUESS pin choices the documentation does not settle; they carry the same marker as in
// src/NSObject+NSComparisonMethods.m and need a macOS run to confirm.
#import <Foundation/Foundation.h>
#include <stdio.h>

// Darling's public NSScriptWhoseTests.h does not declare the NSComparisonMethods category (macOS declares it
// there); the test declares the two methods it calls so it builds either way.
@interface NSObject (IsLikeTestDeclaration)
- (BOOL)isLike:(NSString *)object;
- (BOOL)isCaseInsensitiveLike:(NSString *)object;
@end

static int failures;

static void expectBool(const char *label, BOOL actual, BOOL expected)
{
    BOOL ok = actual == expected;
    printf("%s: %s\n", ok ? "PASS" : "FAIL", label);
    if (!ok)
        failures++;
}

int main(void)
{
    @autoreleasepool {
        // The examples of the header comment.
        expectBool("Stev* matches Steve", [@"Steve" isLike:@"Stev*"], YES);
        expectBool("Stev* matches Stevenson", [@"Stevenson" isLike:@"Stev*"], YES);
        expectBool("Stev* matches Stev (star is a possibly empty run)", [@"Stev" isLike:@"Stev*"], YES);
        expectBool("Stev* does not match Ste", [@"Ste" isLike:@"Stev*"], NO);
        expectBool("N?XT matches NeXT", [@"NeXT" isLike:@"N?XT"], YES);
        expectBool("N?XT matches N3XT", [@"N3XT" isLike:@"N?XT"], YES);
        expectBool("N?XT does not match NXT (? is exactly one)", [@"NXT" isLike:@"N?XT"], NO);
        expectBool("N?XT does not match NeeXT", [@"NeeXT" isLike:@"N?XT"], NO);

        // The whole receiver has to match.
        expectBool("anchored at the start", [@"xSteve" isLike:@"Stev*"], NO);
        expectBool("anchored at the end", [@"NeXTx" isLike:@"N?XT"], NO);
        expectBool("no wildcard: equal strings", [@"abc" isLike:@"abc"], YES);
        expectBool("no wildcard: different strings", [@"abc" isLike:@"abd"], NO);

        // Star placement and backtracking.
        expectBool("star alone matches anything", [@"anything" isLike:@"*"], YES);
        expectBool("star alone matches the empty string", [@"" isLike:@"*"], YES);
        expectBool("empty pattern matches only the empty string", [@"" isLike:@""], YES);
        expectBool("empty pattern does not match text", [@"a" isLike:@""], NO);
        expectBool("question mark does not match the empty string", [@"" isLike:@"?"], NO);
        expectBool("leading star", [@"aab" isLike:@"*ab"], YES);
        expectBool("star in the middle backtracks", [@"abcabd" isLike:@"a*abd"], YES);
        expectBool("two stars", [@"xaybz" isLike:@"*a*b*"], YES);
        expectBool("adjacent stars", [@"abc" isLike:@"a**c"], YES);
        expectBool("star then question mark", [@"abc" isLike:@"*?"], YES);
        expectBool("star then missing tail", [@"abc" isLike:@"*d"], NO);

        // Case: isLike: is case sensitive, isCaseInsensitiveLike: ignores case.
        expectBool("isLike: is case sensitive", [@"next" isLike:@"N?XT"], NO);
        expectBool("isCaseInsensitiveLike: ignores case of the receiver", [@"next" isCaseInsensitiveLike:@"N?XT"], YES);
        expectBool("isCaseInsensitiveLike: ignores case of the pattern letters", [@"STEVE" isCaseInsensitiveLike:@"stev*"], YES);
        expectBool("isCaseInsensitiveLike: still anchored", [@"xsteve" isCaseInsensitiveLike:@"STEV*"], NO);
        expectBool("isCaseInsensitiveLike: wildcard-free mismatch", [@"abc" isCaseInsensitiveLike:@"ABD"], NO);

        // The NSObject default is NO for receivers that are not NSStrings.
        expectBool("NSNumber receiver isLike:", [@1 isLike:@"*"], NO);
        expectBool("NSArray receiver isLike:", [@[@"a"] isLike:@"*"], NO);
        expectBool("NSObject receiver isLike:", [[NSObject new] isLike:@"*"], NO);
        expectBool("NSNumber receiver isCaseInsensitiveLike:", [@1 isCaseInsensitiveLike:@"*"], NO);
        expectBool("NSObject receiver isCaseInsensitiveLike:", [[NSObject new] isCaseInsensitiveLike:@"*"], NO);

        // GUESS: a mutable string and a nil or non-string pattern.
        expectBool("mutable string receiver", [[NSMutableString stringWithString:@"Steve"] isLike:@"Stev*"], YES);
        expectBool("GUESS: nil pattern gives NO", [@"a" isLike:nil], NO);
        expectBool("GUESS: nil pattern gives NO (case-insensitive)", [@"a" isCaseInsensitiveLike:nil], NO);
        expectBool("GUESS: non-string pattern gives NO", [@"a" isLike:(NSString *)@1], NO);

        // GUESS: other characters match literally; there are no character classes and no escape.
        expectBool("GUESS: brackets are literal", [@"[ab]" isLike:@"[ab]"], YES);
        expectBool("GUESS: brackets are not a class", [@"a" isLike:@"[ab]"], NO);
        expectBool("GUESS: backslash is literal", [@"a\\b" isLike:@"a\\b"], YES);
        expectBool("GUESS: backslash does not escape a star", [@"a*" isLike:@"a\\*"], NO);
        expectBool("GUESS: a literal star in the receiver matches the star wildcard", [@"a*" isLike:@"a*"], YES);

        // GUESS: a character is a composed character sequence.
        expectBool("GUESS: ? matches a letter with its combining accent", [@"é" isLike:@"?"], YES);
        expectBool("GUESS: ? matches a surrogate pair", [@"\U0001F600" isLike:@"?"], YES);
        expectBool("GUESS: ? matches one sequence in a longer string", [@"áb" isLike:@"?b"], YES);
        expectBool("GUESS: precomposed and decomposed spellings differ", [@"é" isLike:@"é"], NO);
    }
    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures ? 1 : 0;
}
