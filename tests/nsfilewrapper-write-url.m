// -[NSFileWrapper writeToURL:options:originalContentsURL:error:] for directory and symbolic link wrappers, and
// the name updating of every kind. Documented in developer.apple.com/documentation/foundation/filewrapper/
// write(to:options:originalcontentsurl:) and .../writingoptions: the entire contents are written recursively;
// with the atomic option the write completely succeeds or completely fails; with the name updating option the
// descendants' filenames are set if the write succeeds; when an earlier revision is given, the default
// implementation attempts to write hard links to regular files whose contents have not changed instead of
// writing them out (the inode checks below pin Darling's choice to do so, not a guarantee of the reference). Behaviour the reference leaves open (writing into a directory that exists, a child name
// that is not one path component, the error for a failed write) is marked GUESS in src/NSFileWrapper.m and not
// asserted here beyond the error being set. Built without ARC.
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

static NSString *contents(NSString *path)
{
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
}

static NSData *utf8(NSString *string)
{
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}

static NSFileWrapper *file(NSString *name, NSString *text)
{
    NSFileWrapper *wrapper = [[[NSFileWrapper alloc] initRegularFileWithContents:utf8(text)] autorelease];
    [wrapper setPreferredFilename:name];
    return wrapper;
}

// a.txt, sub/b.txt and a link, all made in memory.
static NSFileWrapper *makeTree(void)
{
    NSFileWrapper *sub = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers:nil] autorelease];
    [sub setPreferredFilename:@"sub"];
    [sub addFileWrapper:file(@"b.txt", @"inner")];
    NSFileWrapper *link = [[[NSFileWrapper alloc] initSymbolicLinkWithDestinationURL:[NSURL fileURLWithPath:@"/absolute/target"]] autorelease];
    [link setPreferredFilename:@"lnk"];
    NSFileWrapper *root = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers:nil] autorelease];
    [root addFileWrapper:file(@"a.txt", @"one")];
    [root addFileWrapper:sub];
    [root addFileWrapper:link];
    return root;
}

static ino_t inode(NSString *path)
{
    struct stat st;
    return stat([path fileSystemRepresentation], &st) == 0 ? st.st_ino : 0;
}

int main(void)
{
    NSAutoreleasePool *outer = [NSAutoreleasePool new];
    fm = [NSFileManager defaultManager];
    char tmpl[] = "/tmp/filewrapper-write-XXXXXX";
    if (!mkdtemp(tmpl)) {
        printf("FAIL: mkdtemp\n");
        return 1;
    }
    NSString *base = [fm stringWithFileSystemRepresentation:tmpl length:strlen(tmpl)];
    NSError *error = nil;

    // A tree written to a place where nothing exists.
    NSString *out = [base stringByAppendingPathComponent:@"out"];
    NSFileWrapper *tree = makeTree();
    expect([tree writeToURL:[NSURL fileURLWithPath:out] options:0 originalContentsURL:nil error:&error], "a directory wrapper is written");
    expect(error == nil, "a successful write sets no error");
    BOOL isDirectory = NO;
    expect([fm fileExistsAtPath:out isDirectory:&isDirectory] && isDirectory, "a directory is created");
    expect([contents([out stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"one"], "a regular child is written with its contents");
    expect([contents([out stringByAppendingPathComponent:@"sub/b.txt"]) isEqualToString:@"inner"], "a directory child is written recursively");
    expect([[fm destinationOfSymbolicLinkAtPath:[out stringByAppendingPathComponent:@"lnk"] error:NULL] isEqualToString:@"/absolute/target"],
           "a link child is created with its destination");

    // The tree read back is the tree written.
    NSFileWrapper *again = [[[NSFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:out] options:NSFileWrapperReadingImmediate error:NULL] autorelease];
    expect([[NSSet setWithArray:[[again fileWrappers] allKeys]] isEqualToSet:[NSSet setWithObjects:@"a.txt", @"sub", @"lnk", nil]], "reading the result gives the same names");
    expect([[[[again fileWrappers] objectForKey:@"lnk"] symbolicLinkDestinationURL] isFileURL], "and the link as a link");

    // Atomic: an existing directory is replaced completely, and nothing else is left in the parent.
    NSString *replaced = [base stringByAppendingPathComponent:@"replaced"];
    [fm createDirectoryAtPath:replaced withIntermediateDirectories:NO attributes:nil error:NULL];
    [@"stale" writeToFile:[replaced stringByAppendingPathComponent:@"stale.txt"] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    expect([tree writeToURL:[NSURL fileURLWithPath:replaced] options:NSFileWrapperWritingAtomic originalContentsURL:nil error:&error], "an atomic write over a directory succeeds");
    expect([contents([replaced stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"one"], "the new contents are in place");
    expect(![fm fileExistsAtPath:[replaced stringByAppendingPathComponent:@"stale.txt"]], "the old contents are gone");
    NSArray *left = [fm contentsOfDirectoryAtPath:base error:NULL];
    expect([[NSSet setWithArray:left] isEqualToSet:[NSSet setWithObjects:@"out", @"replaced", nil]], "no temporary item is left next to the result");

    // Atomic that cannot work fails as a whole and leaves nothing behind.
    NSString *noParent = [base stringByAppendingPathComponent:@"missing/out"];
    error = nil;
    expect(![tree writeToURL:[NSURL fileURLWithPath:noParent] options:NSFileWrapperWritingAtomic originalContentsURL:nil error:&error], "an atomic write below a missing directory fails");
    expect(error != nil, "and sets an error");
    expect(![fm fileExistsAtPath:[base stringByAppendingPathComponent:@"missing"]], "and creates nothing");
    expect([[fm contentsOfDirectoryAtPath:base error:NULL] count] == 2, "and leaves no temporary item");

    // A write that fails half way, after the directory and perhaps a child were written, leaves nothing either.
    // (GUESS in the code: a child name that is not one path component is refused; only the failure is asserted.)
    NSString *escape = [@"../" stringByAppendingString:[[NSProcessInfo processInfo] globallyUniqueString]];
    NSDictionary *odd = [NSDictionary dictionaryWithObjectsAndKeys:file(@"ok.txt", @"x"), @"ok.txt", file(@"bad", @"x"), escape, nil];
    NSFileWrapper *oddTree = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers:odd] autorelease];
    NSString *oddOut = [base stringByAppendingPathComponent:@"odd"];
    error = nil;
    expect(![oddTree writeToURL:[NSURL fileURLWithPath:oddOut] options:NSFileWrapperWritingAtomic originalContentsURL:nil error:&error] && error != nil,
           "an atomic write that fails half way fails as a whole");
    expect(![fm fileExistsAtPath:oddOut] && [[fm contentsOfDirectoryAtPath:base error:NULL] count] == 2, "and leaves neither the result nor a temporary item");
    expect(![fm fileExistsAtPath:[base stringByAppendingPathComponent:[escape lastPathComponent]]], "and nothing outside the destination");

    // A URL that is not a file URL.
    NSURL *web = [NSURL URLWithString:@"http://example.com/out"];
    error = nil;
    expect(![tree writeToURL:web options:0 originalContentsURL:nil error:&error], "a directory wrapper is not written to a URL that is not a file URL");
    expect([[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == NSFileWriteUnsupportedSchemeError, "that is NSFileWriteUnsupportedSchemeError");
    NSFileWrapper *link = [[[tree fileWrappers] objectForKey:@"lnk"] retain];
    error = nil;
    expect(![link writeToURL:web options:0 originalContentsURL:nil error:&error] && [error code] == NSFileWriteUnsupportedSchemeError, "nor is a link wrapper");
    expect(![tree writeToURL:web options:0 originalContentsURL:nil error:NULL], "a NULL error pointer is accepted");

    // A link wrapper alone.
    NSString *linkOut = [base stringByAppendingPathComponent:@"alone"];
    expect([link writeToURL:[NSURL fileURLWithPath:linkOut] options:0 originalContentsURL:nil error:NULL] &&
           [[fm destinationOfSymbolicLinkAtPath:linkOut error:NULL] isEqualToString:@"/absolute/target"], "a link wrapper is written as a link");

    // Name updating: filenames are recorded for the wrapper and its descendants only when asked for and only on success.
    NSFileWrapper *named = makeTree();
    NSString *namedOut = [base stringByAppendingPathComponent:@"named"];
    expect([named writeToURL:[NSURL fileURLWithPath:namedOut] options:0 originalContentsURL:nil error:NULL], "a write without name updating succeeds");
    expect([named filename] == nil && [[[named fileWrappers] objectForKey:@"a.txt"] filename] == nil, "and records no filenames");
    NSString *namedOut2 = [base stringByAppendingPathComponent:@"named2"];
    expect([named writeToURL:[NSURL fileURLWithPath:namedOut2] options:NSFileWrapperWritingWithNameUpdating originalContentsURL:nil error:NULL], "a write with name updating succeeds");
    NSDictionary *kids = [named fileWrappers];
    expect([[named filename] isEqualToString:@"named2"], "the wrapper records the name it was written under");
    expect([[[kids objectForKey:@"a.txt"] filename] isEqualToString:@"a.txt"] && [[[kids objectForKey:@"lnk"] filename] isEqualToString:@"lnk"], "its children record their names");
    expect([[[[[kids objectForKey:@"sub"] fileWrappers] objectForKey:@"b.txt"] filename] isEqualToString:@"b.txt"], "and so do its descendants");
    NSFileWrapper *failing = makeTree();
    expect(![failing writeToURL:[NSURL fileURLWithPath:noParent] options:NSFileWrapperWritingAtomic | NSFileWrapperWritingWithNameUpdating originalContentsURL:nil error:NULL] &&
           [failing filename] == nil && [[[failing fileWrappers] objectForKey:@"a.txt"] filename] == nil, "a failed write records no filenames");
    NSString *atomicNamed = [base stringByAppendingPathComponent:@"atomic-named"];
    expect([makeTree() writeToURL:[NSURL fileURLWithPath:atomicNamed] options:NSFileWrapperWritingAtomic | NSFileWrapperWritingWithNameUpdating originalContentsURL:nil error:NULL], "an atomic write with name updating succeeds");
    NSFileWrapper *regular = file(@"x.txt", @"solo");
    NSString *regularOut = [base stringByAppendingPathComponent:@"solo.txt"];
    expect([regular writeToURL:[NSURL fileURLWithPath:regularOut] options:NSFileWrapperWritingWithNameUpdating originalContentsURL:nil error:NULL] &&
           [[regular filename] isEqualToString:@"solo.txt"] && [contents(regularOut) isEqualToString:@"solo"], "a regular file wrapper takes name updating too");
    NSFileWrapper *linkNamed = [[[NSFileWrapper alloc] initSymbolicLinkWithDestinationURL:[NSURL fileURLWithPath:@"/absolute/target"]] autorelease];
    expect([linkNamed writeToURL:[NSURL fileURLWithPath:[base stringByAppendingPathComponent:@"alone2"]] options:NSFileWrapperWritingWithNameUpdating originalContentsURL:nil error:NULL] &&
           [[linkNamed filename] isEqualToString:@"alone2"], "and so does a link wrapper");

    // The earlier revision: unchanged regular files are linked (the reference says the default implementation attempts
    // this), others are written. Every file has the right contents whatever the file system does.
    NSURL *outURL = [NSURL fileURLWithPath:out];
    NSFileWrapper *revision = [[[NSFileWrapper alloc] initWithURL:outURL options:0 error:NULL] autorelease];
    NSString *next = [base stringByAppendingPathComponent:@"next"];
    NSFileWrapper *replacement = file(@"a.txt", @"replaced");
    expect([revision writeToURL:[NSURL fileURLWithPath:next] options:0 originalContentsURL:outURL error:&error], "a revision is written with the earlier revision given");
    expect(inode([next stringByAppendingPathComponent:@"a.txt"]) == inode([out stringByAppendingPathComponent:@"a.txt"]), "an unchanged file is a hard link to the earlier one (Darling's choice: the reference says only that hard links are attempted)");
    expect([contents([next stringByAppendingPathComponent:@"sub/b.txt"]) isEqualToString:@"inner"], "an unchanged file in a directory has its contents");
    expect(inode([next stringByAppendingPathComponent:@"sub/b.txt"]) == inode([out stringByAppendingPathComponent:@"sub/b.txt"]), "and is linked too (same choice)");
    NSString *copied = [base stringByAppendingPathComponent:@"copied"];
    expect([revision writeToURL:[NSURL fileURLWithPath:copied] options:0 originalContentsURL:nil error:NULL] &&
           inode([copied stringByAppendingPathComponent:@"a.txt"]) != inode([out stringByAppendingPathComponent:@"a.txt"]) &&
           [contents([copied stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"one"], "without an earlier revision every file is written out");
    [revision removeFileWrapper:[[revision fileWrappers] objectForKey:@"a.txt"]];
    [revision addFileWrapper:replacement];
    NSString *changed = [base stringByAppendingPathComponent:@"changed"];
    expect([revision writeToURL:[NSURL fileURLWithPath:changed] options:0 originalContentsURL:outURL error:NULL], "a revision with a replaced child is written");
    expect([contents([changed stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"replaced"], "the replaced child has its new contents");
    expect([contents([out stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"one"], "and the earlier revision is untouched");
    expect(inode([changed stringByAppendingPathComponent:@"sub/b.txt"]) == inode([out stringByAppendingPathComponent:@"sub/b.txt"]), "while the unchanged child is still linked (same choice)");

    // A hard-linked earlier revision must not change when a later one is written over the linked copy.
    // `next` has a.txt linked to out/a.txt (above); write other contents into `next` without atomic.
    NSFileWrapper *editedTree = makeTree();
    [editedTree removeFileWrapper:[[editedTree fileWrappers] objectForKey:@"lnk"]]; // a link is not written over an existing one
    [editedTree removeFileWrapper:[[editedTree fileWrappers] objectForKey:@"a.txt"]];
    [editedTree addFileWrapper:file(@"a.txt", @"edited")];
    expect(inode([next stringByAppendingPathComponent:@"a.txt"]) == inode([out stringByAppendingPathComponent:@"a.txt"]), "(setup) next/a.txt is still linked to out/a.txt");
    expect([editedTree writeToURL:[NSURL fileURLWithPath:next] options:0 originalContentsURL:nil error:NULL], "a changed tree is written into the existing directory");
    expect([contents([next stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"edited"], "the copy has the new contents");
    expect([contents([out stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"one"], "the earlier revision it was linked to is unchanged");
    // The same when saving over the earlier revision itself with a link that now points elsewhere.
    NSString *linked = [base stringByAppendingPathComponent:@"linked"];
    [fm linkItemAtPath:[out stringByAppendingPathComponent:@"a.txt"] toPath:[base stringByAppendingPathComponent:@"alias.txt"] error:NULL];
    [fm createDirectoryAtPath:linked withIntermediateDirectories:NO attributes:nil error:NULL];
    [fm linkItemAtPath:[out stringByAppendingPathComponent:@"a.txt"] toPath:[linked stringByAppendingPathComponent:@"a.txt"] error:NULL];
    expect([editedTree writeToURL:[NSURL fileURLWithPath:linked] options:0 originalContentsURL:outURL error:NULL] &&
           [contents([linked stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"edited"] &&
           [contents([base stringByAppendingPathComponent:@"alias.txt"]) isEqualToString:@"one"], "a changed file written over a link to another file does not change that file");

    // A link in the way is replaced or refused, never followed: a file symlink is replaced, a directory symlink is not entered.
    NSString *victim = [base stringByAppendingPathComponent:@"victim.txt"];
    [@"victim" writeToFile:victim atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    NSString *elsewhere = [base stringByAppendingPathComponent:@"elsewhere"];
    [fm createDirectoryAtPath:elsewhere withIntermediateDirectories:NO attributes:nil error:NULL];
    NSString *trap = [base stringByAppendingPathComponent:@"trap"];
    [fm createDirectoryAtPath:trap withIntermediateDirectories:NO attributes:nil error:NULL];
    symlink([victim fileSystemRepresentation], [[trap stringByAppendingPathComponent:@"a.txt"] fileSystemRepresentation]);
    NSFileWrapper *onlyFile = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers:nil] autorelease];
    [onlyFile addFileWrapper:file(@"a.txt", @"new")];
    expect([onlyFile writeToURL:[NSURL fileURLWithPath:trap] options:0 originalContentsURL:nil error:NULL], "a file is written where a symlink to a file is");
    expect([contents(victim) isEqualToString:@"victim"] && [contents([trap stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"new"],
           "and leaves the file the link pointed to unchanged");
    [fm removeItemAtPath:[trap stringByAppendingPathComponent:@"a.txt"] error:NULL];
    symlink([elsewhere fileSystemRepresentation], [[trap stringByAppendingPathComponent:@"sub"] fileSystemRepresentation]);
    [makeTree() writeToURL:[NSURL fileURLWithPath:trap] options:0 originalContentsURL:nil error:&error];
    expect([[fm contentsOfDirectoryAtPath:elsewhere error:NULL] count] == 0, "a symlink to a directory in the way is not written through");
    NSString *linkedRoot = [base stringByAppendingPathComponent:@"linked-root"];
    symlink([elsewhere fileSystemRepresentation], [linkedRoot fileSystemRepresentation]);
    [makeTree() writeToURL:[NSURL fileURLWithPath:linkedRoot] options:0 originalContentsURL:nil error:NULL];
    expect([[fm contentsOfDirectoryAtPath:elsewhere error:NULL] count] == 0, "a destination that is a symlink to a directory is not written through either");

    [link release];
    [fm removeItemAtPath:base error:NULL];
    [outer drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
