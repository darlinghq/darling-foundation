# NSLocale countryCode

Build nslocale-countrycode.m against Foundation/CoreFoundation and run it under Darling. It checks `-[NSLocale countryCode]` against the public documentation: the region of `en_GB`, `fr_FR` and `zh_HK` (the documented examples "GB", "FR", "HK"), `en_US` and `de_DE`, nil for `en` (the page says only that the value is nullable), the value being the same as `-objectForKey:` with `NSLocaleCountryCode`, and that instances from `+localeWithLocaleIdentifier:`, `+currentLocale`, `+systemLocale` and `+autoupdatingCurrentLocale` respond to the selector. It also checks that `-languageCode` still returns the same value as `-objectForKey:` with `NSLocaleLanguageCode`.

Baseline: the test does not build against the headers of the base commit (no `-countryCode` declaration), and a build that skips the header check raises `unrecognized selector` from `__NSCFLocale` at the first call; candidate: zero failures.

The `en_US`, `de_DE`, `zh_Hant_HK`, `en_US_POSIX` and nil-for-no-region (`en`, `root`) cases are not stated on the documentation page; they are marked GUESS in the source.
