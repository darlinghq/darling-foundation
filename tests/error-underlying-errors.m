// NSError's underlyingErrors (Apple's NSError reference, macOS 11.3): the
// error under NSUnderlyingErrorKey, then the ones under
// NSMultipleUnderlyingErrorsKey; values that are not errors are left out.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(cond, what) do { if (!(cond)) { printf("FAIL: %s\n", what); failures++; } else printf("PASS: %s\n", what); } while (0)

int main(void)
{
    @autoreleasepool
    {
        NSError *a = [NSError errorWithDomain:NSPOSIXErrorDomain code:1 userInfo:nil];
        NSError *b = [NSError errorWithDomain:NSPOSIXErrorDomain code:2 userInfo:nil];
        NSError *c = [NSError errorWithDomain:NSCocoaErrorDomain code:3 userInfo:nil];

        CHECK([NSMultipleUnderlyingErrorsKey isEqualToString:@"NSMultipleUnderlyingErrorsKey"], "the key's string");
        CHECK(a.underlyingErrors != nil && a.underlyingErrors.count == 0, "an error without underlying errors gives an empty array");

        NSError *single = [NSError errorWithDomain:NSCocoaErrorDomain code:10 userInfo:@{ NSUnderlyingErrorKey: a }];
        CHECK([single.underlyingErrors isEqualToArray:@[ a ]], "the error under NSUnderlyingErrorKey");

        NSError *both = [NSError errorWithDomain:NSCocoaErrorDomain code:11
                                        userInfo:@{ NSUnderlyingErrorKey: a, NSMultipleUnderlyingErrorsKey: @[ b, c ] }];
        CHECK([both.underlyingErrors isEqualToArray:(@[ a, b, c ])], "NSUnderlyingErrorKey's error comes first");

        NSError *mixed = [NSError errorWithDomain:NSCocoaErrorDomain code:12
                                         userInfo:@{ NSUnderlyingErrorKey: @"not an error", NSMultipleUnderlyingErrorsKey: @[ b, @42 ] }];
        CHECK([mixed.underlyingErrors isEqualToArray:@[ b ]], "values that are not errors are left out");

        NSError *notArray = [NSError errorWithDomain:NSCocoaErrorDomain code:13 userInfo:@{ NSMultipleUnderlyingErrorsKey: c }];
        CHECK(notArray.underlyingErrors.count == 0, "a value under NSMultipleUnderlyingErrorsKey that is not an array is ignored");

        CFErrorRef cfError = CFErrorCreate(kCFAllocatorDefault, kCFErrorDomainPOSIX, 5,
                                           (CFDictionaryRef)@{ NSUnderlyingErrorKey: b });
        CHECK([((NSError *)cfError).underlyingErrors isEqualToArray:@[ b ]], "a CFError, bridged, has the same underlying errors");
        CFRelease(cfError);
    }
    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures != 0;
}
