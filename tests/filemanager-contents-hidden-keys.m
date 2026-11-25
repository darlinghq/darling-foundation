// CFLAGS: -framework Foundation -fobjc-arc
// ARGS: "$(mktemp -d)/c"
// -[NSFileManager contentsOfDirectoryAtURL:includingPropertiesForKeys:options:error:] with NSURLIsHiddenKey and
// NSURLHasHiddenExtensionKey: the URLs it returns give the same values as fresh URLs for the same items (the Finder's
// invisible and extension-hidden flags count), and listing a folder changes nothing on disk.
// Passes unchanged on macOS 10.14.4 and 26.7.3. Usage: filemanager-contents-hidden-keys <new directory>.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>
#include <sys/xattr.h>

static int failures;

static void expect(BOOL ok, const char *label)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

static void setFinderFlags(NSString *path, unsigned char byte8, unsigned char byte9)
{
    unsigned char info[32] = { 0 };
    info[8] = byte8;
    info[9] = byte9;
    setxattr([path fileSystemRepresentation], "com.apple.FinderInfo", info, sizeof info, 0, XATTR_NOFOLLOW);
}

static BOOL boolValue(NSURL *url, NSURLResourceKey key)
{
    NSNumber *value = nil;
    [url getResourceValue: &value forKey: key error: NULL];
    return [value boolValue];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: %s <new directory>\n", argv[0]);
            return 2;
        }
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dir = [NSString stringWithUTF8String: argv[1]];
        [fm createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL];
        NSString *invisible = [dir stringByAppendingPathComponent: @"invisible.txt"];
        NSString *extension = [dir stringByAppendingPathComponent: @"extension.txt"];
        NSString *plain = [dir stringByAppendingPathComponent: @"plain.txt"];
        for (NSString *path in @[ invisible, extension, plain ])
            [[NSData data] writeToFile: path atomically: NO];
        setFinderFlags(invisible, 0x40, 0);
        setFinderFlags(extension, 0, 0x10);

        NSArray *keys = @[ NSURLIsHiddenKey, NSURLHasHiddenExtensionKey ];
        NSError *error = nil;
        NSArray<NSURL *> *contents = [fm contentsOfDirectoryAtURL: [NSURL fileURLWithPath: dir]
                                       includingPropertiesForKeys: keys
                                                          options: 0
                                                            error: &error];
        expect([contents count] == 3, "the folder lists its three items");
        for (NSURL *url in contents) {
            NSString *name = [url lastPathComponent];
            NSURL *fresh = [NSURL fileURLWithPath: [url path]];
            BOOL same = boolValue(url, NSURLIsHiddenKey) == boolValue(fresh, NSURLIsHiddenKey)
                && boolValue(url, NSURLHasHiddenExtensionKey) == boolValue(fresh, NSURLHasHiddenExtensionKey);
            printf("%s %s: listed hidden %d extension %d, fresh hidden %d extension %d\n", same ? "PASS" : "FAIL",
                   [name UTF8String], boolValue(url, NSURLIsHiddenKey), boolValue(url, NSURLHasHiddenExtensionKey),
                   boolValue(fresh, NSURLIsHiddenKey), boolValue(fresh, NSURLHasHiddenExtensionKey));
            failures += !same;
            if ([name isEqual: @"invisible.txt"])
                expect(boolValue(url, NSURLIsHiddenKey), "the invisible item is listed as hidden");
            if ([name isEqual: @"extension.txt"])
                expect(boolValue(url, NSURLHasHiddenExtensionKey), "the extension-hidden item is listed with its extension hidden");
            if ([name isEqual: @"plain.txt"])
                expect(!boolValue(url, NSURLIsHiddenKey) && !boolValue(url, NSURLHasHiddenExtensionKey), "the plain item is neither");
        }

        unsigned char info[32] = { 0 };
        getxattr([extension fileSystemRepresentation], "com.apple.FinderInfo", info, sizeof info, 0, XATTR_NOFOLLOW);
        expect(info[9] == 0x10, "listing leaves the extension-hidden flag on disk");
        memset(info, 0, sizeof info);
        getxattr([invisible fileSystemRepresentation], "com.apple.FinderInfo", info, sizeof info, 0, XATTR_NOFOLLOW);
        expect(info[8] == 0x40, "listing leaves the invisible flag on disk");

        printf(failures ? "FAILED %d\n" : "ALL PASSED\n", failures);
    }
    return failures != 0;
}
