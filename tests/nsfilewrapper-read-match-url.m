// -[NSFileWrapper readFromURL:options:error:] and -[NSFileWrapper matchesContentsOfURL:].
// Documented in developer.apple.com/documentation/foundation/filewrapper/read(from:options:) and
// .../matchescontents(of:): reading rereads the contents of the wrapper from the node, and for a directory
// children are added and removed as necessary to match the file system; a match is decided by the modification
// date and permissions for a regular file, by the children (recursively) for a directory and by the destination
// for a symbolic link. Items marked GUESS in src/NSFileWrapper.m (the error for a node of another kind, a
// child whose node changed kind) are checked only for not crashing and for leaving the wrapper intact.
// Built without ARC.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

static int failures;

static void expect(BOOL ok, const char *what)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok)
        failures++;
}

static NSFileManager *fm;

static void put(NSString *path, NSString *text)
{
    [text writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

// Moves the modification date, which is what a regular file is matched on.
static void touch(NSString *path, NSTimeInterval secondsFromNow)
{
    NSDictionary *attrs = @{ NSFileModificationDate: [NSDate dateWithTimeIntervalSinceNow:secondsFromNow] };
    [fm setAttributes:attrs ofItemAtPath:path error:NULL];
}

static NSString *text(NSFileWrapper *wrapper)
{
    return [[[NSString alloc] initWithData:[wrapper regularFileContents] encoding:NSUTF8StringEncoding] autorelease];
}

int main(void)
{
    NSAutoreleasePool *outer = [NSAutoreleasePool new];
    fm = [NSFileManager defaultManager];
    char tmpl[] = "/tmp/filewrapper-read-XXXXXX";
    if (!mkdtemp(tmpl)) {
        printf("FAIL: mkdtemp\n");
        return 1;
    }
    NSString *dir = [fm stringWithFileSystemRepresentation:tmpl length:strlen(tmpl)];
    NSString *a = [dir stringByAppendingPathComponent:@"a.txt"];
    NSString *sub = [dir stringByAppendingPathComponent:@"sub"];
    NSString *b = [sub stringByAppendingPathComponent:@"b.txt"];
    NSString *gone = [dir stringByAppendingPathComponent:@"gone.txt"];
    NSString *link = [dir stringByAppendingPathComponent:@"link"];
    NSURL *dirURL = [NSURL fileURLWithPath:dir];
    NSURL *aURL = [NSURL fileURLWithPath:a];
    [fm createDirectoryAtPath:sub withIntermediateDirectories:YES attributes:nil error:NULL];
    put(a, @"one");
    put(b, @"inner");
    put(gone, @"bye");
    symlink([a fileSystemRepresentation], [link fileSystemRepresentation]);

    NSError *error = nil;
    NSFileWrapper *wrapper = [[[NSFileWrapper alloc] initWithURL:dirURL options:0 error:&error] autorelease];
    expect(wrapper != nil, "the directory is read");

    // Matching.
    expect([wrapper matchesContentsOfURL:dirURL], "a directory wrapper read from the directory matches it");
    expect([[[wrapper fileWrappers] objectForKey:@"a.txt"] matchesContentsOfURL:aURL], "a regular file wrapper matches its file");
    expect([[[wrapper fileWrappers] objectForKey:@"link"] matchesContentsOfURL:[NSURL fileURLWithPath:link]], "a link wrapper matches its link");
    expect(![wrapper matchesContentsOfURL:aURL], "a directory wrapper does not match a file");
    expect(![[[wrapper fileWrappers] objectForKey:@"a.txt"] matchesContentsOfURL:dirURL], "a file wrapper does not match a directory");
    expect(![wrapper matchesContentsOfURL:[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"missing"]]], "a missing node matches nothing");
    expect(![wrapper matchesContentsOfURL:[NSURL URLWithString:@"http://example.com/"]], "a URL that is not a file URL matches nothing");
    NSFileWrapper *fromData = [[[NSFileWrapper alloc] initRegularFileWithContents:[@"one" dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
    expect(![fromData matchesContentsOfURL:aURL], "a wrapper that was not read from a node records no date and does not match");

    // A node on disk that the wrapper lacks, and a child of the wrapper that is not on disk, are each a mismatch.
    NSString *extra = [dir stringByAppendingPathComponent:@"extra.txt"];
    put(extra, @"x");
    expect(![wrapper matchesContentsOfURL:dirURL], "a directory with an entry the wrapper lacks does not match");
    [fm removeItemAtPath:extra error:NULL];
    expect([wrapper matchesContentsOfURL:dirURL], "and matches again once the entry is gone");
    [fm removeItemAtPath:gone error:NULL];
    expect(![wrapper matchesContentsOfURL:dirURL], "a directory lacking an entry the wrapper has does not match");

    // Permissions count for a regular file, besides the modification date.
    struct stat st;
    stat([a fileSystemRepresentation], &st);
    mode_t mode = st.st_mode & 07777;
    chmod([a fileSystemRepresentation], mode ^ 0100);
    expect(![[[wrapper fileWrappers] objectForKey:@"a.txt"] matchesContentsOfURL:aURL], "a regular file with other permissions does not match");
    chmod([a fileSystemRepresentation], mode);
    expect([[[wrapper fileWrappers] objectForKey:@"a.txt"] matchesContentsOfURL:aURL], "and matches again with its permissions back");

    touch(b, 100);
    NSFileWrapper *bWrapper = [[[[wrapper fileWrappers] objectForKey:@"sub"] fileWrappers] objectForKey:@"b.txt"];
    expect(![bWrapper matchesContentsOfURL:[NSURL fileURLWithPath:b]], "a regular file with another modification date does not match");
    expect(![[[wrapper fileWrappers] objectForKey:@"sub"] matchesContentsOfURL:[NSURL fileURLWithPath:sub]], "a directory with such a child does not match");
    expect(![wrapper matchesContentsOfURL:dirURL], "so the directory above it does not match either");
    expect([[[wrapper fileWrappers] objectForKey:@"a.txt"] matchesContentsOfURL:aURL], "a sibling that did not change still matches");

    // Rereading: contents, additions and removals, at any depth, and the kinds of node.
    put(a, @"changed");
    touch(a, 100);
    put([dir stringByAppendingPathComponent:@"new.txt"], @"fresh");
    [fm removeItemAtPath:b error:NULL];
    put([sub stringByAppendingPathComponent:@"deeper.txt"], @"deep");
    [fm removeItemAtPath:link error:NULL];
    symlink("/somewhere/else", [link fileSystemRepresentation]);
    NSFileWrapper *aBefore = [[wrapper fileWrappers] objectForKey:@"a.txt"];
    NSFileWrapper *subBefore = [[wrapper fileWrappers] objectForKey:@"sub"];

    expect(![wrapper matchesContentsOfURL:dirURL], "the directory no longer matches");
    error = nil;
    expect([wrapper readFromURL:dirURL options:NSFileWrapperReadingImmediate error:&error], "the directory is reread");
    expect(error == nil, "a successful reread sets no error");
    expect([wrapper matchesContentsOfURL:dirURL], "the directory matches after the reread");
    NSDictionary *children = [wrapper fileWrappers];
    NSSet *names = [NSSet setWithArray:[children allKeys]];
    expect([names isEqualToSet:[NSSet setWithObjects:@"a.txt", @"sub", @"new.txt", @"link", nil]], "children were added and removed to match the directory");
    expect([children objectForKey:@"a.txt"] == aBefore && [children objectForKey:@"sub"] == subBefore,
           "the wrappers of nodes that remain are kept");
    expect([text([children objectForKey:@"a.txt"]) isEqualToString:@"changed"], "the contents of a kept file were reread");
    expect([text([children objectForKey:@"new.txt"]) isEqualToString:@"fresh"], "a new file has its contents");
    expect([[[children objectForKey:@"new.txt"] filename] isEqualToString:@"new.txt"], "a new child records its filename");
    NSDictionary *inner = [[children objectForKey:@"sub"] fileWrappers];
    expect([[NSSet setWithArray:[inner allKeys]] isEqualToSet:[NSSet setWithObject:@"deeper.txt"]], "the reread is recursive");
    expect([[[[children objectForKey:@"link"] symbolicLinkDestinationURL] path] isEqualToString:@"/somewhere/else"], "a link has its new destination");

    // Immediate reading took the contents now: they survive the file going away.
    [fm removeItemAtPath:a error:NULL];
    expect([text([children objectForKey:@"a.txt"]) isEqualToString:@"changed"], "NSFileWrapperReadingImmediate read the contents in advance");

    // A file replaced by a directory of the same name (GUESS: the child is replaced).
    put(a, @"again");
    [fm removeItemAtPath:[dir stringByAppendingPathComponent:@"new.txt"] error:NULL];
    [fm createDirectoryAtPath:[dir stringByAppendingPathComponent:@"new.txt"] withIntermediateDirectories:NO attributes:nil error:NULL];
    expect([wrapper readFromURL:dirURL options:0 error:NULL], "a directory with a child that changed kind is reread");
    expect([[[wrapper fileWrappers] objectForKey:@"new.txt"] isDirectory], "the child that changed kind is a directory wrapper now");

    // Failures leave the receiver as it was.
    NSFileWrapper *file = [[[NSFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:a] options:0 error:NULL] autorelease];
    error = nil;
    expect(![file readFromURL:dirURL options:0 error:&error], "a regular file wrapper does not take a directory");
    expect(error != nil && [[error domain] isEqualToString:NSCocoaErrorDomain], "that failure is a Cocoa error");
    expect([file isRegularFile] && [text(file) isEqualToString:@"again"], "the wrapper is unchanged by it");
    error = nil;
    expect(![file readFromURL:[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"missing"]] options:0 error:&error], "a missing node cannot be read");
    expect([[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == NSFileReadNoSuchFileError, "that is NSFileReadNoSuchFileError");
    error = nil;
    expect(![file readFromURL:[NSURL URLWithString:@"http://example.com/"] options:0 error:&error], "a URL that is not a file URL cannot be read");
    expect([[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == NSFileReadUnsupportedSchemeError, "that is NSFileReadUnsupportedSchemeError");
    expect(![file readFromURL:dirURL options:0 error:NULL], "a NULL error pointer is accepted");

    // A regular file wrapper rereads its own file.
    put(a, @"third");
    touch(a, 200);
    expect(![file matchesContentsOfURL:aURL], "the file wrapper no longer matches its changed file");
    expect([file readFromURL:aURL options:0 error:NULL] && [text(file) isEqualToString:@"third"], "the file wrapper rereads it");
    expect([file matchesContentsOfURL:aURL], "and matches it again");

    // A link wrapper rereads the destination.
    NSFileWrapper *linkWrapper = [[[NSFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:link] options:0 error:NULL] autorelease];
    [fm removeItemAtPath:link error:NULL];
    symlink("/another/place", [link fileSystemRepresentation]);
    expect(![linkWrapper matchesContentsOfURL:[NSURL fileURLWithPath:link]], "a link wrapper does not match a link with another destination");
    expect([linkWrapper readFromURL:[NSURL fileURLWithPath:link] options:0 error:NULL] &&
           [[[linkWrapper symbolicLinkDestinationURL] path] isEqualToString:@"/another/place"], "the link wrapper rereads the destination");
    expect([linkWrapper matchesContentsOfURL:[NSURL fileURLWithPath:link]], "and matches it again");

    [fm removeItemAtPath:dir error:NULL];
    [outer drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
