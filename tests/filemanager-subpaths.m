// Copyright (C) 2026 Lubos Dolezel
//
// -[NSFileManager subpathsOfDirectoryAtPath:error:], -subpathsAtPath: and -enumeratorAtPath: report
// every descendant as a path relative to the directory asked about ("b/d/e.txt", not "e.txt"),
// include hidden entries, list a symbolic link to a directory without entering it, give the nesting
// level of the entry last returned, and skip the contents of one directory on request.
// Runs unchanged on macOS. The order of the entries is not specified, so lists are compared sorted.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static int failures;
#define CHECK(cond, label) do { if (!(cond)) { printf("FAIL %s (line %d)\n", label, __LINE__); failures++; } } while (0)

static void put(NSString *path, NSString *text)
{
    [text writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

static NSArray *sorted(NSArray *a)
{
    return [a sortedArrayUsingSelector:@selector(compare:)];
}

static void checkList(NSArray *got, NSArray *expected, const char *label)
{
    if (![sorted(got) isEqualToArray:sorted(expected)]) {
        printf("FAIL %s: got %s\n", label, [[got description] UTF8String]);
        failures++;
    }
}

int main(void)
{
    @autoreleasepool {
        char tmpl[] = "/tmp/fm-subpaths-XXXXXX";
        NSString *root = [NSString stringWithUTF8String:mkdtemp(tmpl)];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *d in @[@"b/d", @"emp", @".hid", @"Zed/q"])
            [fm createDirectoryAtPath:[root stringByAppendingPathComponent:d] withIntermediateDirectories:YES attributes:nil error:NULL];
        for (NSString *f in @[@"a", @"b/c", @"b/d/e.txt", @".hid/x", @"Zed/q/r", @"f"])
            put([root stringByAppendingPathComponent:f], @"x");
        [fm createSymbolicLinkAtPath:[root stringByAppendingPathComponent:@"lnk"] withDestinationPath:@"b" error:NULL];

        NSArray *all = @[@"Zed", @"Zed/q", @"Zed/q/r", @"a", @"f", @"emp", @".hid", @".hid/x", @"lnk", @"b", @"b/c", @"b/d", @"b/d/e.txt"];

        NSError *e = nil;
        NSArray *a = [fm subpathsOfDirectoryAtPath:root error:&e];
        CHECK(a != nil && e == nil, "subpathsOfDirectoryAtPath succeeds");
        checkList(a, all, "subpathsOfDirectoryAtPath");
        checkList([fm subpathsAtPath:root], all, "subpathsAtPath");
        checkList([[fm enumeratorAtPath:root] allObjects], all, "enumeratorAtPath allObjects");

        // Below a subdirectory, paths are relative to that subdirectory.
        checkList([fm subpathsOfDirectoryAtPath:[root stringByAppendingPathComponent:@"b"] error:NULL], @[@"c", @"d", @"d/e.txt"], "subpaths of a subdirectory");

        // The level of the entry returned last.
        NSDirectoryEnumerator *en = [fm enumeratorAtPath:root];
        NSString *s;
        int levelsOk = 1, seen = 0;
        while ((s = [en nextObject])) {
            seen++;
            if ([en level] != [[s pathComponents] count]) {
                printf("FAIL level of %s is %lu\n", [s UTF8String], (unsigned long)[en level]);
                levelsOk = 0;
            }
        }
        CHECK(levelsOk && seen == (int)[all count], "level follows the nesting");

        // skipDescendants skips what is inside the directory just returned, only.
        en = [fm enumeratorAtPath:root];
        NSMutableArray *got = [NSMutableArray array];
        while ((s = [en nextObject])) {
            [got addObject:s];
            if ([s isEqualToString:@"b"] || [s isEqualToString:@"Zed/q"])
                [en skipDescendants];
        }
        checkList(got, @[@"Zed", @"Zed/q", @"a", @"f", @"emp", @".hid", @".hid/x", @"lnk", @"b"], "skipDescendants");

        // Nothing at the path: no list (an enumerator has nothing to return).
        NSString *missing = [root stringByAppendingPathComponent:@"nosuch"];
        CHECK([fm subpathsAtPath:missing] == nil, "subpathsAtPath of a missing path is nil");
        CHECK([fm subpathsOfDirectoryAtPath:missing error:&e] == nil && e != nil, "subpathsOfDirectoryAtPath of a missing path fails");

        [fm removeItemAtPath:root error:NULL];
        printf(failures ? "FAILED (%d)\n" : "PASSED\n", failures);
    }
    return failures != 0;
}
