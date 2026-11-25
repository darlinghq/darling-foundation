// CFLAGS: -framework Foundation
// Copyright (C) 2026 Lubos Dolezel
//
// NSHomeDirectory() in a process without HOME in its environment (as an application LaunchServices launches can be)
// is the user's home directory from the user database, as on macOS 10.14.4 and 26.7.3 (observed; the program passes
// unchanged on both), not "/".
//
// Prints PASS or FAIL lines, then ALL PASSED or FAILED n.
#import <Foundation/Foundation.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void)
{
    int failures = 0;
    @autoreleasepool {
        unsetenv("HOME");
        struct passwd *pw = getpwuid(getuid());
        NSString *want = pw != NULL ? [NSString stringWithUTF8String: pw->pw_dir] : nil;
        NSString *home = NSHomeDirectory();
        BOOL ok = want != nil && [home isEqual: want];
        printf("%s NSHomeDirectory() without HOME is the user database's home (%s, want %s)\n", ok ? "PASS" : "FAIL",
               [home UTF8String], [want UTF8String]);
        if (!ok)
            failures++;
        ok = [NSHomeDirectory() isEqual: home];
        printf("%s it stays the same\n", ok ? "PASS" : "FAIL");
        if (!ok)
            failures++;
    }
    printf(failures ? "FAILED %d\n" : "ALL PASSED\n", failures);
    return failures != 0;
}
