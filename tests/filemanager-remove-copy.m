// Copyright (C) 2026 Lubos Dolezel
//
// NSFileManager removeItemAtPath: / copyItemAtPath: and NSFileWrapper initWithURL:options:error:
// against the documented contracts (and mac-probes/mc16-fileerrors.m on macOS 27).
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

int main(void)
{
    @autoreleasepool {
        char tmpl[] = "/tmp/fm-remove-copy-XXXXXX";
        NSString *root = [NSString stringWithUTF8String:mkdtemp(tmpl)];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *e = nil;

        // A regular file is removed (nftw rejects a non-directory root).
        NSString *file = [root stringByAppendingPathComponent:@"file"];
        put(file, @"abc");
        CHECK([fm removeItemAtPath:file error:&e] && ![fm fileExistsAtPath:file], "remove a regular file");

        // A missing item: NSFileNoSuchFileError.
        e = nil;
        CHECK(![fm removeItemAtPath:file error:&e] && e.code == NSFileNoSuchFileError, "remove a missing item");

        // A symbolic link to a directory is removed, not followed.
        NSString *target = [root stringByAppendingPathComponent:@"target"];
        NSString *dir = [root stringByAppendingPathComponent:@"dir"];
        [fm createDirectoryAtPath:target withIntermediateDirectories:YES attributes:nil error:NULL];
        put([target stringByAppendingPathComponent:@"keep"], @"keep");
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
        symlink([target fileSystemRepresentation], [[dir stringByAppendingPathComponent:@"link"] fileSystemRepresentation]);
        CHECK([fm removeItemAtPath:dir error:&e] && ![fm fileExistsAtPath:dir], "remove a directory holding a link");
        CHECK([fm fileExistsAtPath:[target stringByAppendingPathComponent:@"keep"]], "link target tree survives");

        // Removing a link given directly removes the link only.
        NSString *link = [root stringByAppendingPathComponent:@"toplink"];
        symlink([target fileSystemRepresentation], [link fileSystemRepresentation]);
        CHECK([fm removeItemAtPath:link error:&e], "remove a symlink to a directory");
        CHECK([fm fileExistsAtPath:[target stringByAppendingPathComponent:@"keep"]], "target survives direct link removal");

        // Copying a tree: nested files, a symlink stays a symlink.
        NSString *src = [root stringByAppendingPathComponent:@"src"];
        [fm createDirectoryAtPath:[src stringByAppendingPathComponent:@"sub"] withIntermediateDirectories:YES attributes:nil error:NULL];
        put([src stringByAppendingPathComponent:@"sub/inner"], @"inner");
        symlink("sub/inner", [[src stringByAppendingPathComponent:@"rel"] fileSystemRepresentation]);
        NSString *copy = [root stringByAppendingPathComponent:@"copy"];
        CHECK([fm copyItemAtPath:src toPath:copy error:&e], "copy a directory tree");
        CHECK([[NSString stringWithContentsOfFile:[copy stringByAppendingPathComponent:@"sub/inner"] encoding:NSUTF8StringEncoding error:NULL] isEqual:@"inner"], "nested file copied");
        NSDictionary *a = [fm attributesOfItemAtPath:[copy stringByAppendingPathComponent:@"rel"] error:NULL];
        CHECK([a[NSFileType] isEqual:NSFileTypeSymbolicLink], "symlink copied as a symlink");

        // Copy onto an existing destination: NSFileWriteFileExistsError, destination untouched.
        put([copy stringByAppendingPathComponent:@"marker"], @"m");
        e = nil;
        CHECK(![fm copyItemAtPath:src toPath:copy error:&e] && e.code == NSFileWriteFileExistsError
              && [e.domain isEqual:NSCocoaErrorDomain], "copy onto an existing path fails with 516");
        CHECK([fm fileExistsAtPath:[copy stringByAppendingPathComponent:@"marker"]], "existing destination untouched");

        // NSFileWrapper recursive loading.
        NSFileWrapper *w = [[NSFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:src] options:NSFileWrapperReadingImmediate error:&e];
        CHECK(w != nil && w.isDirectory, "directory wrapper loads");
        NSFileWrapper *sub = w.fileWrappers[@"sub"];
        CHECK(sub.isDirectory && [[sub.fileWrappers[@"inner"] regularFileContents] isEqual:[@"inner" dataUsingEncoding:NSUTF8StringEncoding]],
              "nested regular file contents loaded");
        NSFileWrapper *rel = w.fileWrappers[@"rel"];
        CHECK(rel.isSymbolicLink && [rel.symbolicLinkDestinationURL.path hasSuffix:@"sub/inner"],
              "symlink wrapper keeps the stored destination");
        [w release];

        e = nil;
        w = [[NSFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:[root stringByAppendingPathComponent:@"nope"]] options:0 error:&e];
        CHECK(w == nil && e.code == NSFileReadNoSuchFileError, "missing path: NSFileReadNoSuchFileError");
        e = nil;
        w = [[NSFileWrapper alloc] initWithURL:[NSURL URLWithString:@"http://example.com/x"] options:0 error:&e];
        CHECK(w == nil && e.code == NSFileReadUnsupportedSchemeError, "non-file URL: NSFileReadUnsupportedSchemeError");

        // Lazy loading: contents are read on demand.
        w = [[NSFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:src] options:0 error:&e];
        CHECK([[[(NSFileWrapper *)w.fileWrappers[@"sub"] fileWrappers][@"inner"] regularFileContents] length] == 5, "lazy file contents available");
        [w release];

        [fm removeItemAtPath:root error:NULL];
    }
    printf(failures ? "FAILED (%d)\n" : "PASS\n", failures);
    return failures != 0;
}
