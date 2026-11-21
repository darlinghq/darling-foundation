// The localizedStringFor... methods of NSLocale return the display name of a code in the receiver's language.
// Documented in the NSLocale reference (developer.apple.com/documentation/foundation/nslocale), where each method
// is stated to be equivalent to -displayNameForKey:value: with the matching key, with the en_US examples used below:
// "zh" -> "Chinese", "GB" -> "United Kingdom", "fr_FR" -> "French (France)", "Hant" -> "Traditional Han",
// "POSIX" -> "Computer", "phonebook" -> "Phonebook Sort Order", "JPY" -> "Japanese Yen".
// The collator identifier method has no documented example; on Darling it returns nil because CoreFoundation
// has no display name for that key, so its check below only pins the equivalence, not a value.
#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static BOOL same(NSString *a, NSString *b)
{
    return (a == nil && b == nil) || [a isEqualToString:b];
}

int main(void)
{
    @autoreleasepool
    {
        NSLocale *locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease];

        expect([[locale localizedStringForLanguageCode:@"zh"] isEqualToString:@"Chinese"], @"language code example");
        expect([[locale localizedStringForCountryCode:@"GB"] isEqualToString:@"United Kingdom"], @"country code example");
        expect([[locale localizedStringForLocaleIdentifier:@"fr_FR"] isEqualToString:@"French (France)"],
               @"locale identifier example");

        expect([[locale localizedStringForScriptCode:@"Hant"] isEqualToString:@"Traditional Han"], @"script example");
        expect([[locale localizedStringForVariantCode:@"POSIX"] isEqualToString:@"Computer"], @"variant example");
        expect([[locale localizedStringForCollationIdentifier:@"phonebook"] isEqualToString:@"Phonebook Sort Order"],
               @"collation example");
        expect([[locale localizedStringForCurrencyCode:@"JPY"] isEqualToString:@"Japanese Yen"], @"currency example");

        expect(same([locale localizedStringForLanguageCode:@"de"],
                    [locale displayNameForKey:NSLocaleLanguageCode value:@"de"]), @"language equivalence");
        expect(same([locale localizedStringForCountryCode:@"JP"],
                    [locale displayNameForKey:NSLocaleCountryCode value:@"JP"]), @"country equivalence");
        expect(same([locale localizedStringForScriptCode:@"Hant"],
                    [locale displayNameForKey:NSLocaleScriptCode value:@"Hant"]), @"script equivalence");
        expect(same([locale localizedStringForVariantCode:@"POSIX"],
                    [locale displayNameForKey:NSLocaleVariantCode value:@"POSIX"]), @"variant equivalence");
        expect(same([locale localizedStringForCollationIdentifier:@"phonebook"],
                    [locale displayNameForKey:NSLocaleCollationIdentifier value:@"phonebook"]), @"collation equivalence");
        expect(same([locale localizedStringForCurrencyCode:@"JPY"],
                    [locale displayNameForKey:NSLocaleCurrencyCode value:@"JPY"]), @"currency equivalence");
        expect(same([locale localizedStringForCollatorIdentifier:@"phonebook"],
                    [locale displayNameForKey:NSLocaleCollatorIdentifier value:@"phonebook"]), @"collator equivalence");

        NSLocale *french = [[[NSLocale alloc] initWithLocaleIdentifier:@"fr_FR"] autorelease];
        // Inference from "localized", not a documented value: a French locale must not answer in English.
        expect(![[french localizedStringForLanguageCode:@"zh"] isEqualToString:@"Chinese"], @"names follow the receiver's language");

        NSLocale *automatic = [NSLocale autoupdatingCurrentLocale];
        expect(same([automatic localizedStringForLanguageCode:@"zh"],
                    [automatic displayNameForKey:NSLocaleLanguageCode value:@"zh"]), @"autoupdating locale");

        NSLog(@"PASS: NSLocale display names");
    }
    return 0;
}
