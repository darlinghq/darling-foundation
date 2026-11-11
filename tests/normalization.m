#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

static void exact(NSString *actual, const unichar *expected, NSUInteger length)
{
    assert([actual length] == length);
    for (NSUInteger i = 0; i < length; ++i)
        assert([actual characterAtIndex:i] == expected[i]);
}

int main(void)
{
    @autoreleasepool {
        const unichar composed[] = {0x00e9};
        const unichar decomposed[] = {'e', 0x0301};
        const unichar ligature[] = {0xfb01};
        const unichar expanded[] = {'f', 'i'};
        NSString *nfd = [NSString stringWithCharacters:decomposed length:2];
        NSString *nfc = [NSString stringWithCharacters:composed length:1];
        NSString *compat = [NSString stringWithCharacters:ligature length:1];
        exact([nfd precomposedStringWithCanonicalMapping], composed, 1);
        exact([nfc decomposedStringWithCanonicalMapping], decomposed, 2);
        exact([nfc decomposedStringWithCompatibilityMapping], decomposed, 2);
        exact([compat precomposedStringWithCanonicalMapping], ligature, 1);
        exact([compat decomposedStringWithCompatibilityMapping], expanded, 2);
        exact([compat precomposedStringWithCompatibilityMapping], expanded, 2);
        exact(nfd, decomposed, 2);
        exact(compat, ligature, 1);
        assert([[@"" precomposedStringWithCanonicalMapping] length] == 0);
        assert([[@"" decomposedStringWithCompatibilityMapping] length] == 0);
    }
    puts("PASS: exact canonical and compatibility normalization code units");
    return 0;
}
