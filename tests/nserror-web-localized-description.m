// -[NSError _web_localizedDescription], Foundation SPI that WebKit's
// ResourceError uses. Observed on macOS 26.7.3 (x86_64): for errors outside
// NSURLErrorDomain it is the error's localizedDescription. (For
// NSURLErrorDomain macOS gives the system's description of the code instead,
// which Darling doesn't have; that isn't tested here.)
#import <Foundation/Foundation.h>
#include <errno.h>
#include <stdio.h>

@interface NSError (WebKitSPI)
- (NSString *)_web_localizedDescription;
@end

int main(void)
{
    int failures = 0;
    @autoreleasepool {
        NSArray *errors = @[
            [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileNoSuchFileError userInfo:nil],
            [NSError errorWithDomain:NSPOSIXErrorDomain code:ENOENT userInfo:nil],
            [NSError errorWithDomain:@"MyDomain" code:7 userInfo:nil],
            [NSError errorWithDomain:@"MyDomain" code:7 userInfo:@{ NSLocalizedFailureReasonErrorKey: @"reason" }],
            [NSError errorWithDomain:@"MyDomain" code:7 userInfo:@{ NSLocalizedDescriptionKey: @"custom" }],
            [NSError errorWithDomain:@"WebKitErrorDomain" code:102 userInfo:nil],
        ];
        for (NSError *error in errors) {
            BOOL ok = [[error _web_localizedDescription] isEqualToString:[error localizedDescription]];
            printf("%s: %s %ld\n", ok ? "PASS" : "FAIL", [[error domain] UTF8String], (long)[error code]);
            if (!ok)
                failures++;
        }
    }
    return failures != 0;
}
