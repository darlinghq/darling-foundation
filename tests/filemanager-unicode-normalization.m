// Copyright (C) 2026 Lubos Dolezel
//
// NSFileManager finds a file whose name has non-ASCII characters by the precomposed and the
// decomposed spelling of the name, as on macOS (QUIRK in NSFileManager.m, observed on macOS
// 26.7.3). Creating a nested directory under a name that exists already must also succeed.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>

static int failures;
#define CHECK(cond, label) do { if (!(cond)) { printf("FAIL %s (line %d)\n", label, __LINE__); failures++; } } while (0)

static void lookups(NSFileManager *fm, NSString *base, NSString *name, const char *spelling)
{
    NSString *path = [base stringByAppendingPathComponent:name];
    BOOL isDir = NO;
    char label[200];

#define LABEL(text) (snprintf(label, sizeof label, "%s: %s", spelling, text), label)
    CHECK([fm fileExistsAtPath:path], LABEL("fileExistsAtPath:"));
    CHECK([fm fileExistsAtPath:path isDirectory:&isDir] && isDir, LABEL("fileExistsAtPath:isDirectory:"));
    CHECK([fm attributesOfItemAtPath:path error:NULL] != nil, LABEL("attributesOfItemAtPath:"));
    CHECK([fm contentsOfDirectoryAtPath:path error:NULL] != nil, LABEL("contentsOfDirectoryAtPath:"));
    CHECK([fm isReadableFileAtPath:path], LABEL("isReadableFileAtPath:"));
    CHECK([NSData dataWithContentsOfFile:[path stringByAppendingPathComponent:@"in.txt"]] != nil, LABEL("file inside"));
    CHECK([fm createFileAtPath:[path stringByAppendingPathComponent:@"created.txt"] contents:[NSData data] attributes:nil],
          LABEL("createFileAtPath: inside"));
    CHECK([fm fileExistsAtPath:[path stringByAppendingPathComponent:@"created.txt"]], LABEL("file created inside exists"));
}

int main(void)
{
    @autoreleasepool {
        char tmpl[] = "/tmp/fm-unicode-XXXXXX";
        NSString *base = [NSString stringWithUTF8String:mkdtemp(tmpl)];
        NSFileManager *fm = [NSFileManager defaultManager];

        NSArray *names = @[@"Příliš žluťoučký kůň", @"日本語フォルダ ダイアログ"];
        for (NSString *name in names) {
            NSString *nfc = [name precomposedStringWithCanonicalMapping];
            NSString *nfd = [name decomposedStringWithCanonicalMapping];
            NSString *path = [base stringByAppendingPathComponent:nfc];

            CHECK([fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL], "create with NFC");
            [@"x" writeToFile:[path stringByAppendingPathComponent:@"in.txt"] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
            lookups(fm, base, nfc, "NFC");
            lookups(fm, base, nfd, "NFD");

            // The nested directory under a name that exists already (extracting a second file into a
            // folder whose name has accents).
            NSError *error = nil;
            NSString *nested = [[base stringByAppendingPathComponent:nfc] stringByAppendingPathComponent:@"nested"];
            CHECK([fm createDirectoryAtPath:nested withIntermediateDirectories:YES attributes:nil error:&error], "create nested under existing (NFC)");
            nested = [[base stringByAppendingPathComponent:nfd] stringByAppendingPathComponent:@"nested2"];
            CHECK([fm createDirectoryAtPath:nested withIntermediateDirectories:YES attributes:nil error:&error], "create nested under existing (NFD)");
            CHECK([fm createDirectoryAtPath:nested withIntermediateDirectories:YES attributes:nil error:&error], "create the same directory again");

            CHECK([fm removeItemAtPath:path error:NULL], "remove with NFC");
            CHECK(![fm fileExistsAtPath:path], "removed (NFC)");
            CHECK(![fm fileExistsAtPath:[base stringByAppendingPathComponent:nfd]], "removed (NFD)");
        }

        // A file that exists only under the precomposed spelling (created by a program that writes
        // the bytes of the name as given) is found by that spelling.
        NSString *precomposed = [@"Příliš žluťoučký kůň.txt" precomposedStringWithCanonicalMapping];
        NSString *rawPath = [base stringByAppendingPathComponent:precomposed];
        int fd = open([rawPath UTF8String], O_WRONLY | O_CREAT, 0644);
        CHECK(fd >= 0, "create with the raw bytes");
        if (fd >= 0) {
            close(fd);
            CHECK([fm fileExistsAtPath:rawPath], "precomposed-only file exists");
            unlink([rawPath UTF8String]);
        }

        // An ASCII name is unaffected, and a missing name stays missing.
        CHECK(![fm fileExistsAtPath:[base stringByAppendingPathComponent:@"nonexistent-é"]], "missing name");
        CHECK([fm fileExistsAtPath:base], "ASCII path");
        rmdir([base fileSystemRepresentation]);
    }
    if (failures == 0)
        printf("PASS\n");
    return failures != 0;
}
