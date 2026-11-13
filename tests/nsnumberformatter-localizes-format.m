/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// -localizesFormat defaults to YES and reads back what was set, also on a copy. On a 10.4-style
// formatter it does not change the output (observed on macOS 26.7.3).
#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool {
        int failures = 0;
        NSNumberFormatter *f = [[[NSNumberFormatter alloc] init] autorelease];
        [f setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
        [f setFormat:@"#,##0.00"];
        if (![f localizesFormat]) {
            printf("FAIL: localizesFormat does not default to YES\n");
            failures++;
        }
        NSString *before = [f stringFromNumber:@1234.5];
        [f setLocalizesFormat:NO];
        if ([f localizesFormat]) {
            printf("FAIL: localizesFormat does not read back NO\n");
            failures++;
        }
        if ([[f copy] autorelease] == nil || [[[f copy] autorelease] localizesFormat]) {
            printf("FAIL: a copy does not keep localizesFormat\n");
            failures++;
        }
        if (![[f stringFromNumber:@1234.5] isEqualToString:before]) {
            printf("FAIL: localizesFormat changed the output of a 10.4-style formatter\n");
            failures++;
        }
        if (failures == 0)
            printf("PASS\n");
        return failures != 0;
    }
}
