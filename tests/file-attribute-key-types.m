// NSFileAttributeKey, NSFileAttributeType and NSFileProtectionType name the
// types of the NSFileManager attribute constants, as in the SDK headers. Code
// written against the SDK declares variables, dictionaries and functions with
// these names; it must compile against Darling's headers and see the same values.
#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSFileAttributeType typeOf(NSDictionary<NSFileAttributeKey, id> *attributes)
{
    return attributes[NSFileType];
}

int main(void)
{
    @autoreleasepool
    {
        NSFileAttributeKey sizeKey = NSFileSize;
        NSFileProtectionType protection = NSFileProtectionNone;
        expect([sizeKey isEqualToString:@"NSFileSize"], @"NSFileSize value");
        expect(protection != nil, @"NSFileProtectionNone is defined");

        NSString *path = NSTemporaryDirectory();
        NSError *error = nil;
        NSDictionary<NSFileAttributeKey, id> *attributes =
            [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
        expect(attributes != nil, @"attributes of the temporary directory");
        NSFileAttributeType type = typeOf(attributes);
        expect([type isEqualToString:NSFileTypeDirectory], @"the temporary directory is a directory");
    }
    NSLog(@"PASS");
    return 0;
}
