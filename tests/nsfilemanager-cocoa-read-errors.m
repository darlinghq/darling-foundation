// Copyright (C) 2026 Lubos Dolezel
//
// Errors of the NSFileManager reads that fail with an NSError: contentsOfDirectoryAtPath:,
// contentsOfDirectoryAtURL:..., subpathsOfDirectoryAtPath:, attributesOfItemAtPath: and
// destinationOfSymbolicLinkAtPath:. They are NSCocoaErrorDomain errors (NSFileReadNoSuchFileError,
// NSFileReadNoPermissionError, NSFileReadUnknownError) with the failing path and, as
// NSUnderlyingErrorKey, the errno as an NSPOSIXErrorDomain error; a missing directory listed by
// path has an NSOSStatusErrorDomain error (-43) underneath. Expected codes and keys are the black-box
// observations of macOS 10.14.4 and 26.7.3 kept in mac-probes/fileerrors (probe.m, cases A1-A18,
// O2-O6, A40-A45). Where the two differ the 10.14.4 result is followed. Runs as an ordinary user:
// directories of mode 0 give the permission errors.
#import <Foundation/Foundation.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

static int failures;
static NSString *D;
static NSFileManager *FM;

static NSString *P(NSString *rel) { return [D stringByAppendingPathComponent:rel]; }
static void mkd(NSString *rel, mode_t m) { mkdir([P(rel) fileSystemRepresentation], 0700); chmod([P(rel) fileSystemRepresentation], m); }
static void mkf(NSString *rel, const char *content)
{
    FILE *f = fopen([P(rel) fileSystemRepresentation], "w");
    if (f) { fputs(content, f); fclose(f); }
}

static NSString *keysOf(NSError *e)
{
    return [[[[e userInfo] allKeys] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","];
}

// The call must have failed (result == nil) with an error of the code, the underlying error of the
// domain and code (a NULL domain: none), exactly the userInfo keys (sorted, comma separated), the
// path in NSFilePath and, when url is not nil, that URL string in NSURL.
static void expect(const char *label, id result, NSError *e, NSInteger code, NSString *domain, NSInteger underlyingCode, NSString *keys, NSString *path, NSString *url)
{
    NSError *u = [[e userInfo] objectForKey:NSUnderlyingErrorKey];
    BOOL good = result == nil && e != nil && [[e domain] isEqualToString:NSCocoaErrorDomain] && [e code] == code;
    if (domain != nil)
        good = good && u != nil && [[u domain] isEqualToString:domain] && [u code] == underlyingCode;
    else
        good = good && u == nil;
    good = good && [keysOf(e) isEqualToString:keys];
    good = good && [[[e userInfo] objectForKey:NSFilePathErrorKey] isEqualToString:path];
    if (url != nil)
        good = good && [[[[e userInfo] objectForKey:NSURLErrorKey] absoluteString] isEqualToString:url];
    id variant = [[e userInfo] objectForKey:@"NSUserStringVariant"];
    if (variant != nil)
        good = good && [variant isEqual:@[ @"Folder" ]];
    if (!good)
    {
        printf("FAIL %s: result=%d error=%s/%ld keys=[%s] path=%s underlying=%s/%ld\n", label, result != nil,
            [[e domain] UTF8String], (long) [e code], [keysOf(e) UTF8String],
            [[[[e userInfo] objectForKey:NSFilePathErrorKey] description] UTF8String],
            [[u domain] UTF8String], (long) [u code]);
        failures++;
    }
}

#define EXPECT(label, call, code, domain, ucode, keys, path, url) do { NSError *e = nil; id r = (call); expect(label, r, e, code, domain, ucode, keys, path, url); } while (0)

#define PATHKEYS @"NSFilePath,NSUnderlyingError"
#define URLKEYS @"NSFilePath,NSURL,NSUnderlyingError"
#define FOLDERKEYS @"NSFilePath,NSUnderlyingError,NSUserStringVariant"
#define FOLDERURLKEYS @"NSFilePath,NSURL,NSUnderlyingError,NSUserStringVariant"

int main(void)
{
    @autoreleasepool {
        char tmpl[] = "/tmp/fm-cocoa-read-errors-XXXXXX";
        D = [NSString stringWithUTF8String:mkdtemp(tmpl)];
        FM = [NSFileManager defaultManager];
        char real[PATH_MAX];
        NSString *R = [NSString stringWithUTF8String:realpath([D fileSystemRepresentation], real)];

        mkd(@"rw", 0755); mkd(@"rw/edir", 0755); mkf(@"file", "x");
        mkd(@"dirnoperm", 0755); mkf(@"dirnoperm/inner", "i"); chmod([P(@"dirnoperm") fileSystemRepresentation], 0000);
        symlink("nowhere", [P(@"rw/dangling") fileSystemRepresentation]);
        symlink("file", [P(@"rw/filelink") fileSystemRepresentation]);
        NSString *noperm = [R stringByAppendingPathComponent:@"dirnoperm"];
        NSString *nopermURL = [@"file://" stringByAppendingString:noperm];

        // contentsOfDirectoryAtPath:
        EXPECT("list a missing directory", [FM contentsOfDirectoryAtPath:P(@"gone") error:&e], NSFileReadNoSuchFileError, NSOSStatusErrorDomain, -43, FOLDERKEYS, P(@"gone"), nil);
        EXPECT("list below a file", [FM contentsOfDirectoryAtPath:P(@"file/x") error:&e], NSFileReadNoSuchFileError, NSOSStatusErrorDomain, -43, FOLDERKEYS, P(@"file/x"), nil);
        EXPECT("list a dangling link", [FM contentsOfDirectoryAtPath:P(@"rw/dangling") error:&e], NSFileReadNoSuchFileError, NSOSStatusErrorDomain, -43, FOLDERKEYS, P(@"rw/dangling"), nil);
        EXPECT("list a link to a file", [FM contentsOfDirectoryAtPath:P(@"rw/filelink") error:&e], NSFileReadNoSuchFileError, NSOSStatusErrorDomain, -43, FOLDERKEYS, P(@"rw/filelink"), nil);
        EXPECT("list the empty path", [FM contentsOfDirectoryAtPath:@"" error:&e], NSFileReadNoSuchFileError, NSOSStatusErrorDomain, -43, FOLDERKEYS, @"", nil);
        EXPECT("list a directory of mode 0", [FM contentsOfDirectoryAtPath:P(@"dirnoperm") error:&e], NSFileReadNoPermissionError, NSPOSIXErrorDomain, 13, FOLDERURLKEYS, noperm, nopermURL);
        EXPECT("list a file", [FM contentsOfDirectoryAtPath:P(@"file") error:&e], NSFileReadUnknownError, NSPOSIXErrorDomain, 20, FOLDERURLKEYS, P(@"file"), [[@"file://" stringByAppendingString:P(@"file")] stringByAppendingString:@"/"]);

        // contentsOfDirectoryAtURL:
        EXPECT("list a missing directory by URL", [FM contentsOfDirectoryAtURL:[NSURL fileURLWithPath:P(@"gone")] includingPropertiesForKeys:nil options:0 error:&e], NSFileReadNoSuchFileError, NSPOSIXErrorDomain, 2, URLKEYS, P(@"gone"), [@"file://" stringByAppendingString:P(@"gone")]);
        EXPECT("list a directory of mode 0 by URL", [FM contentsOfDirectoryAtURL:[NSURL fileURLWithPath:P(@"dirnoperm")] includingPropertiesForKeys:nil options:0 error:&e], NSFileReadNoPermissionError, NSPOSIXErrorDomain, 13, URLKEYS, noperm, nopermURL);
        EXPECT("list a file by URL", [FM contentsOfDirectoryAtURL:[NSURL fileURLWithPath:P(@"file")] includingPropertiesForKeys:nil options:0 error:&e], NSFileReadUnknownError, NSPOSIXErrorDomain, 20, URLKEYS, P(@"file"), [@"file://" stringByAppendingString:P(@"file")]);

        // subpathsOfDirectoryAtPath:
        EXPECT("subpaths of a missing directory", [FM subpathsOfDirectoryAtPath:P(@"gone") error:&e], NSFileReadNoSuchFileError, NSPOSIXErrorDomain, 2, PATHKEYS, P(@"gone"), nil);
        EXPECT("subpaths of a directory of mode 0", [FM subpathsOfDirectoryAtPath:P(@"dirnoperm") error:&e], NSFileReadNoPermissionError, NSPOSIXErrorDomain, 13, PATHKEYS, P(@"dirnoperm"), nil);
        EXPECT("subpaths below a file", [FM subpathsOfDirectoryAtPath:P(@"file/x") error:&e], NSFileReadUnknownError, NSPOSIXErrorDomain, 20, PATHKEYS, P(@"file/x"), nil);
        EXPECT("list below a file by URL", [FM contentsOfDirectoryAtURL:[NSURL fileURLWithPath:P(@"file/x")] includingPropertiesForKeys:nil options:0 error:&e], NSFileReadUnknownError, NSPOSIXErrorDomain, 20, URLKEYS, P(@"file/x"), [@"file://" stringByAppendingString:P(@"file/x")]);

        // attributesOfItemAtPath:
        EXPECT("attributes of a missing item", [FM attributesOfItemAtPath:P(@"gone") error:&e], NSFileReadNoSuchFileError, NSPOSIXErrorDomain, 2, PATHKEYS, P(@"gone"), nil);
        EXPECT("attributes below a directory of mode 0", [FM attributesOfItemAtPath:P(@"dirnoperm/inner") error:&e], NSFileReadNoPermissionError, NSPOSIXErrorDomain, 13, PATHKEYS, P(@"dirnoperm/inner"), nil);
        EXPECT("attributes below a file", [FM attributesOfItemAtPath:P(@"file/x") error:&e], NSFileReadUnknownError, NSPOSIXErrorDomain, 20, PATHKEYS, P(@"file/x"), nil);
        EXPECT("attributes of the empty path", [FM attributesOfItemAtPath:@"" error:&e], NSFileReadUnknownError, nil, 0, @"NSFilePath", @"", nil);

        // destinationOfSymbolicLinkAtPath:
        EXPECT("destination of a missing item", [FM destinationOfSymbolicLinkAtPath:P(@"gone") error:&e], NSFileReadNoSuchFileError, NSPOSIXErrorDomain, 2, PATHKEYS, P(@"gone"), nil);
        EXPECT("destination below a directory of mode 0", [FM destinationOfSymbolicLinkAtPath:P(@"dirnoperm/inner") error:&e], NSFileReadNoPermissionError, NSPOSIXErrorDomain, 13, PATHKEYS, P(@"dirnoperm/inner"), nil);
        EXPECT("destination of a directory", [FM destinationOfSymbolicLinkAtPath:P(@"rw/edir") error:&e], NSFileReadUnknownError, NSPOSIXErrorDomain, 22, PATHKEYS, P(@"rw/edir"), nil);
        EXPECT("destination below a file", [FM destinationOfSymbolicLinkAtPath:P(@"file/x") error:&e], NSFileReadUnknownError, NSPOSIXErrorDomain, 20, PATHKEYS, P(@"file/x"), nil);

        // what works still works, and passing no error pointer is fine
        {
            NSError *e = nil;
            NSArray *names = [FM contentsOfDirectoryAtPath:P(@"rw") error:&e];
            if (![[names sortedArrayUsingSelector:@selector(compare:)] isEqual:@[ @"dangling", @"edir", @"filelink" ]] || e != nil) { printf("FAIL listing a directory\n"); failures++; }
            if ([FM attributesOfItemAtPath:P(@"rw/dangling") error:&e] == nil || e != nil) { printf("FAIL attributes of a dangling link\n"); failures++; }
            if (![[FM destinationOfSymbolicLinkAtPath:P(@"rw/dangling") error:&e] isEqualToString:@"nowhere"] || e != nil) { printf("FAIL destination of a dangling link\n"); failures++; }
            if (![[[FM subpathsOfDirectoryAtPath:P(@"rw") error:&e] sortedArrayUsingSelector:@selector(compare:)] isEqual:@[ @"dangling", @"edir", @"filelink" ]]) { printf("FAIL subpaths\n"); failures++; }
            // an item that is not a directory has no sub-paths; that is not an error
            if (![[FM subpathsOfDirectoryAtPath:P(@"file") error:&e] isEqual:@[]] || ![[FM subpathsOfDirectoryAtPath:P(@"rw/dangling") error:&e] isEqual:@[]] || e != nil) { printf("FAIL subpaths of an item that is not a directory\n"); failures++; }
            if ([FM contentsOfDirectoryAtPath:P(@"gone") error:NULL] != nil || [FM attributesOfItemAtPath:P(@"gone") error:NULL] != nil
                || [FM destinationOfSymbolicLinkAtPath:P(@"gone") error:NULL] != nil || [FM subpathsOfDirectoryAtPath:P(@"gone") error:NULL] != nil
                || [FM contentsAtPath:P(@"gone")] != nil)
            { printf("FAIL failures without an error pointer\n"); failures++; }
        }

        chmod([P(@"dirnoperm") fileSystemRepresentation], 0755);
        [FM removeItemAtPath:D error:NULL];
        printf(failures ? "FAIL (%d)\n" : "PASS\n", failures);
    }
    return failures != 0;
}
