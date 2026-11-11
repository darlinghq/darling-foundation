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
        expect([NSInlinePresentationIntentAttributeName isEqualToString:@"NSInlinePresentationIntent"],
               @"inline presentation intent key");
        expect([NSLanguageIdentifierAttributeName isEqualToString:@"NSLanguage"], @"language identifier key");

        expect(NSInlinePresentationIntentEmphasized == 1 && NSInlinePresentationIntentStronglyEmphasized == 2 &&
               NSInlinePresentationIntentCode == 4 && NSInlinePresentationIntentStrikethrough == 32 &&
               NSInlinePresentationIntentSoftBreak == 64 && NSInlinePresentationIntentLineBreak == 128 &&
               NSInlinePresentationIntentInlineHTML == 256 && NSInlinePresentationIntentBlockHTML == 512,
               @"inline presentation intent bits");

        NSInlinePresentationIntent intent = NSInlinePresentationIntentStronglyEmphasized | NSInlinePresentationIntentCode;
        NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] initWithString:@"bold code"] autorelease];
        [string addAttribute:NSInlinePresentationIntentAttributeName value:@(intent) range:NSMakeRange(0, 4)];
        [string addAttribute:NSLanguageIdentifierAttributeName value:@"en-US" range:NSMakeRange(0, string.length)];

        NSRange range;
        NSNumber *stored = [string attribute:NSInlinePresentationIntentAttributeName atIndex:0 effectiveRange:&range];
        expect(stored.unsignedIntegerValue == intent && range.length == 4, @"intent attribute round trip");
        NSDictionary *tail = [string attributesAtIndex:5 effectiveRange:NULL];
        expect(tail[NSInlinePresentationIntentAttributeName] == nil && [tail[@"NSLanguage"] isEqualToString:@"en-US"],
               @"language attribute is found under its string value");

        NSLog(@"PASS: %@=%lu, %@=%@", NSInlinePresentationIntentAttributeName, (unsigned long)stored.unsignedIntegerValue,
              NSLanguageIdentifierAttributeName, tail[NSLanguageIdentifierAttributeName]);
    }
    return 0;
}
