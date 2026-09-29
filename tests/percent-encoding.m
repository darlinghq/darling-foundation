#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool {
        NSCharacterSet *letters = [NSCharacterSet characterSetWithCharactersInString:@"abe"];
        assert([[ @"a b%" stringByAddingPercentEncodingWithAllowedCharacters:letters] isEqual:@"a%20b%25"]);
        assert([[ @"e\u0301" stringByAddingPercentEncodingWithAllowedCharacters:letters] isEqual:@"e%CC%81"]);
        NSCharacterSet *nonASCII = [NSCharacterSet characterSetWithCharactersInString:@"\u00e9\U0001f600"];
        assert([[ @"\u00e9\U0001f600" stringByAddingPercentEncodingWithAllowedCharacters:nonASCII] isEqual:@"%C3%A9%F0%9F%98%80"]);
        assert([[ @"" stringByAddingPercentEncodingWithAllowedCharacters:letters] isEqual:@""]);
        const unichar embedded[] = {'a', 0, 'b'};
        NSString *withNul = [NSString stringWithCharacters:embedded length:3];
        assert([[withNul stringByAddingPercentEncodingWithAllowedCharacters:letters] isEqual:@"a%00b"]);
        assert([[ @"%20" stringByAddingPercentEncodingWithAllowedCharacters:letters] isEqual:@"%25%32%30"]);
        const unichar invalidUnits[] = {0xd800};
        NSString *invalid = [NSString stringWithCharacters:invalidUnits length:1];
        assert(invalid != nil);
        assert([invalid stringByAddingPercentEncodingWithAllowedCharacters:letters] == nil);
        NSCharacterSet *path = [NSCharacterSet performSelector:NSSelectorFromString(@"URLPathAllowedCharacterSet")];
        NSCharacterSet *query = [NSCharacterSet performSelector:NSSelectorFromString(@"URLQueryAllowedCharacterSet")];
        assert([[ @"a/b;c?d" stringByAddingPercentEncodingWithAllowedCharacters:path] isEqual:@"a/b%3Bc%3Fd"]);
        assert([[ @"a/b;c?d" stringByAddingPercentEncodingWithAllowedCharacters:query] isEqual:@"a/b;c?d"]);
    }
    puts("PASS: percent encoding ASCII, combining marks, non-ASCII and embedded NUL");
    return 0;
}
