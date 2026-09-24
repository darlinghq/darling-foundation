// NSByteCountFormatter formattingContext: default, round trip, copies, and the
// capitalization of the non-numeric zero. Exits non-zero on failure.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures = 0;

static void expect(const char *what, NSString *got, NSString *want)
{
    if (![got isEqualToString:want])
    {
        printf("FAIL %s: got \"%s\", want \"%s\"\n", what, got ? [got UTF8String] : "(nil)", [want UTF8String]);
        failures++;
    }
}

int main(void)
{
    @autoreleasepool {
        NSByteCountFormatter *f = [[[NSByteCountFormatter alloc] init] autorelease];
        if ([f formattingContext] != NSFormattingContextUnknown)
        {
            printf("FAIL default context %ld\n", (long)[f formattingContext]);
            failures++;
        }
        expect("unknown context", [f stringFromByteCount:0], @"Zero KB");

        [f setFormattingContext:NSFormattingContextMiddleOfSentence];
        if ([f formattingContext] != NSFormattingContextMiddleOfSentence)
        {
            printf("FAIL context round trip\n");
            failures++;
        }
        expect("middle of sentence", [f stringFromByteCount:0], @"zero KB");
        [f setAllowedUnits:NSByteCountFormatterUseBytes];
        expect("middle of sentence, bytes", [f stringFromByteCount:0], @"zero bytes");

        NSByteCountFormatter *copy = [[f copy] autorelease];
        expect("copy keeps context", [copy stringFromByteCount:0], @"zero bytes");

        [f setFormattingContext:NSFormattingContextBeginningOfSentence];
        expect("beginning of sentence", [f stringFromByteCount:0], @"Zero bytes");
        [f setFormattingContext:NSFormattingContextStandalone];
        expect("standalone", [f stringFromByteCount:0], @"Zero bytes");
    }
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
