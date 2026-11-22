// Updating a directory file wrapper from its directory keeps the children it recycles alive.
// -[NSFileWrapper updateFromPath:] is documented (deprecated since 10.10, developer.apple.com/documentation/
// foundation/filewrapper/update(frompath:)): for a directory the contained wrappers are updated too, and wrappers
// for added or removed nodes are created or released. The recycled child is then owned by the directory's new
// child dictionary once, like any other child, and by nobody else once the caller lets go of its own reference
// (Memory Management Policy, developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/
// Articles/mmRules.html). Built without ARC; the legacy path methods are not declared in the header.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

@interface NSFileWrapper (LegacyPathAPI)
- (id)initWithPath:(NSString *)path;
- (BOOL)updateFromPath:(NSString *)path;
@end

static int failures;

static void expect(BOOL ok, const char *what)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok)
        failures++;
}

// The directory is only re-read when its modification date is newer than the wrapper's.
static void touchDirectory(NSString *dir, NSTimeInterval secondsFromNow)
{
    NSDictionary *attrs = @{ NSFileModificationDate: [NSDate dateWithTimeIntervalSinceNow:secondsFromNow] };
    [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:dir error:NULL];
}

int main(void)
{
    NSAutoreleasePool *outer = [NSAutoreleasePool new];
    NSFileManager *fm = [NSFileManager defaultManager];
    char tmpl[] = "/tmp/filewrapper-recycle-XXXXXX";
    if (!mkdtemp(tmpl)) {
        printf("FAIL: mkdtemp\n");
        return 1;
    }
    NSString *dir = [fm stringWithFileSystemRepresentation:tmpl length:strlen(tmpl)];
    NSString *sub = [dir stringByAppendingPathComponent:@"sub"];
    [fm createDirectoryAtPath:sub withIntermediateDirectories:YES attributes:nil error:NULL];
    [@"one" writeToFile:[dir stringByAppendingPathComponent:@"a.txt"] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    [@"inner" writeToFile:[sub stringByAppendingPathComponent:@"b.txt"] atomically:NO encoding:NSUTF8StringEncoding error:NULL];

    NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithPath:dir];
    NSFileWrapper *file = [[wrapper fileWrappers] objectForKey:@"a.txt"];
    NSFileWrapper *folder = [[wrapper fileWrappers] objectForKey:@"sub"];
    expect(file != nil && folder != nil, "the initial read found the file and the folder");
    [file retain];
    [folder retain];
    NSUInteger fileCount = [file retainCount];
    NSUInteger folderCount = [folder retainCount];

    // Two updates in a row, each after a change that makes the directory newer than the wrapper.
    for (int round = 1; round <= 2; round++) {
        NSString *added = [NSString stringWithFormat:@"added%d.txt", round];
        [@"new" writeToFile:[dir stringByAppendingPathComponent:added] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        touchDirectory(dir, 10 * round);
        expect([wrapper updateFromPath:dir], "the directory wrapper is updated");

        NSDictionary *children = [wrapper fileWrappers];
        expect([children objectForKey:added] != nil, "a node added on disk gets a wrapper");
        expect([children objectForKey:@"a.txt"] == file, "the file wrapper is recycled, not replaced");
        expect([children objectForKey:@"sub"] == folder, "the folder wrapper is recycled, not replaced");
        expect([file retainCount] == fileCount, "the recycled file wrapper is owned once by the directory");
        expect([folder retainCount] == folderCount, "the recycled folder wrapper is owned once by the directory");
        expect([[children objectForKey:@"a.txt"] isRegularFile] && [[file regularFileContents] length] == 3,
               "the recycled file wrapper still reads its contents");
    }

    // The caller's references are the only others, so releasing them leaves the directory consistent.
    [file release];
    [folder release];
    expect([[[wrapper fileWrappers] objectForKey:@"a.txt"] isRegularFile], "the child is valid after the caller let go");
    [wrapper release];

    [fm removeItemAtPath:dir error:NULL];
    [outer drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
