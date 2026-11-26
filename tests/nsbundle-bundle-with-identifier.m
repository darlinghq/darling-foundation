// +[NSBundle bundleWithIdentifier:] finds a loaded framework by its
// identifier even when no NSBundle has been made for it yet. Observed on
// macOS 26.7.3 (x86_64) with the same calls.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

int main(void)
{
    @autoreleasepool {
        // Asked for first, before anything else makes its NSBundle.
        NSBundle *coreFoundation = [NSBundle bundleWithIdentifier: @"com.apple.CoreFoundation"];
        report("CoreFoundation is found", [[[coreFoundation bundlePath] lastPathComponent] isEqualToString: @"CoreFoundation.framework"]);
        report("with its identifier", [[coreFoundation bundleIdentifier] isEqualToString: @"com.apple.CoreFoundation"]);
        report("the same bundle the next time", [NSBundle bundleWithIdentifier: @"com.apple.CoreFoundation"] == coreFoundation);

        NSBundle *foundation = [NSBundle bundleWithIdentifier: @"com.apple.Foundation"];
        report("Foundation is found", [[[foundation bundlePath] lastPathComponent] isEqualToString: @"Foundation.framework"]);
        report("it is the bundle of its classes", foundation == [NSBundle bundleForClass: [NSObject class]]
                                                   || foundation == [NSBundle bundleForClass: [NSBundle class]]);

        report("an unknown identifier gives nil", [NSBundle bundleWithIdentifier: @"org.darlinghq.test.no-such-bundle"] == nil);
    }
    return failures != 0;
}
