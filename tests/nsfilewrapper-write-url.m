// -[NSFileWrapper writeToURL:options:originalContentsURL:error:] for directory and symbolic link wrappers, and
// the name updating of every kind. Documented in developer.apple.com/documentation/foundation/filewrapper/
// write(to:options:originalcontentsurl:) and .../writingoptions: the entire contents are written recursively;
// with the atomic option the write completely succeeds or completely fails; with the name updating option the
// descendants' filenames are set if the write succeeds; when an earlier revision is given, the default
// implementation attempts to write hard links to regular files whose contents have not changed instead of
// writing them out (the inode checks below pin Darling's choice to do so, which macOS makes too).
// What the documentation leaves open is pinned by black-box observation on macOS 26.7.3 and 10.14.4 (identical on
// both): without the atomic option nothing may exist where a directory or link wrapper is written (it fails with
// NSFileWriteFileExistsError; macOS also removes a directory it found there, which Darling does not); the atomic
// option replaces whatever is there; a regular file wrapper overwrites a file and writes through a link;
// the fileAttributes of a wrapper are applied to what is written, permissions with the umask; with name updating the
// children record their names while the wrapper written keeps its own filename (a QUIRK, see recordChildNames in
// src/NSFileWrapper.m); a wrapper saved over its own file with that file as the earlier revision leaves it alone
// unless the write is atomic; the error for a parent that is missing is NSFileNoSuchFileError, for a parent that
// is a file the unknown write error. A child name with a ".." component is refused with NSFileWriteInvalidFileNameError,
// which is stricter than macOS. Built without ARC.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/time.h>
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

static int permissions(NSString *path)
{
    struct stat st;
    return stat([path fileSystemRepresentation], &st) == 0 ? (st.st_mode & 07777) : -1;
}

static BOOL isLink(NSString *path)
{
    struct stat st;
    return lstat([path fileSystemRepresentation], &st) == 0 && S_ISLNK(st.st_mode);
}

static NSNumber *underlyingCode(NSError *error)
{
    return [NSNumber numberWithInteger:[[[error userInfo] objectForKey:NSUnderlyingErrorKey] code]];
}

int main(void)
{
    NSAutoreleasePool *outer = [NSAutoreleasePool new];
    fm = [NSFileManager defaultManager];
    umask(022);
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
    expect(permissions(out) == 0755 && permissions([out stringByAppendingPathComponent:@"a.txt"]) == 0644, "with the permissions of a new item under umask 022");

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

    // The errors of the writes that fail for the place (observed on macOS).
    error = nil;
    expect(![tree writeToURL:[NSURL fileURLWithPath:noParent] options:0 originalContentsURL:nil error:&error] &&
           [[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == NSFileNoSuchFileError && [underlyingCode(error) intValue] == ENOENT,
           "a parent that does not exist is NSFileNoSuchFileError with ENOENT");
    NSString *aFile = [base stringByAppendingPathComponent:@"afile"];
    [@"x" writeToFile:aFile atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    error = nil;
    expect(![tree writeToURL:[NSURL fileURLWithPath:[aFile stringByAppendingPathComponent:@"out"]] options:0 originalContentsURL:nil error:&error] &&
           [[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == NSFileWriteUnknownError && [underlyingCode(error) intValue] == ENOTDIR,
           "a parent that is a file is the unknown write error with ENOTDIR");
    expect(![tree writeToURL:[NSURL fileURLWithPath:noParent] options:0 originalContentsURL:nil error:NULL], "a NULL error pointer is accepted");

    // Without the atomic option nothing may be where a directory or a link is written (observed on macOS, which also
    // removes a directory it found there; here the item stays).
    NSString *existingDir = [base stringByAppendingPathComponent:@"existing-dir"];
    [fm createDirectoryAtPath:existingDir withIntermediateDirectories:NO attributes:nil error:NULL];
    [@"stale" writeToFile:[existingDir stringByAppendingPathComponent:@"stale.txt"] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    error = nil;
    expect(![tree writeToURL:[NSURL fileURLWithPath:existingDir] options:0 originalContentsURL:nil error:&error] &&
           [error code] == NSFileWriteFileExistsError && [underlyingCode(error) intValue] == EEXIST,
           "a directory wrapper is not written where a directory exists (NSFileWriteFileExistsError)");
    expect([contents([existingDir stringByAppendingPathComponent:@"stale.txt"]) isEqualToString:@"stale"] &&
           ![fm fileExistsAtPath:[existingDir stringByAppendingPathComponent:@"a.txt"]], "and what was there is not written into");
    NSString *existingFile = [base stringByAppendingPathComponent:@"existing-file"];
    [@"old" writeToFile:existingFile atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    error = nil;
    expect(![tree writeToURL:[NSURL fileURLWithPath:existingFile] options:0 originalContentsURL:nil error:&error] && [error code] == NSFileWriteFileExistsError &&
           [contents(existingFile) isEqualToString:@"old"], "nor where a file exists");
    NSString *victim = [base stringByAppendingPathComponent:@"victim"];
    [fm createDirectoryAtPath:victim withIntermediateDirectories:NO attributes:nil error:NULL];
    NSString *dirLink = [base stringByAppendingPathComponent:@"dir-link"];
    symlink([victim fileSystemRepresentation], [dirLink fileSystemRepresentation]);
    expect(![tree writeToURL:[NSURL fileURLWithPath:dirLink] options:0 originalContentsURL:nil error:NULL] &&
           [[fm contentsOfDirectoryAtPath:victim error:NULL] count] == 0 && isLink(dirLink), "a symlink to a directory is not written through, nor replaced");
    NSFileWrapper *link = [[[tree fileWrappers] objectForKey:@"lnk"] retain];
    error = nil;
    expect(![link writeToURL:[NSURL fileURLWithPath:existingFile] options:0 originalContentsURL:nil error:&error] && [error code] == NSFileWriteFileExistsError &&
           [contents(existingFile) isEqualToString:@"old"], "a link wrapper is not written over an existing file either");
    NSString *linkOver = [base stringByAppendingPathComponent:@"link-over"];
    [@"old" writeToFile:linkOver atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    expect([link writeToURL:[NSURL fileURLWithPath:linkOver] options:NSFileWrapperWritingAtomic originalContentsURL:nil error:NULL] && isLink(linkOver), "but the atomic option replaces it");
    NSString *linkedRoot = [base stringByAppendingPathComponent:@"linked-root"];
    symlink([victim fileSystemRepresentation], [linkedRoot fileSystemRepresentation]);
    expect([tree writeToURL:[NSURL fileURLWithPath:linkedRoot] options:NSFileWrapperWritingAtomic originalContentsURL:nil error:NULL] &&
           [[fm contentsOfDirectoryAtPath:victim error:NULL] count] == 0 && !isLink(linkedRoot), "the atomic option replaces a symlink to a directory without writing through it");

    // A regular file wrapper overwrites a file and writes through a link without the atomic option, and replaces
    // either with it.
    NSFileWrapper *solo = file(@"solo.txt", @"NEW");
    expect([solo writeToURL:[NSURL fileURLWithPath:existingFile] options:0 originalContentsURL:nil error:NULL] && [contents(existingFile) isEqualToString:@"NEW"], "a regular file wrapper overwrites a file");
    NSString *target = [base stringByAppendingPathComponent:@"target.txt"];
    [@"TARGET" writeToFile:target atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    NSString *fileLink = [base stringByAppendingPathComponent:@"file-link"];
    symlink([target fileSystemRepresentation], [fileLink fileSystemRepresentation]);
    expect([solo writeToURL:[NSURL fileURLWithPath:fileLink] options:0 originalContentsURL:nil error:NULL] && isLink(fileLink) && [contents(target) isEqualToString:@"NEW"], "and writes through a link to a file");
    [@"TARGET" writeToFile:target atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    expect([solo writeToURL:[NSURL fileURLWithPath:fileLink] options:NSFileWrapperWritingAtomic originalContentsURL:nil error:NULL] && !isLink(fileLink) &&
           [contents(fileLink) isEqualToString:@"NEW"] && [contents(target) isEqualToString:@"TARGET"], "an atomic write replaces the link and leaves what it pointed to");
    error = nil;
    expect(![solo writeToURL:[NSURL fileURLWithPath:existingDir] options:0 originalContentsURL:nil error:&error] && error != nil &&
           [[error domain] isEqualToString:NSCocoaErrorDomain], "a regular file wrapper is not written over a directory");

    // A write that fails half way, after the directory and perhaps a child were written, leaves nothing either.
    // A child name with a ".." component is refused (stricter than macOS, which follows it); "." and ".." name the
    // directory itself and its parent and fail as the unknown write error with EISDIR (observed on macOS).
    NSString *escape = [@"../" stringByAppendingString:[[NSProcessInfo processInfo] globallyUniqueString]];
    NSDictionary *odd = [NSDictionary dictionaryWithObjectsAndKeys:file(@"ok.txt", @"x"), @"ok.txt", file(@"bad", @"x"), escape, nil];
    NSFileWrapper *oddTree = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers:odd] autorelease];
    NSString *oddOut = [base stringByAppendingPathComponent:@"odd"];
    NSUInteger beforeCount = [[fm contentsOfDirectoryAtPath:base error:NULL] count];
    error = nil;
    expect(![oddTree writeToURL:[NSURL fileURLWithPath:oddOut] options:NSFileWrapperWritingAtomic originalContentsURL:nil error:&error] &&
           [[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == NSFileWriteInvalidFileNameError,
           "an atomic write with a child name that leaves the destination fails as a whole, with NSFileWriteInvalidFileNameError");
    expect(![fm fileExistsAtPath:oddOut] && [[fm contentsOfDirectoryAtPath:base error:NULL] count] == beforeCount, "and leaves neither the result nor a temporary item");
    expect(![fm fileExistsAtPath:[base stringByAppendingPathComponent:[escape lastPathComponent]]], "and nothing outside the destination");
    for (NSString *dots in [NSArray arrayWithObjects:@".", @"..", nil]) {
        NSFileWrapper *dotTree = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers:[NSDictionary dictionaryWithObject:file(@"x", @"x") forKey:dots]] autorelease];
        error = nil;
        expect(![dotTree writeToURL:[NSURL fileURLWithPath:[base stringByAppendingPathComponent:@"dots"]] options:0 originalContentsURL:nil error:&error] &&
               [error code] == NSFileWriteUnknownError && [underlyingCode(error) intValue] == EISDIR, "a child named \".\" or \"..\" is the unknown write error with EISDIR");
        [fm removeItemAtPath:[base stringByAppendingPathComponent:@"dots"] error:NULL];
    }

    // A URL that is not a file URL.
    NSURL *web = [NSURL URLWithString:@"http://example.com/out"];
    error = nil;
    expect(![tree writeToURL:web options:0 originalContentsURL:nil error:&error], "a directory wrapper is not written to a URL that is not a file URL");
    expect([[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == NSFileWriteUnsupportedSchemeError, "that is NSFileWriteUnsupportedSchemeError");
    error = nil;
    expect(![link writeToURL:web options:0 originalContentsURL:nil error:&error] && [error code] == NSFileWriteUnsupportedSchemeError, "nor is a link wrapper");
    expect(![tree writeToURL:web options:0 originalContentsURL:nil error:NULL], "a NULL error pointer is accepted");

    // A link wrapper alone.
    NSString *linkOut = [base stringByAppendingPathComponent:@"alone"];
    expect([link writeToURL:[NSURL fileURLWithPath:linkOut] options:0 originalContentsURL:nil error:NULL] &&
           [[fm destinationOfSymbolicLinkAtPath:linkOut error:NULL] isEqualToString:@"/absolute/target"], "a link wrapper is written as a link");

    // Name updating (QUIRK): the descendants of a written directory record their names; the wrapper written keeps its own
    // filename, whatever kind it is, and a failed write records nothing.
    NSFileWrapper *named = makeTree();
    NSString *namedOut = [base stringByAppendingPathComponent:@"named"];
    expect([named writeToURL:[NSURL fileURLWithPath:namedOut] options:0 originalContentsURL:nil error:NULL], "a write without name updating succeeds");
    expect([named filename] == nil && [[[named fileWrappers] objectForKey:@"a.txt"] filename] == nil, "and records no filenames");
    NSString *namedOut2 = [base stringByAppendingPathComponent:@"named2"];
    expect([named writeToURL:[NSURL fileURLWithPath:namedOut2] options:NSFileWrapperWritingWithNameUpdating originalContentsURL:nil error:NULL], "a write with name updating succeeds");
    NSDictionary *kids = [named fileWrappers];
    expect([named filename] == nil, "the directory wrapper keeps its own (absent) filename (QUIRK: observed on macOS)");
    expect([[[kids objectForKey:@"a.txt"] filename] isEqualToString:@"a.txt"] && [[[kids objectForKey:@"lnk"] filename] isEqualToString:@"lnk"], "its children record their names");
    expect([[[[[kids objectForKey:@"sub"] fileWrappers] objectForKey:@"b.txt"] filename] isEqualToString:@"b.txt"], "and so do its descendants");
    NSFileWrapper *failing = makeTree();
    expect(![failing writeToURL:[NSURL fileURLWithPath:noParent] options:NSFileWrapperWritingAtomic | NSFileWrapperWritingWithNameUpdating originalContentsURL:nil error:NULL] &&
           [failing filename] == nil && [[[failing fileWrappers] objectForKey:@"a.txt"] filename] == nil, "a failed write records no filenames");
    NSString *atomicNamed = [base stringByAppendingPathComponent:@"atomic-named"];
    NSFileWrapper *atomicTree = makeTree();
    expect([atomicTree writeToURL:[NSURL fileURLWithPath:atomicNamed] options:NSFileWrapperWritingAtomic | NSFileWrapperWritingWithNameUpdating originalContentsURL:nil error:NULL] &&
           [[[[atomicTree fileWrappers] objectForKey:@"a.txt"] filename] isEqualToString:@"a.txt"], "an atomic write with name updating records the children's names");
    NSFileWrapper *regular = file(@"x.txt", @"solo");
    NSString *regularOut = [base stringByAppendingPathComponent:@"solo.txt"];
    expect([regular writeToURL:[NSURL fileURLWithPath:regularOut] options:NSFileWrapperWritingWithNameUpdating originalContentsURL:nil error:NULL] &&
           [regular filename] == nil && [contents(regularOut) isEqualToString:@"solo"], "a regular file wrapper keeps its filename too");
    NSFileWrapper *linkNamed = [[[NSFileWrapper alloc] initSymbolicLinkWithDestinationURL:[NSURL fileURLWithPath:@"/absolute/target"]] autorelease];
    expect([linkNamed writeToURL:[NSURL fileURLWithPath:[base stringByAppendingPathComponent:@"alone2"]] options:NSFileWrapperWritingWithNameUpdating originalContentsURL:nil error:NULL] &&
           [linkNamed filename] == nil, "and so does a link wrapper");

    // The earlier revision: unchanged regular files are linked (the reference says the default implementation attempts
    // this), others are written. Every file has the right contents whatever the file system does.
    NSURL *outURL = [NSURL fileURLWithPath:out];
    NSFileWrapper *revision = [[[NSFileWrapper alloc] initWithURL:outURL options:0 error:NULL] autorelease];
    NSString *next = [base stringByAppendingPathComponent:@"next"];
    NSFileWrapper *replacement = file(@"a.txt", @"replaced");
    expect([revision writeToURL:[NSURL fileURLWithPath:next] options:0 originalContentsURL:outURL error:&error], "a revision is written with the earlier revision given");
    expect(inode([next stringByAppendingPathComponent:@"a.txt"]) == inode([out stringByAppendingPathComponent:@"a.txt"]), "an unchanged file is a hard link to the earlier one");
    expect([contents([next stringByAppendingPathComponent:@"sub/b.txt"]) isEqualToString:@"inner"], "an unchanged file in a directory has its contents");
    expect(inode([next stringByAppendingPathComponent:@"sub/b.txt"]) == inode([out stringByAppendingPathComponent:@"sub/b.txt"]), "and is linked too");
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
    expect(inode([changed stringByAppendingPathComponent:@"sub/b.txt"]) == inode([out stringByAppendingPathComponent:@"sub/b.txt"]), "while the unchanged child is still linked");

    // A hard-linked earlier revision must not change when a later one replaces the linked copy: `next` has a.txt
    // linked to out/a.txt (above); an atomic write replaces `next` as a whole.
    NSFileWrapper *editedTree = makeTree();
    [editedTree removeFileWrapper:[[editedTree fileWrappers] objectForKey:@"a.txt"]];
    [editedTree addFileWrapper:file(@"a.txt", @"edited")];
    expect(inode([next stringByAppendingPathComponent:@"a.txt"]) == inode([out stringByAppendingPathComponent:@"a.txt"]), "(setup) next/a.txt is still linked to out/a.txt");
    expect([editedTree writeToURL:[NSURL fileURLWithPath:next] options:NSFileWrapperWritingAtomic originalContentsURL:nil error:NULL], "a changed tree is written over the directory atomically");
    expect([contents([next stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"edited"], "the copy has the new contents");
    expect([contents([out stringByAppendingPathComponent:@"a.txt"]) isEqualToString:@"one"], "the earlier revision it was linked to is unchanged");

    // A regular wrapper saved over its own file, with that file as the earlier revision: a non-atomic write leaves
    // the file alone, an atomic one replaces it (observed on macOS).
    NSString *own = [base stringByAppendingPathComponent:@"own.txt"];
    [@"own" writeToFile:own atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    NSURL *ownURL = [NSURL fileURLWithPath:own];
    NSFileWrapper *ownWrapper = [[[NSFileWrapper alloc] initWithURL:ownURL options:NSFileWrapperReadingImmediate error:NULL] autorelease];
    ino_t ownInode = inode(own);
    expect([ownWrapper writeToURL:ownURL options:0 originalContentsURL:ownURL error:NULL] && inode(own) == ownInode && [contents(own) isEqualToString:@"own"], "an unchanged wrapper saved over its own file leaves it alone");
    expect([ownWrapper writeToURL:ownURL options:NSFileWrapperWritingAtomic originalContentsURL:ownURL error:NULL] && inode(own) != ownInode && [contents(own) isEqualToString:@"own"], "unless the write is atomic");

    // The attributes of a wrapper are applied to what is written: permissions with the umask applied, and the date.
    NSString *src = [base stringByAppendingPathComponent:@"src.txt"];
    [@"src" writeToFile:src atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    chmod([src fileSystemRepresentation], 0640);
    struct timeval times[2];
    times[0].tv_sec = times[1].tv_sec = 1000000000;
    times[0].tv_usec = times[1].tv_usec = 0;
    utimes([src fileSystemRepresentation], times);
    NSFileWrapper *srcWrapper = [[[NSFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:src] options:NSFileWrapperReadingImmediate error:NULL] autorelease];
    NSString *srcCopy = [base stringByAppendingPathComponent:@"src-copy.txt"];
    expect([srcWrapper writeToURL:[NSURL fileURLWithPath:srcCopy] options:0 originalContentsURL:nil error:NULL] && permissions(srcCopy) == 0640 &&
           [[[fm attributesOfItemAtPath:srcCopy error:NULL] objectForKey:NSFileModificationDate] timeIntervalSince1970] == 1000000000.0,
           "a wrapper read from a file is written with that file's permissions and date");
    NSFileWrapper *loose = file(@"loose.txt", @"x");
    [loose setFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:NSFileTypeRegular, NSFileType, [NSNumber numberWithInt:0666], NSFilePosixPermissions,
                              [NSDate dateWithTimeIntervalSince1970:1100000000], NSFileModificationDate, nil]];
    NSString *looseOut = [base stringByAppendingPathComponent:@"loose.txt"];
    expect([loose writeToURL:[NSURL fileURLWithPath:looseOut] options:0 originalContentsURL:nil error:NULL] && permissions(looseOut) == 0644 &&
           [[[fm attributesOfItemAtPath:looseOut error:NULL] objectForKey:NSFileModificationDate] timeIntervalSince1970] == 1100000000.0,
           "permissions 0666 are applied as 0644 under umask 022, and the date as given");
    NSFileWrapper *closed = file(@"closed.txt", @"x");
    [closed setFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:NSFileTypeRegular, NSFileType, [NSNumber numberWithInt:0], NSFilePosixPermissions,
                               [NSDate dateWithTimeIntervalSince1970:1100000000], NSFileModificationDate, nil]];
    NSString *closedOut = [base stringByAppendingPathComponent:@"closed.txt"];
    expect([closed writeToURL:[NSURL fileURLWithPath:closedOut] options:0 originalContentsURL:nil error:NULL] && permissions(closedOut) == 0, "permissions 0 are applied as 0");
    chmod([closedOut fileSystemRepresentation], 0644);
    NSFileWrapper *secured = makeTree();
    [secured setFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:NSFileTypeDirectory, NSFileType, [NSNumber numberWithInt:0700], NSFilePosixPermissions,
                                [NSDate dateWithTimeIntervalSince1970:1100000000], NSFileModificationDate, nil]];
    NSString *securedOut = [base stringByAppendingPathComponent:@"secured"];
    expect([secured writeToURL:[NSURL fileURLWithPath:securedOut] options:0 originalContentsURL:nil error:NULL] && permissions(securedOut) == 0700 &&
           [[[fm attributesOfItemAtPath:securedOut error:NULL] objectForKey:NSFileModificationDate] timeIntervalSince1970] == 1100000000.0,
           "a directory wrapper's permissions and date are applied after its children were written");

    [link release];
    [fm removeItemAtPath:base error:NULL];
    [outer drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
