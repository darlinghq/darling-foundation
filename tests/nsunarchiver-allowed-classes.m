// Copyright (C) 2026 Lubos Dolezel
//
// QUIRK coverage: NSUnarchiver accepts the private -_setAllowedClasses: and decodes normally.
#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void)
{
    int failures = 0;
    @autoreleasepool {
        NSData *d = [NSArchiver archivedDataWithRootObject:@[ @"a", @1 ]];
        NSUnarchiver *u = [[NSUnarchiver alloc] initForReadingWithData:d];
        SEL sel = NSSelectorFromString(@"_setAllowedClasses:");
        // test_quirk_set_allowed_classes_is_accepted
        if (![u respondsToSelector:sel]) { printf("FAIL: selector not accepted\n"); failures++; }
        else {
            [u performSelector:sel withObject:[NSSet setWithObject:[NSArray class]]];
            id o = [u decodeObject];
            if (![o isEqual:(@[ @"a", @1 ])]) { printf("FAIL: decode after the call\n"); failures++; }
        }
        [u release];
    }
    printf(failures ? "FAILED\n" : "PASS\n");
    return failures != 0;
}
