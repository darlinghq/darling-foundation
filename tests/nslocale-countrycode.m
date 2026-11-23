// -[NSLocale countryCode] is documented (developer.apple.com/documentation/foundation/nslocale/countrycode) as the
// country or region code of the locale, a nullable string, available since macOS 10.12, and as holding the same value
// that -objectForKey: returns for NSLocaleCountryCode. The page gives "GB", "FR" and "HK" as examples; the en_US and
// de_DE pairs and the nil case for an identifier without a region are not on the page (see the GUESS comments).
// The sibling -languageCode is documented the same way and is checked here so that adding the new method does not
// disturb it.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void report(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

static BOOL same(NSString *a, NSString *b)
{
    return (a == nil && b == nil) || [a isEqualToString:b];
}

int main(void)
{
    @autoreleasepool
    {
        // The three codes the documentation page uses as examples.
        report("en_GB -> GB", [[[NSLocale localeWithLocaleIdentifier:@"en_GB"] countryCode] isEqualToString:@"GB"]);
        report("fr_FR -> FR", [[[NSLocale localeWithLocaleIdentifier:@"fr_FR"] countryCode] isEqualToString:@"FR"]);
        report("zh_HK -> HK", [[[NSLocale localeWithLocaleIdentifier:@"zh_HK"] countryCode] isEqualToString:@"HK"]);

        // GUESS: the page lists no value for these identifiers; the region part of the identifier is the obvious reading.
        report("en_US -> US", [[[NSLocale localeWithLocaleIdentifier:@"en_US"] countryCode] isEqualToString:@"US"]);
        report("de_DE -> DE", [[[NSLocale localeWithLocaleIdentifier:@"de_DE"] countryCode] isEqualToString:@"DE"]);

        // GUESS: the page only says the type is nullable, not when nil is returned; no region in the identifier is the
        // natural case (the neighbouring regionCode page says nil when the identifier has no region).
        report("en (no region) -> nil", [[NSLocale localeWithLocaleIdentifier:@"en"] countryCode] == nil);

        // GUESS: not on the page. Read from the CoreFoundation components code, where the country is whatever ICU's
        // uloc_getCountry finds in the identifier: a script or variant part does not change it, "root" has none.
        report("zh_Hant_HK -> HK", [[[NSLocale localeWithLocaleIdentifier:@"zh_Hant_HK"] countryCode] isEqualToString:@"HK"]);
        report("en_US_POSIX -> US", [[[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"] countryCode] isEqualToString:@"US"]);
        report("root (no region) -> nil", [[NSLocale localeWithLocaleIdentifier:@"root"] countryCode] == nil);

        // Documented: the same value as -objectForKey: with NSLocaleCountryCode, including nil.
        NSArray<NSString *> *identifiers = @[ @"en_US", @"de_DE", @"zh_HK", @"en" ];
        BOOL consistent = YES;
        for (NSString *identifier in identifiers)
        {
            NSLocale *locale = [NSLocale localeWithLocaleIdentifier:identifier];
            consistent = consistent && same([locale countryCode], [locale objectForKey:NSLocaleCountryCode]);
        }
        report("countryCode equals objectForKey:NSLocaleCountryCode", consistent);

        // The property declaration: dot syntax compiles and gives the same value.
        NSLocale *gb = [NSLocale localeWithLocaleIdentifier:@"en_GB"];
        report("dot syntax gives the same value", same(gb.countryCode, [gb countryCode]));

        // Every kind of instance reaches the method, whichever concrete class backs it.
        NSLocale *current = [NSLocale currentLocale];
        NSLocale *system = [NSLocale systemLocale];
        NSLocale *autoupdating = [NSLocale autoupdatingCurrentLocale];
        report("+localeWithLocaleIdentifier: instance responds", [gb respondsToSelector:@selector(countryCode)]);
        report("+currentLocale instance responds", [current respondsToSelector:@selector(countryCode)]);
        report("+systemLocale instance responds", [system respondsToSelector:@selector(countryCode)]);
        report("+autoupdatingCurrentLocale instance responds", [autoupdating respondsToSelector:@selector(countryCode)]);
        report("NSLocale instances respond", [NSLocale instancesRespondToSelector:@selector(countryCode)]);

        // Calling it on the shared locales matches -objectForKey: and returns a string when there is a value.
        report("+currentLocale countryCode equals objectForKey:",
               same([current countryCode], [current objectForKey:NSLocaleCountryCode]));
        report("+systemLocale countryCode equals objectForKey:",
               same([system countryCode], [system objectForKey:NSLocaleCountryCode]));
        report("+autoupdatingCurrentLocale countryCode equals objectForKey:",
               same([autoupdating countryCode], [autoupdating objectForKey:NSLocaleCountryCode]));
        id currentCode = [current countryCode];
        report("+currentLocale countryCode is nil or a string", currentCode == nil || [currentCode isKindOfClass:[NSString class]]);

        // The sibling still works (documented examples are "en", "es" and "zh").
        report("-languageCode en_US -> en", [[[NSLocale localeWithLocaleIdentifier:@"en_US"] languageCode] isEqualToString:@"en"]);
        report("-languageCode zh_HK -> zh", [[[NSLocale localeWithLocaleIdentifier:@"zh_HK"] languageCode] isEqualToString:@"zh"]);
        report("-languageCode equals objectForKey:NSLocaleLanguageCode",
               same([gb languageCode], [gb objectForKey:NSLocaleLanguageCode]));
    }
    return failures != 0;
}
