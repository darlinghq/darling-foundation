// Copyright (C) 2026 Lubos Dolezel
//
// NSURLIsPackageKey and NSDirectoryEnumerationSkipsPackageDescendants. A
// directory is a package when its type is declared as one (.app, .bundle,
// .plugin, .rtfd) or when it has the Finder's bundle bit; a .framework, a
// plain folder, a file and a symbolic link are not. The URL enumerator lists
// a package but not its contents when asked to skip them; the path-based
// enumerator always descends into packages.
// Built without ARC. Values are those observed on macOS 26.7.3 and Mac OS X
// 10.14.4 (x86_64 and i386), where the program builds and runs too.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/xattr.h>
#include <unistd.h>

static int failures;
static NSString *root;

static void expect(BOOL ok, NSString *what)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", [what UTF8String]);
    if (!ok)
        failures++;
}

static void makeDirectory(NSString *rel)
{
    [[NSFileManager defaultManager] createDirectoryAtPath:[root stringByAppendingPathComponent:rel]
                              withIntermediateDirectories:YES attributes:nil error:NULL];
}

static void makeFile(NSString *rel)
{
    [[NSData data] writeToFile:[root stringByAppendingPathComponent:rel] atomically:NO];
}

// 1 or 0, or -1 when no value came back.
static int isPackage(NSURL *url, BOOL *succeeded)
{
    NSNumber *value = nil;
    *succeeded = [url getResourceValue:&value forKey:NSURLIsPackageKey error:NULL];
    return value == nil ? -1 : ([value boolValue] ? 1 : 0);
}

static void checkPackage(NSString *rel, int expected)
{
    BOOL succeeded = NO;
    int value = isPackage([NSURL fileURLWithPath:[root stringByAppendingPathComponent:rel]], &succeeded);
    expect(succeeded && value == expected,
           [NSString stringWithFormat:@"%@: NSURLIsPackageKey is %s (got %d)", rel, expected ? "YES" : "NO", value]);
}

static NSString *relative(NSString *path)
{
    if ([path hasPrefix:root])
        return [path substringFromIndex:[root length] + 1];
    return path;
}

static NSSet *enumerateURLs(NSString *rel, NSDirectoryEnumerationOptions options)
{
    NSURL *directory = [NSURL fileURLWithPath:[root stringByAppendingPathComponent:rel]];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:directory
        includingPropertiesForKeys:nil options:options errorHandler:nil];
    NSMutableSet *seen = [NSMutableSet set];
    NSURL *url;
    while ((url = [enumerator nextObject]) != nil)
        [seen addObject:relative([[url path] stringByResolvingSymlinksInPath])];
    return seen;
}

static void checkSeen(NSSet *seen, NSString *rel, BOOL expected, NSString *context)
{
    expect([seen containsObject:rel] == expected,
           [NSString stringWithFormat:@"%@: %@ is %@", context, rel, expected ? @"listed" : @"skipped"]);
}

int main(void)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSFileManager *fm = [NSFileManager defaultManager];
    char dirTemplate[] = "/tmp/urlispackage.XXXXXX";
    if (mkdtemp(dirTemplate) == NULL) {
        perror("mkdtemp");
        return 1;
    }
    // /tmp is a link on macOS; compare resolved paths.
    root = [[[NSString stringWithUTF8String:dirTemplate] stringByResolvingSymlinksInPath] retain];

    makeDirectory(@"App.app/Contents/MacOS");
    makeFile(@"App.app/Contents/Info.plist");
    makeDirectory(@"Plain.app");
    makeFile(@"Plain.app/inner");
    makeDirectory(@"Thing.bundle");
    makeFile(@"Thing.bundle/inner");
    makeDirectory(@"Ext.plugin");
    makeDirectory(@"Doc.rtfd");
    makeFile(@"Doc.rtfd/TXT.rtf");
    makeDirectory(@"Kit.framework");
    makeFile(@"Kit.framework/inner");
    makeDirectory(@"Folder/sub");
    makeFile(@"Folder/sub/file");
    makeDirectory(@"Bit");
    makeFile(@"Bit/inner");
    makeFile(@"file.app");
    [fm createSymbolicLinkAtPath:[root stringByAppendingPathComponent:@"LinkApp.app"] withDestinationPath:@"App.app" error:NULL];

    // kHasBundle (0x2000) in the Finder flags, bytes 8 and 9 of com.apple.FinderInfo.
    unsigned char finderInfo[32] = { 0 };
    finderInfo[8] = 0x20;
    expect(setxattr([[root stringByAppendingPathComponent:@"Bit"] fileSystemRepresentation], "com.apple.FinderInfo",
                    finderInfo, sizeof finderInfo, 0, 0) == 0, @"the bundle bit can be set on a directory");

    checkPackage(@"App.app", 1);
    checkPackage(@"Plain.app", 1);
    checkPackage(@"Thing.bundle", 1);
    checkPackage(@"Ext.plugin", 1);
    checkPackage(@"Doc.rtfd", 1);
    checkPackage(@"Kit.framework", 0);
    checkPackage(@"Folder", 0);
    checkPackage(@"Bit", 1);
    checkPackage(@"file.app", 0);
    checkPackage(@"LinkApp.app", 0);

    BOOL succeeded = YES;
    int missing = isPackage([NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"Missing.app"]], &succeeded);
    expect(!succeeded && missing == -1, @"Missing.app: no value and an error");

    // Values prefetched by contentsOfDirectoryAtURL: are the same answers.
    NSArray *contents = [fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:root]
                          includingPropertiesForKeys:[NSArray arrayWithObject:NSURLIsPackageKey] options:0 error:NULL];
    NSDictionary *expectedContents = [NSDictionary dictionaryWithObjectsAndKeys:
        @YES, @"App.app", @YES, @"Bit", @NO, @"Kit.framework", @NO, @"Folder", @NO, @"file.app", @NO, @"LinkApp.app", nil];
    for (NSURL *url in contents) {
        NSString *name = [url lastPathComponent];
        NSNumber *expectedValue = [expectedContents objectForKey:name];
        if (expectedValue == nil)
            continue;
        NSNumber *value = nil;
        [url getResourceValue:&value forKey:NSURLIsPackageKey error:NULL];
        expect(value != nil && [value isEqual:expectedValue],
               [NSString stringWithFormat:@"contentsOfDirectoryAtURL: %@ is %@a package", name, [expectedValue boolValue] ? @"" : @"not "]);
    }

    NSString *context = @"URL enumerator skipping package descendants";
    NSSet *seen = enumerateURLs(@".", NSDirectoryEnumerationSkipsPackageDescendants);
    checkSeen(seen, @"App.app", YES, context);
    checkSeen(seen, @"App.app/Contents", NO, context);
    checkSeen(seen, @"Plain.app/inner", NO, context);
    checkSeen(seen, @"Thing.bundle/inner", NO, context);
    checkSeen(seen, @"Doc.rtfd", YES, context);
    checkSeen(seen, @"Doc.rtfd/TXT.rtf", NO, context);
    checkSeen(seen, @"Bit", YES, context);
    checkSeen(seen, @"Bit/inner", NO, context);
    checkSeen(seen, @"Kit.framework/inner", YES, context);
    checkSeen(seen, @"Folder/sub/file", YES, context);

    context = @"URL enumerator";
    seen = enumerateURLs(@".", 0);
    checkSeen(seen, @"App.app/Contents/Info.plist", YES, context);
    checkSeen(seen, @"Doc.rtfd/TXT.rtf", YES, context);

    context = @"URL enumerator rooted at a package, skipping package descendants";
    seen = enumerateURLs(@"App.app", NSDirectoryEnumerationSkipsPackageDescendants);
    checkSeen(seen, @"App.app/Contents", YES, context);
    checkSeen(seen, @"App.app/Contents/Info.plist", YES, context);

    context = @"path enumerator";
    NSMutableSet *paths = [NSMutableSet set];
    NSString *path;
    NSDirectoryEnumerator *pathEnumerator = [fm enumeratorAtPath:root];
    while ((path = [pathEnumerator nextObject]) != nil)
        [paths addObject:path];
    checkSeen(paths, @"App.app/Contents/Info.plist", YES, context);
    checkSeen(paths, @"Bit/inner", YES, context);

    [fm removeItemAtPath:root error:NULL];
    printf("%s\n", failures == 0 ? "ALL PASS" : "SOME FAILED");
    [pool drain];
    return failures == 0 ? 0 : 1;
}
