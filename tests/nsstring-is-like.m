// Copyright (C) 2026 Lubos Dolezel
//
// -[NSObject isLike:] and -[NSObject isCaseInsensitiveLike:] (NSComparisonMethods), documented at
// https://developer.apple.com/documentation/objectivec/nsobject-swift.class/islike(_:) and
// .../iscaseinsensitivelike(_:) : the NSObject default returns NO, NSString returns YES when the receiver matches
// the pattern given as the argument (the second form ignoring the case of the receiver's characters). The public
// NSScriptWhoseTests.h comment says the pattern uses simple shell wildcards, '*' and '?', and that the result is
// NO when the receiver is not an NSString (examples there: "Stev*" and "N?XT").
//
// The cases under the QUIRK headings pin behaviour the documentation does not give (character classes, the
// backslash escape, UTF-16 units as the matching unit, exceptions for malformed or non-string patterns); it was
// observed on macOS 26.7.3 and 10.14.4 and the whole file passes on both.
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

static void expectRaises(const char *label, NSString *name, void (^block)(void))
{
    NSString *raised = nil;
    @try {
        block();
    } @catch (NSException *exception) {
        raised = exception.name;
    }
    BOOL ok = [raised isEqualToString:name];
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

        expectBool("mutable string receiver", [[NSMutableString stringWithString:@"Steve"] isLike:@"Stev*"], YES);
        expectBool("mutable string pattern", [@"a" isLike:[NSMutableString stringWithString:@"a"]], YES);
        expectBool("nil pattern gives NO", [@"a" isLike:nil], NO);
        expectBool("nil pattern gives NO (case-insensitive)", [@"a" isCaseInsensitiveLike:nil], NO);
        expectBool("star matches a newline", [@"a\nb" isLike:@"a*b"], YES);
        expectBool("question mark matches a newline", [@"a\nb" isLike:@"a?b"], YES);
        expectBool("dot, plus and parentheses are literal", [@"a.b+(c)" isLike:@"a.b+(c)"], YES);
        expectBool("dot is not a wildcard", [@"axb" isLike:@"a.b"], NO);

        // QUIRK tests: behaviour observed on macOS 26.7.3 and 10.14.4 that the documentation does not give; each
        // comment names the observation. See the QUIRK comment in src/NSObject+NSComparisonMethods.m.
        // test_quirk_islike_non_string_pattern_raises
        expectRaises("non-string pattern raises NSInvalidArgumentException", NSInvalidArgumentException, ^{ [@"a" isLike:(NSString *)@1]; });
        expectRaises("null pattern object raises NSInvalidArgumentException", NSInvalidArgumentException, ^{ [@"a" isLike:(NSString *)[NSNull null]]; });

        // test_quirk_islike_character_classes
        expectBool("class: member", [@"b" isLike:@"[abc]"], YES);
        expectBool("class: non-member", [@"d" isLike:@"[abc]"], NO);
        expectBool("class matches one unit only", [@"ab" isLike:@"[ab]"], NO);
        expectBool("class: range", [@"c" isLike:@"[a-c]"], YES);
        expectBool("class: outside the range", [@"d" isLike:@"[a-c]"], NO);
        expectBool("class: two ranges", [@"y" isLike:@"[a-cx-z]"], YES);
        expectBool("class: between two ranges", [@"m" isLike:@"[a-cx-z]"], NO);
        expectBool("class: reversed range matches nothing", [@"b" isLike:@"[c-a]"], NO);
        expectBool("class: trailing dash is a member", [@"-" isLike:@"[a-]"], YES);
        expectBool("class: trailing dash leaves the letter a member", [@"a" isLike:@"[a-]"], YES);
        expectBool("class: leading dash is a member", [@"-" isLike:@"[-a]"], YES);
        expectBool("class: only a dash", [@"-" isLike:@"[-]"], YES);
        expectBool("class: no negation with ! (the ! is a member)", [@"!" isLike:@"[!b]"], YES);
        expectBool("class: no negation with !", [@"a" isLike:@"[!b]"], NO);
        expectBool("class: no negation with ^ (the ^ is a member)", [@"^" isLike:@"[^b]"], YES);
        expectBool("class: no negation with ^", [@"a" isLike:@"[^b]"], NO);
        expectBool("class: wildcards are literal members", [@"*" isLike:@"[*]"], YES);
        expectBool("class: wildcards are literal members (?)", [@"x" isLike:@"[?]"], NO);
        expectBool("class: empty class matches nothing", [@"a" isLike:@"[]"], NO);
        expectBool("class: closes at the first ]", [@"a]" isLike:@"[a]]"], YES);
        expectBool("class: followed by star", [@"axyz" isLike:@"[a]*"], YES);
        expectBool("class: needs a unit", [@"" isLike:@"[a]*"], NO);
        expectBool("class: escaped ] is a member", [@"]" isLike:@"[\\]]"], YES);
        expectBool("class: escaped ] is not closing", [@"a" isLike:@"[\\]]"], NO);
        expectBool("class: escaped backslash", [@"\\" isLike:@"[\\\\]"], YES);
        expectBool("class: escaped dash is a member", [@"-" isLike:@"[a\\-c]"], YES);
        expectBool("class: a ] outside a class is itself", [@"]" isLike:@"]"], YES);
        expectBool("class: POSIX names are not special", [@"a" isLike:@"[[:alpha:]]"], NO);
        expectBool("class: Latin-1 range", [@"\u00e9" isLike:@"[\u00e0-\u00ff]"], YES);
        expectRaises("class: not closed raises", NSInternalInconsistencyException, ^{ [@"a" isLike:@"[a"]; });
        expectRaises("class: range without end raises", NSInternalInconsistencyException, ^{ [@"a" isLike:@"[a-"]; });
        expectBool("class: an unclosed class after a failed match is not reached", [@"b" isLike:@"a["], NO);

        // test_quirk_islike_backslash_escape
        expectBool("escape: backslash makes a star ordinary", [@"a*" isLike:@"a\\*"], YES);
        expectBool("escape: an escaped star does not match other text", [@"ab" isLike:@"a\\*"], NO);
        expectBool("escape: backslash makes a question mark ordinary", [@"?" isLike:@"\\?"], YES);
        expectBool("escape: an escaped question mark does not match other text", [@"x" isLike:@"\\?"], NO);
        expectBool("escape: escaped backslash", [@"\\x" isLike:@"\\\\x"], YES);
        expectBool("escape: of an ordinary character", [@"ab" isLike:@"a\\b"], YES);
        expectBool("escape: of a bracket", [@"[" isLike:@"\\["], YES);
        expectBool("escape: the backslash itself is not matched literally", [@"a\\b" isLike:@"a\\b"], NO);
        expectBool("escape: a trailing backslash matches nothing", [@"a\\" isLike:@"a\\"], NO);
        expectBool("escape: a lone backslash matches nothing", [@"\\" isLike:@"\\"], NO);

        // test_quirk_islike_matching_unit_is_a_utf16_unit
        expectBool("unit: precomposed letter is one unit", [@"\u00e9" isLike:@"?"], YES);
        expectBool("unit: decomposed letter is two units, not matched by ?", [@"e\u0301" isLike:@"?"], NO);
        expectBool("unit: decomposed letter is matched by ??", [@"e\u0301" isLike:@"??"], YES);
        expectBool("unit: decomposed letter after its base", [@"e\u0301" isLike:@"e?"], YES);
        expectBool("unit: surrogate pair is not matched by ?", [@"\U0001F600" isLike:@"?"], NO);
        expectBool("unit: surrogate pair is matched by ??", [@"\U0001F600" isLike:@"??"], YES);
        expectBool("unit: star spans a surrogate pair", [@"x\U0001F600" isLike:@"x*"], YES);
        expectBool("unit: precomposed and decomposed spellings differ", [@"\u00e9" isLike:@"e\u0301"], NO);
        expectBool("unit: precomposed matches itself", [@"\u00e9" isLike:@"\u00e9"], YES);

        // test_quirk_islike_case_insensitive_classes
        expectBool("ci: literal units fold on both sides", [@"\u00c9COLE" isCaseInsensitiveLike:@"\u00e9cole"], YES);
        expectBool("ci: accents are significant", [@"\u00c9" isCaseInsensitiveLike:@"e*"], NO);
        expectBool("ci: class members are lowercased, receiver unit compared as is (lowercase receiver)", [@"b" isCaseInsensitiveLike:@"[A-C]"], YES);
        expectBool("ci: class members are lowercased, receiver unit compared as is (uppercase receiver)", [@"B" isCaseInsensitiveLike:@"[A-C]"], NO);
        expectBool("ci: lowercase class, lowercase receiver", [@"b" isCaseInsensitiveLike:@"[a-c]"], YES);
        expectBool("ci: lowercase class, uppercase receiver", [@"B" isCaseInsensitiveLike:@"[a-c]"], NO);
        expectBool("ci: uppercase member, uppercase receiver", [@"B" isCaseInsensitiveLike:@"[B]"], NO);
        expectBool("ci: uppercase member, lowercase receiver", [@"b" isCaseInsensitiveLike:@"[B]"], YES);
    }
    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures ? 1 : 0;
}
