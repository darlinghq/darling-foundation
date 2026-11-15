// Copyright (C) 2026 Lubos Dolezel
// Creating the standard user defaults does not write the locale preferences (AppleLocale, AppleLanguages)
// into the application's own preferences: they belong to the global domain, and a copy in the
// application's domain would override whatever the user or the system configured there.
#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool
    {
        (void)[NSUserDefaults standardUserDefaults];
        CFStringRef keys[] = {CFSTR("AppleLocale"), CFSTR("AppleLanguages")};
        int failures = 0;
        for (int i = 0; i < 2; i++)
        {
            CFPropertyListRef value = CFPreferencesCopyValue(keys[i], kCFPreferencesCurrentApplication,
                                                             kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
            if (value != NULL)
            {
                printf("FAIL: %s was written to the application's preferences\n", [(NSString *)keys[i] UTF8String]);
                CFRelease(value);
                failures++;
            }
        }
        if (failures == 0)
            printf("PASS\n");
        return failures != 0;
    }
}
