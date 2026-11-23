// Copyright (C) 2026 Lubos Dolezel
//
// Errors of NSFileManager create, copy, move, link and remove calls and of the NSData and NSString
// file writes: NSCocoaErrorDomain errors (NSFileWriteNoPermissionError, NSFileWriteFileExistsError,
// ...) whose userInfo names the path and carries the errno as an NSPOSIXErrorDomain error in
// NSUnderlyingErrorKey. Expected codes and keys are the black-box observations of macOS 10.14.4
// and 26.7.3 kept in mac-probes/fileerrors (probe.m and the out.*.txt results). Runs as an
// ordinary user: directories with mode 0555 give the permission errors.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

static int failures;
static NSString *D;
static NSFileManager *FM;

static NSString *P(NSString *rel) { return [D stringByAppendingPathComponent:rel]; }
static NSURL *U(NSString *rel) { return [NSURL fileURLWithPath:P(rel)]; }
static void mkd(NSString *rel, mode_t m) { mkdir([P(rel) fileSystemRepresentation], 0700); chmod([P(rel) fileSystemRepresentation], m); }
static void mkf(NSString *rel, const char *content, mode_t m)
{
    FILE *f = fopen([P(rel) fileSystemRepresentation], "w");
    if (f) { fputs(content, f); fclose(f); }
    chmod([P(rel) fileSystemRepresentation], m);
}

static NSString *keysOf(NSError *e)
{
    return [[[[e userInfo] allKeys] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","];
}

// ok == NO and the error must be an NSCocoaErrorDomain error with the code, the POSIX error underneath
// (0: none) and exactly the userInfo keys (comma separated, sorted).
static void expect(const char *label, BOOL ok, NSError *e, NSInteger code, int posix, NSString *keys, NSString *path)
{
    BOOL good = !ok && e != nil && [[e domain] isEqualToString:NSCocoaErrorDomain] && [e code] == code;
    NSError *u = [[e userInfo] objectForKey:NSUnderlyingErrorKey];
    if (posix != 0)
        good = good && u != nil && [[u domain] isEqualToString:NSPOSIXErrorDomain] && [u code] == posix;
    else
        good = good && u == nil;
    good = good && [keysOf(e) isEqualToString:keys];
    if (good && path != nil)
        good = [[[e userInfo] objectForKey:NSFilePathErrorKey] isEqualToString:P(path)];
    if (!good)
    {
        printf("FAIL %s: ok=%d error=%s/%ld keys=[%s] underlying=%s/%ld\n", label, ok,
            [[e domain] UTF8String], (long) [e code], [keysOf(e) UTF8String],
            [[u domain] UTF8String], (long) [u code]);
        failures++;
    }
}

#define EXPECT(label, call, code, posix, keys, path) do { NSError *e = nil; BOOL ok = (call); expect(label, ok, e, code, posix, keys, path); } while (0)

#define PATHKEYS @"NSFilePath,NSUnderlyingError"
#define XFER @"NSDestinationFilePath,NSFilePath,NSSourceFilePathErrorKey,NSUnderlyingError,NSUserStringVariant"

int main(void)
{
    @autoreleasepool {
        char tmpl[] = "/tmp/fm-cocoa-errors-XXXXXX";
        D = [NSString stringWithUTF8String:mkdtemp(tmpl)];
        FM = [NSFileManager defaultManager];
        NSData *data = [@"hello" dataUsingEncoding:NSUTF8StringEncoding];

        mkd(@"ro", 0755); mkd(@"rw", 0755); mkd(@"ro/sub", 0755);
        mkf(@"file", "x", 0644); mkf(@"noread", "secret", 0000); mkd(@"full", 0755); mkf(@"full/a", "a", 0644);
        mkd(@"dirnoperm", 0755); mkf(@"dirnoperm/inner", "i", 0644); chmod([P(@"dirnoperm") fileSystemRepresentation], 0000);
        mkf(@"rw/exists", "e", 0644); mkd(@"rw/edir", 0755);
        symlink("nowhere", [P(@"rw/dangling") fileSystemRepresentation]);
        chmod([P(@"ro") fileSystemRepresentation], 0555);

        // create directory
        EXPECT("create in a read-only parent", [FM createDirectoryAtPath:P(@"ro/new") withIntermediateDirectories:NO attributes:nil error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"ro/new");
        EXPECT("create where a directory exists", [FM createDirectoryAtPath:P(@"rw/edir") withIntermediateDirectories:NO attributes:nil error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/edir");
        EXPECT("create where a file exists", [FM createDirectoryAtPath:P(@"rw/exists") withIntermediateDirectories:NO attributes:nil error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/exists");
        EXPECT("create with intermediates where a file exists", [FM createDirectoryAtPath:P(@"rw/exists") withIntermediateDirectories:YES attributes:nil error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/exists");
        EXPECT("create below a missing parent", [FM createDirectoryAtPath:P(@"rw/missing/x") withIntermediateDirectories:NO attributes:nil error:&e], NSFileNoSuchFileError, 2, PATHKEYS, @"rw/missing/x");
        {
            struct stat st;
            if (stat([P(@"rw/missing") fileSystemRepresentation], &st) == 0) { printf("FAIL a failed create left the parent behind\n"); failures++; }
        }
        EXPECT("create below a file", [FM createDirectoryAtPath:P(@"rw/exists/x") withIntermediateDirectories:NO attributes:nil error:&e], NSFileWriteUnknownError, 20, PATHKEYS, @"rw/exists/x");
        EXPECT("create with intermediates below a file", [FM createDirectoryAtPath:P(@"rw/exists/x") withIntermediateDirectories:YES attributes:nil error:&e], NSFileWriteUnknownError, 20, PATHKEYS, @"rw/exists");
        EXPECT("create with intermediates in a read-only parent", [FM createDirectoryAtPath:P(@"ro/a/b") withIntermediateDirectories:YES attributes:nil error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"ro/a/b");
        EXPECT("create in a parent of mode 0", [FM createDirectoryAtPath:P(@"dirnoperm/a") withIntermediateDirectories:NO attributes:nil error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"dirnoperm/a");
        EXPECT("create by URL in a read-only parent", [FM createDirectoryAtURL:U(@"ro/new2") withIntermediateDirectories:NO attributes:nil error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"ro/new2");
        EXPECT("create by URL where it exists", [FM createDirectoryAtURL:U(@"rw/edir") withIntermediateDirectories:NO attributes:nil error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/edir");
        EXPECT("create by URL below a missing parent", [FM createDirectoryAtURL:U(@"rw/missing/x") withIntermediateDirectories:NO attributes:nil error:&e], NSFileNoSuchFileError, 2, PATHKEYS, @"rw/missing/x");
        EXPECT("create over a dangling link", [FM createDirectoryAtPath:P(@"rw/dangling") withIntermediateDirectories:NO attributes:nil error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/dangling");
        {
            NSError *e = nil;
            if (![FM createDirectoryAtPath:P(@"rw/edir") withIntermediateDirectories:YES attributes:nil error:&e]) { printf("FAIL create with intermediates over a directory is a success\n"); failures++; }
        }

        // symbolic links
        EXPECT("symlink where a file exists", [FM createSymbolicLinkAtPath:P(@"rw/exists") withDestinationPath:@"file" error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/exists");
        EXPECT("symlink in a read-only parent", [FM createSymbolicLinkAtPath:P(@"ro/l") withDestinationPath:@"file" error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"ro/l");
        EXPECT("symlink below a missing parent", [FM createSymbolicLinkAtPath:P(@"rw/missing/l") withDestinationPath:@"file" error:&e], NSFileNoSuchFileError, 2, PATHKEYS, @"rw/missing/l");
        EXPECT("symlink by URL where a file exists", [FM createSymbolicLinkAtURL:U(@"rw/exists") withDestinationURL:U(@"file") error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/exists");

        // hard links
        EXPECT("link onto an existing file", [FM linkItemAtPath:P(@"file") toPath:P(@"rw/exists") error:&e], NSFileWriteFileExistsError, 17, XFER, @"file");
        EXPECT("link a missing source", [FM linkItemAtPath:P(@"nosuch") toPath:P(@"rw/hl") error:&e], NSFileReadNoSuchFileError, 2, PATHKEYS, @"nosuch");
        EXPECT("link into a read-only parent", [FM linkItemAtPath:P(@"file") toPath:P(@"ro/hl") error:&e], NSFileWriteNoPermissionError, 13, XFER, @"file");

        // copy
        EXPECT("copy a missing source", [FM copyItemAtPath:P(@"nosuch") toPath:P(@"rw/cp") error:&e], NSFileReadNoSuchFileError, 2, PATHKEYS, @"nosuch");
        EXPECT("copy onto a file", [FM copyItemAtPath:P(@"file") toPath:P(@"rw/exists") error:&e], NSFileWriteFileExistsError, 17, XFER, @"file");
        EXPECT("copy onto a directory", [FM copyItemAtPath:P(@"file") toPath:P(@"rw/edir") error:&e], NSFileWriteFileExistsError, 17, XFER, @"file");
        EXPECT("copy into a read-only parent", [FM copyItemAtPath:P(@"file") toPath:P(@"ro/cp") error:&e], NSFileWriteNoPermissionError, 13, XFER, @"file");
        EXPECT("copy below a missing parent", [FM copyItemAtPath:P(@"file") toPath:P(@"rw/missing/cp") error:&e], NSFileNoSuchFileError, 2, XFER, @"file");
        {
            struct stat st;
            if (stat([P(@"rw/missing") fileSystemRepresentation], &st) == 0) { printf("FAIL a failed copy created the destination's parent\n"); failures++; }
        }
        EXPECT("copy an unreadable file", [FM copyItemAtPath:P(@"noread") toPath:P(@"rw/cp6") error:&e], NSFileWriteNoPermissionError, 13, XFER, @"noread");
        EXPECT("copy a directory into a read-only parent", [FM copyItemAtPath:P(@"full") toPath:P(@"ro/cpdir") error:&e], NSFileWriteNoPermissionError, 13, XFER, @"full");
        EXPECT("copy by URL a missing source", [FM copyItemAtURL:U(@"nosuch") toURL:U(@"rw/cp8") error:&e], NSFileReadNoSuchFileError, 2, PATHKEYS, @"nosuch");
        EXPECT("copy by URL onto a file", [FM copyItemAtURL:U(@"file") toURL:U(@"rw/exists") error:&e], NSFileWriteFileExistsError, 17, XFER, @"file");
        EXPECT("copy by URL into a read-only parent", [FM copyItemAtURL:U(@"file") toURL:U(@"ro/cp10") error:&e], NSFileWriteNoPermissionError, 13, XFER, @"file");
        EXPECT("copy an unreadable directory", [FM copyItemAtPath:P(@"dirnoperm") toPath:P(@"rw/cp12") error:&e], NSFileWriteNoPermissionError, 13, XFER, @"dirnoperm");

        // move
        EXPECT("move a missing source", [FM moveItemAtPath:P(@"nosuch") toPath:P(@"rw/mv") error:&e], NSFileNoSuchFileError, 2, XFER, @"nosuch");
        EXPECT("move onto a file", [FM moveItemAtPath:P(@"file") toPath:P(@"rw/exists") error:&e], NSFileWriteFileExistsError, 17, XFER, @"file");
        EXPECT("move into a read-only parent", [FM moveItemAtPath:P(@"file") toPath:P(@"ro/mv") error:&e], NSFileWriteNoPermissionError, 13, XFER, @"file");
        EXPECT("move below a missing parent", [FM moveItemAtPath:P(@"file") toPath:P(@"rw/missing/mv") error:&e], NSFileNoSuchFileError, 2, XFER, @"file");
        EXPECT("move out of a read-only parent", [FM moveItemAtPath:P(@"ro/sub") toPath:P(@"rw/mv5") error:&e], NSFileWriteNoPermissionError, 13, XFER, @"ro/sub");
        EXPECT("move by URL a missing source", [FM moveItemAtURL:U(@"nosuch") toURL:U(@"rw/mv6") error:&e], NSFileNoSuchFileError, 2, XFER, @"nosuch");
        EXPECT("move by URL onto a file", [FM moveItemAtURL:U(@"file") toURL:U(@"rw/exists") error:&e], NSFileWriteFileExistsError, 17, XFER, @"file");
        EXPECT("move by URL into a read-only parent", [FM moveItemAtURL:U(@"file") toURL:U(@"ro/mv8") error:&e], NSFileWriteNoPermissionError, 13, XFER, @"file");

        // remove
        NSString *RM = @"NSFilePath,NSUnderlyingError,NSUserStringVariant";
        EXPECT("remove a missing item", [FM removeItemAtPath:P(@"nosuch") error:&e], NSFileNoSuchFileError, 2, RM, @"nosuch");
        EXPECT("remove from a read-only parent", [FM removeItemAtPath:P(@"ro/sub") error:&e], NSFileWriteNoPermissionError, 13, RM, @"ro/sub");
        EXPECT("remove by URL a missing item", [FM removeItemAtURL:U(@"nosuch") error:&e], NSFileNoSuchFileError, 2, RM, @"nosuch");
        EXPECT("remove by URL from a read-only parent", [FM removeItemAtURL:U(@"ro/sub") error:&e], NSFileWriteNoPermissionError, 13, RM, @"ro/sub");
        EXPECT("remove a directory that cannot be read", [FM removeItemAtPath:P(@"dirnoperm") error:&e], NSFileWriteNoPermissionError, 13, RM, @"dirnoperm");

        // NSData
        EXPECT("data write into a read-only parent", [data writeToFile:P(@"ro/d") options:0 error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"ro/d");
        EXPECT("data write below a missing parent", [data writeToFile:P(@"rw/missing/d") options:0 error:&e], NSFileNoSuchFileError, 2, PATHKEYS, @"rw/missing/d");
        EXPECT("data write onto a directory", [data writeToFile:P(@"rw/edir") options:0 error:&e], NSFileWriteUnknownError, 21, PATHKEYS, @"rw/edir");
        EXPECT("data write without overwriting", [data writeToFile:P(@"rw/exists") options:NSDataWritingWithoutOverwriting error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/exists");
        EXPECT("data write without overwriting, atomic", [data writeToFile:P(@"rw/exists") options:NSDataWritingWithoutOverwriting | NSDataWritingAtomic error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/exists");
        EXPECT("data write without overwriting over a dangling link", [data writeToFile:P(@"rw/dangling") options:NSDataWritingWithoutOverwriting error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/dangling");
        // QUIRK test: atomic write into an unwritable folder carries the Folder variant (a string)
        {
            NSError *e = nil;
            BOOL ok = [data writeToFile:P(@"ro/d") options:NSDataWritingAtomic error:&e];
            expect("atomic write into an unwritable folder carries the Folder variant", ok, e, NSFileWriteNoPermissionError, 13, @"NSFilePath,NSUnderlyingError,NSUserStringVariant", @"ro/d");
            if ([[[e userInfo] objectForKey:@"NSUserStringVariant"] isKindOfClass:[NSString class]] == NO || ![[[e userInfo] objectForKey:@"NSUserStringVariant"] isEqual:@"Folder"])
            { printf("FAIL the Folder variant is the string Folder\n"); failures++; }
        }
        EXPECT("atomic data write below a missing parent", [data writeToFile:P(@"rw/missing/d") options:NSDataWritingAtomic error:&e], NSFileNoSuchFileError, 2, @"NSFilePath,NSUnderlyingError,NSUserStringVariant", @"rw/missing/d");
        EXPECT("atomic data write onto a directory", [data writeToFile:P(@"rw/edir") options:NSDataWritingAtomic error:&e], NSFileWriteUnknownError, 21, PATHKEYS, @"rw/edir");
        EXPECT("data write over an unwritable file", [data writeToFile:P(@"noread") options:0 error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"noread");
        EXPECT("data write by URL into a read-only parent", [data writeToURL:U(@"ro/d9") options:0 error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"ro/d9");
        EXPECT("data write by URL below a missing parent", [data writeToURL:U(@"rw/missing/d") options:0 error:&e], NSFileNoSuchFileError, 2, PATHKEYS, @"rw/missing/d");
        EXPECT("data write by URL without overwriting", [data writeToURL:U(@"rw/exists") options:NSDataWritingWithoutOverwriting error:&e], NSFileWriteFileExistsError, 17, PATHKEYS, @"rw/exists");
        EXPECT("data write by URL onto a directory", [data writeToURL:U(@"rw/edir") options:0 error:&e], NSFileWriteUnknownError, 21, PATHKEYS, @"rw/edir");
        EXPECT("data write by URL, atomic, into a read-only parent", [data writeToURL:U(@"ro/d13") options:NSDataWritingAtomic error:&e], NSFileWriteNoPermissionError, 13, @"NSFilePath,NSUnderlyingError,NSUserStringVariant", @"ro/d13");
        {
            NSError *e = nil;
            NSURL *http = [NSURL URLWithString:@"http://localhost/x"];
            BOOL ok = [data writeToURL:http options:0 error:&e];
            expect("data write to an http URL", ok, e, NSFileWriteUnsupportedSchemeError, 0, @"NSURL", nil);
            if (![[[e userInfo] objectForKey:NSURLErrorKey] isEqual:http]) { printf("FAIL the URL of the unsupported scheme error\n"); failures++; }
        }
        EXPECT("mutable data write into a read-only parent", [[NSMutableData dataWithData:data] writeToFile:P(@"ro/d16") options:0 error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"ro/d16");

        // NSString
        EXPECT("string write into a read-only parent", [@"hello" writeToFile:P(@"ro/s") atomically:NO encoding:NSUTF8StringEncoding error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"ro/s");
        EXPECT("string write below a missing parent", [@"hello" writeToFile:P(@"rw/missing/s") atomically:NO encoding:NSUTF8StringEncoding error:&e], NSFileNoSuchFileError, 2, PATHKEYS, @"rw/missing/s");
        EXPECT("string write by URL into a read-only parent", [@"hello" writeToURL:U(@"ro/s4") atomically:NO encoding:NSUTF8StringEncoding error:&e], NSFileWriteNoPermissionError, 13, PATHKEYS, @"ro/s4");
        EXPECT("string write onto a directory", [@"hello" writeToFile:P(@"rw/edir") atomically:NO encoding:NSUTF8StringEncoding error:&e], NSFileWriteUnknownError, 21, PATHKEYS, @"rw/edir");
        {
            NSError *e = nil;
            BOOL ok = [@"héllo" writeToFile:P(@"rw/s6") atomically:NO encoding:NSASCIIStringEncoding error:&e];
            expect("string write in an encoding that cannot hold it", ok, e, NSFileWriteInapplicableStringEncodingError, 0, @"NSFilePath,NSStringEncoding", @"rw/s6");
            if ([[[e userInfo] objectForKey:NSStringEncodingErrorKey] unsignedIntegerValue] != NSASCIIStringEncoding) { printf("FAIL the encoding in the error\n"); failures++; }
        }

        // successes still work
        {
            NSError *e = nil;
            if (![data writeToFile:P(@"rw/new") options:0 error:&e] || ![FM copyItemAtPath:P(@"rw/new") toPath:P(@"rw/copy") error:&e]
                || ![FM moveItemAtPath:P(@"rw/copy") toPath:P(@"rw/moved") error:&e] || ![FM removeItemAtPath:P(@"rw/moved") error:&e]
                || ![FM createDirectoryAtPath:P(@"rw/a/b/c") withIntermediateDirectories:YES attributes:nil error:&e])
            { printf("FAIL successful operations failed: %s\n", [[e description] UTF8String]); failures++; }
        }

        chmod([P(@"ro") fileSystemRepresentation], 0755);
        chmod([P(@"dirnoperm") fileSystemRepresentation], 0755);
        chmod([P(@"noread") fileSystemRepresentation], 0644);
        [FM removeItemAtPath:D error:NULL];
        printf(failures ? "FAIL (%d)\n" : "PASS\n", failures);
    }
    return failures != 0;
}
