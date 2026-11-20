// Copyright (C) 2026 Lubos Dolezel
//
// +[NSString availableStringEncodings] and +[NSString localizedNameOfStringEncoding:].
// On macOS 26.7.3 and Mac OS X 10.14.4 (English) the available encodings are
// CoreFoundation's, converted, in the same order and ending with 0; each name is
// CFStringGetNameOfEncoding's, and an unknown encoding has an empty name.

#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expectTrue(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

static void expectName(NSStringEncoding encoding, NSString *expected)
{
    NSString *name = [NSString localizedNameOfStringEncoding:encoding];
    BOOL ok = [name isKindOfClass:[NSString class]] && [name isEqualToString:expected];
    printf("%s name of %#lx: got \"%s\", expected \"%s\"\n", ok ? "PASS" : "FAIL", (unsigned long)encoding,
           name ? [name UTF8String] : "(nil)", [expected UTF8String]);
    failures += !ok;
}

int main(void)
{
    @autoreleasepool {
        expectName(NSUTF8StringEncoding, @"Unicode (UTF-8)");
        expectName(NSUnicodeStringEncoding, @"Unicode (UTF-16)");
        expectName(NSMacOSRomanStringEncoding, @"Western (Mac OS Roman)");
        expectName(NSWindowsCP1252StringEncoding, @"Western (Windows Latin 1)");
        expectName(NSISOLatin1StringEncoding, @"Western (ISO Latin 1)");
        expectName(NSASCIIStringEncoding, @"Western (ASCII)");
        expectName(NSNonLossyASCIIStringEncoding, @"Non-lossy ASCII");
        expectName(NSShiftJISStringEncoding, @"Japanese (Windows, DOS)");
        expectName(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese), @"Japanese (Mac OS)");
        expectName(CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000), @"Chinese (GB 18030)");
        expectName(12345, @"");

        const NSStringEncoding *available = [NSString availableStringEncodings];
        expectTrue("available encodings exist", available != NULL);
        const CFStringEncoding *cf = CFStringGetListOfAvailableEncodings();
        NSUInteger count = 0, cfCount = 0;
        while (available && available[count]) count++;
        while (cf[cfCount] != kCFStringEncodingInvalidId) cfCount++;
        printf("%lu available, %lu in CoreFoundation\n", (unsigned long)count, (unsigned long)cfCount);
        expectTrue("as many as CoreFoundation's", count == cfCount && count > 0);
        BOOL sameOrder = count == cfCount, named = YES, utf8 = NO;
        for (NSUInteger i = 0; i < count; i++) {
            if (i < cfCount && available[i] != CFStringConvertEncodingToNSStringEncoding(cf[i])) sameOrder = NO;
            NSString *name = [NSString localizedNameOfStringEncoding:available[i]];
            CFStringRef cfName = CFStringGetNameOfEncoding(CFStringConvertNSStringEncodingToEncoding(available[i]));
            if ([name length] == 0 || !cfName || ![name isEqualToString:(NSString *)cfName]) named = NO;
            if (available[i] == NSUTF8StringEncoding) utf8 = YES;
        }
        expectTrue("CoreFoundation's encodings in its order", sameOrder);
        expectTrue("every available encoding has CoreFoundation's name", named);
        expectTrue("UTF-8 is available", utf8);
        expectTrue("same list on every call", available == [NSString availableStringEncodings]);
    }
    printf("failures=%d\n", failures);
    return failures ? 1 : 0;
}
