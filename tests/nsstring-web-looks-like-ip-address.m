// -[NSString _web_looksLikeIPAddress], Foundation SPI that WebKit uses to tell
// whether a URL's host is an IP address. Every expectation below was observed
// on macOS 26.7.3 (x86_64) with the same strings.
#import <Foundation/Foundation.h>
#include <stdio.h>

@interface NSString (WebKitSPI)
- (BOOL)_web_looksLikeIPAddress;
@end

int main(void)
{
    int failures = 0;
    @autoreleasepool {
        struct { NSString *string; BOOL expected; } cases[] = {
            // IPv4: four parts of digits, leading zeros allowed, each at most 255
            { @"1.2.3.4", YES }, { @"255.255.255.255", YES }, { @"0.0.0.0", YES },
            { @"01.02.03.04", YES }, { @"001.002.003.004", YES }, { @"1.2.3.0004", YES },
            { @"1.2.3.0255", YES }, { @"1.2.3.0256", NO }, { @"256.1.1.1", NO },
            { @"1.2.3.1234", NO }, { @"1.2.3", NO }, { @"1", NO }, { @"12345", NO },
            { @"1.2.3.4.5", NO }, { @"1.2.3.", NO }, { @".1.2.3", NO }, { @"1..2.3", NO },
            { @"0x7f.0.0.1", NO }, { @"1.2.3.-4", NO }, { @"1.2.3.+4", NO },
            { @"1.2.3.4:80", NO }, { @" 1.2.3.4", NO }, { @"1.2.3.4 ", NO },
            { @"1.2.3.4\n", NO }, { @"1.2.3.a", NO }, { @"1.2.3.4a", NO },
            { @"[1.2.3.4]", NO }, { @"1.2.3.4%en0", NO },
            // IPv6
            { @"::1", YES }, { @"::", YES }, { @"fe80::1", YES }, { @"FE80::1", YES },
            { @"2001:db8::", YES }, { @"2001:0db8:0000:0000:0000:0000:0000:0001", YES },
            { @"1:2:3:4:5:6:7:8", YES }, { @"1:2:3:4:5:6:7::", YES }, { @"::1:2:3:4:5:6:7", YES },
            { @"0001:2::1", YES }, { @"00001::1", YES }, { @"12345::1", NO },
            { @"::ffff:1.2.3.4", YES }, { @"::FFFF:1.2.3.4", YES }, { @"::ffff:01.2.3.4", YES },
            { @"1:2:3:4:5:6:1.2.3.4", YES }, { @"::ffff:1.2.3", NO },
            { @"1:2:3:4:5:6:7:8:9", NO }, { @"1::2::3", NO }, { @":", NO }, { @":::", NO },
            { @"g::1", NO }, { @"dead:beef", NO }, { @"abcd", NO }, { @"[::1]", NO },
            // IPv6 zones
            { @"fe80::1%en0", YES }, { @"fe80::1%zzz", YES }, { @"fe80::1%", YES },
            { @"fe80::1% en0", YES }, { @"::1%1", YES }, { @"fe80::1%%", NO },
            { @"fe80::1%en0%x", NO },
            // names
            { @"example.com", NO }, { @"localhost", NO }, { @"1e100.net", NO },
            { @"a.b.c.d", NO }, { @"", NO },
        };
        for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
            BOOL result = [cases[i].string _web_looksLikeIPAddress];
            BOOL ok = result == cases[i].expected;
            printf("%s: '%s' -> %d\n", ok ? "PASS" : "FAIL",
                   [[cases[i].string stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"] UTF8String], result);
            if (!ok)
                failures++;
        }
        // The string ends at an embedded NUL.
        NSString *withNul = [[[NSString alloc] initWithBytes:"1.2.3.4\0x" length:9 encoding:NSUTF8StringEncoding] autorelease];
        BOOL ok = [withNul _web_looksLikeIPAddress];
        printf("%s: an embedded NUL ends the string\n", ok ? "PASS" : "FAIL");
        if (!ok)
            failures++;
    }
    return failures != 0;
}
