// Copyright (C) 2026 Lubos Dolezel
//
// NSStringTransform constants with -stringByApplyingTransform:reverse: and
// -applyTransform:reverse:range:updatedRange:, the deallocator-taking no-copy string
// initializers and +[NSDate now]. Build with -fobjc-arc.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

static int failures;

static void expectTrue(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

int main(void)
{
    @autoreleasepool {
        NSString *source = @"Ångström";
        expectTrue("strip diacritics", [[source stringByApplyingTransform:NSStringTransformStripDiacritics reverse:NO] isEqualToString:@"Angstrom"]);
        expectTrue("unicode name", [[source stringByApplyingTransform:NSStringTransformToUnicodeName reverse:NO]
                                       isEqualToString:@"\\N{LATIN CAPITAL LETTER A WITH RING ABOVE}ngstr\\N{LATIN SMALL LETTER O WITH DIAERESIS}m"]);
        expectTrue("unicode name reverse", [[@"\\N{LATIN SMALL LETTER E WITH ACUTE}" stringByApplyingTransform:NSStringTransformToUnicodeName reverse:YES]
                                               isEqualToString:@"é"]);

        NSMutableString *m = [NSMutableString stringWithString:@"xééx"];
        NSRange updated = NSMakeRange(0, 0);
        BOOL ok = [m applyTransform:NSStringTransformStripDiacritics reverse:NO range:NSMakeRange(1, 2) updatedRange:&updated];
        expectTrue("applyTransform on a range", ok && [m isEqualToString:@"xeex"] && updated.location == 1 && updated.length == 2);

        // No-copy initializers with a deallocator (newer than macOS 10.14: skipped there)
        NSString *probe = [NSString alloc];
        if ([probe respondsToSelector:@selector(initWithCharactersNoCopy:length:deallocator:)])
        {
            __block int freed = 0;
            unichar *chars = malloc(3 * sizeof(unichar));
            chars[0] = 'a'; chars[1] = 'b'; chars[2] = 'c';
            NSString *fromChars = [probe initWithCharactersNoCopy:chars length:3 deallocator:^(unichar *p, NSUInteger n) { free(p); freed++; }];
            expectTrue("characters no copy", [fromChars isEqualToString:@"abc"]);
            char *bytes = malloc(2);
            bytes[0] = 'h'; bytes[1] = 'i';
            NSString *fromBytes = [[NSString alloc] initWithBytesNoCopy:bytes length:2 encoding:NSUTF8StringEncoding deallocator:^(void *p, NSUInteger n) { free(p); freed++; }];
            expectTrue("bytes no copy", [fromBytes isEqualToString:@"hi"]);
            // the deallocator runs when the string is released, not before
            fromChars = nil;
            fromBytes = nil;
            expectTrue("deallocators called on release", freed == 2);
        }
        else
        {
            printf("SKIP deallocator initializers (newer than 10.14)\n");
        }

        // +[NSDate now] is 10.15 API: not available on Mojave
        if ([NSDate respondsToSelector:@selector(now)])
        {
            NSDate *now = [NSDate performSelector:@selector(now)];
            expectTrue("NSDate now", fabs([now timeIntervalSinceNow]) < 5);
        }
        else
        {
            printf("SKIP NSDate now (needs 10.15)\n");
        }
    }
    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures ? 1 : 0;
}
