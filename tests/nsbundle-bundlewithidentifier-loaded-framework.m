// CFLAGS: -framework Foundation
/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * +[NSBundle bundleWithIdentifier:] returns the bundle of a framework that the dynamic linker has
 * loaded even if no NSBundle was created for it yet, returns the same object on repeated calls, and
 * returns nil for an identifier that matches nothing.
 */
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL: %s (line %d)\n", #c, __LINE__); failures++; } } while (0)

// A framework with a CFBundleIdentifier that this program does not link and that nothing in it
// touches before the lookup below (not Foundation, CoreFoundation or AppKit).
#define FRAMEWORK_DIR "/System/Library/Frameworks/CoreServices.framework"
#define FRAMEWORK_NAME @"CoreServices.framework"

int main(void)
{
    @autoreleasepool
    {
        // Read through the property list parser, not through NSBundle, so that no NSBundle exists yet.
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:@FRAMEWORK_DIR "/Resources/Info.plist"];
        NSString *identifier = info[@"CFBundleIdentifier"];
        CHECK([identifier length] > 0);
        if ([identifier length] == 0)
        {
            return 1;
        }

        void *handle = dlopen(FRAMEWORK_DIR "/CoreServices", RTLD_NOW);
        if (handle == NULL)
        {
            printf("FAIL: dlopen: %s\n", dlerror());
            return 1;
        }

        // On a build without the fix this is nil: the framework is loaded but its bundle was never created.
        NSBundle *bundle = [NSBundle bundleWithIdentifier:identifier];
        CHECK(bundle != nil);
        CHECK([[bundle bundleIdentifier] isEqualToString:identifier]);
        CHECK([[bundle bundlePath] hasSuffix:FRAMEWORK_NAME]);

        CHECK([NSBundle bundleWithIdentifier:identifier] == bundle);
        CHECK([NSBundle bundleWithPath:[bundle bundlePath]] == bundle);

        CHECK([NSBundle bundleWithIdentifier:@"com.example.no-such-bundle-identifier"] == nil);
        CHECK([NSBundle bundleWithIdentifier:@""] == nil);

        // A nil identifier is not an error and finds nothing.
        id nilObject = nil;
        CHECK([NSBundle bundleWithIdentifier:nilObject] == nil);

        // The main bundle is a loaded bundle too; a test executable normally has no identifier.
        NSString *mainIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (mainIdentifier != nil)
        {
            CHECK([NSBundle bundleWithIdentifier:mainIdentifier] == [NSBundle mainBundle]);
        }
        else
        {
            printf("SKIP: the main bundle has no identifier\n");
        }
    }

    printf("%s\n", failures ? "FAILED" : "PASSED");
    return failures != 0;
}
