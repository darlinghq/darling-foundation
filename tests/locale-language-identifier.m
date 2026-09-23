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

int main(void)
{
    @autoreleasepool
    {
        NSLocale *english = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US@rg=gbzzzz"] autorelease];
        NSLog(@"english locale %@ -> language %@", english.localeIdentifier, english.languageIdentifier);
        expect([[english languageIdentifier] isEqualToString:@"en-US"], @"region override must not change language identifier");

        NSLocale *chinese = [[[NSLocale alloc] initWithLocaleIdentifier:@"zh_Hant_TW"] autorelease];
        NSLog(@"chinese locale %@ -> language %@", chinese.localeIdentifier, chinese.languageIdentifier);
        expect([[chinese languageIdentifier] isEqualToString:@"zh-Hant"], @"canonical Chinese script identifier");

        NSLocale *autoLocale = [NSLocale autoupdatingCurrentLocale];
        NSLocale *currentLocale = [NSLocale currentLocale];
        NSLog(@"current locale %@ -> language %@; auto locale %@ -> language %@",
              currentLocale.localeIdentifier, currentLocale.languageIdentifier,
              autoLocale.localeIdentifier, autoLocale.languageIdentifier);
        NSString *currentLanguage = currentLocale.languageIdentifier;
        NSString *automaticLanguage = autoLocale.languageIdentifier;
        expect((currentLanguage == nil && automaticLanguage == nil) ||
               [automaticLanguage isEqualToString:currentLanguage], @"autoupdating locale follows current locale");
        NSLog(@"PASS: language identifiers %@, %@, %@", english.languageIdentifier,
              chinese.languageIdentifier, autoLocale.languageIdentifier);
    }
    return 0;
}
