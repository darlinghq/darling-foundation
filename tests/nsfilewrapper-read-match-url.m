// -[NSFileWrapper readFromURL:options:error:] and -[NSFileWrapper matchesContentsOfURL:].
// Documented in developer.apple.com/documentation/foundation/filewrapper/read(from:options:) and
// .../matchescontents(of:): reading rereads the contents of the wrapper from the node, and for a directory
// children are added and removed as necessary to match the file system; a match is decided by modification dates
// (and, for a directory, its children). What the documentation leaves open is pinned by black-box observation on
// macOS 26.7.3 and 10.14.4 (identical on both): a regular file or link wrapper matches when the whole second of the
// node's date is that of the recorded date or the one after it, whatever the contents, permissions or link
// destination are; a directory wrapper matches when its own date does and every child it has matches the entry of
// that name (entries it lacks are not looked at); a wrapper made from data records the moment it was made as its
// date, except a link wrapper, which records none; a reread reads the contents only for a wrapper that no longer
// matches, but always takes up the node's attributes; an existing child that cannot be reread does not fail the
// read of its directory. The date rule is a QUIRK (see modificationDatesMatch in src/NSFileWrapper.m).
// A wrapper becomes a regular file or link wrapper (the same object) when it reads a regular file or link; reading a
// directory into a wrapper that is not one raises on macOS (the process aborts); here that read fails and leaves the
// wrapper as it was.
// Built without ARC.
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

static void put(NSString *path, NSString *text)
{
    [text writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

// Sets the modification date of the item itself (a link is not followed), to whole seconds since 1970 plus a fraction.
static void setDate(NSString *path, double seconds)
{
    struct timeval times[2];
    times[0].tv_sec = times[1].tv_sec = (time_t)seconds;
    times[0].tv_usec = times[1].tv_usec = (suseconds_t)((seconds - (double)(time_t)seconds) * 1000000.0);
    lutimes([path fileSystemRepresentation], times);
}

static NSString *text(NSFileWrapper *wrapper)
{
    return [[[NSString alloc] initWithData:[wrapper regularFileContents] encoding:NSUTF8StringEncoding] autorelease];
}

static NSDate *dateAt(double seconds)
{
    return [NSDate dateWithTimeIntervalSince1970:seconds];
}

// A date at which the files below are put, long ago, so that moving them by seconds never meets "now".
#define T0 1500000000.0

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
    NSURL *linkURL = [NSURL fileURLWithPath:link];
    [fm createDirectoryAtPath:sub withIntermediateDirectories:YES attributes:nil error:NULL];
    put(a, @"one");
    put(b, @"inner");
    put(gone, @"bye");
    symlink([a fileSystemRepresentation], [link fileSystemRepresentation]);
    for (NSString *path in [NSArray arrayWithObjects:a, b, gone, link, sub, dir, nil])
        setDate(path, T0);

    NSError *error = nil;
    NSFileWrapper *wrapper = [[[NSFileWrapper alloc] initWithURL:dirURL options:0 error:&error] autorelease];
    expect(wrapper != nil, "the directory is read");
    NSDictionary *wrapped = [wrapper fileWrappers];
    NSFileWrapper *aWrapper = [wrapped objectForKey:@"a.txt"];
    NSFileWrapper *subWrapper = [wrapped objectForKey:@"sub"];
    NSFileWrapper *bWrapper = [[subWrapper fileWrappers] objectForKey:@"b.txt"];
    NSFileWrapper *linkWrapper = [wrapped objectForKey:@"link"];

    // Matching.
    expect([wrapper matchesContentsOfURL:dirURL], "a directory wrapper read from the directory matches it");
    expect([aWrapper matchesContentsOfURL:aURL], "a regular file wrapper matches its file");
    expect([linkWrapper matchesContentsOfURL:linkURL], "a link wrapper matches its link");
    expect(![wrapper matchesContentsOfURL:aURL], "a directory wrapper does not match a file");
    expect(![aWrapper matchesContentsOfURL:dirURL], "a file wrapper does not match a directory");
    expect(![wrapper matchesContentsOfURL:[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:@"missing"]]], "a missing node matches nothing");
    expect(![wrapper matchesContentsOfURL:[NSURL URLWithString:@"http://example.com/"]], "a URL that is not a file URL matches nothing");
    expect(![wrapper matchesContentsOfURL:nil], "a nil URL matches nothing");

    // Contents, permissions and a link's destination are not compared, the dates are.
    put(a, @"ONE");
    setDate(a, T0);
    expect([aWrapper matchesContentsOfURL:aURL], "a regular file with other contents and the same date still matches");
    struct stat st;
    stat([a fileSystemRepresentation], &st);
    mode_t mode = st.st_mode & 07777;
    chmod([a fileSystemRepresentation], mode ^ 0100);
    expect([aWrapper matchesContentsOfURL:aURL], "so does one with other permissions");
    chmod([a fileSystemRepresentation], mode);
    [fm removeItemAtPath:link error:NULL];
    symlink("/somewhere/else", [link fileSystemRepresentation]);
    setDate(link, T0);
    expect([linkWrapper matchesContentsOfURL:linkURL], "a link wrapper matches a link with another destination and the same date");
    put(a, @"one");
    setDate(a, T0);

    // The date rule (QUIRK): the whole second of the node's date is the recorded one or the one after it. Observed
    // for recorded dates at three fractions of a second and these offsets of the node's date from the recorded date.
    {
        static const double offsets[] = { -1.5, -1.1, -1, -0.9, -0.5, 0, 0.5, 0.9, 1, 1.1, 1.5, 2 };
        static const double fractions[] = { 0.05, 0.56, 0.95 };
        // Y for a match; one row per fraction, one column per offset
        static const char *expected[] = { "nnnnnYYYYYYn", "nnnnYYYYYYnn", "nnnYYYYYYnnn" };
        NSString *probe = [dir stringByAppendingPathComponent:@"probe.txt"];
        put(probe, @"x");
        NSURL *probeURL = [NSURL fileURLWithPath:probe];
        BOOL ok = YES;
        for (int f = 0; f < 3; f++) {
            double recorded = T0 + 100 + fractions[f];
            NSFileWrapper *w = [[[NSFileWrapper alloc] initRegularFileWithContents:nil] autorelease];
            [w setFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:NSFileTypeRegular, NSFileType,
                [NSNumber numberWithInt:0644], NSFilePosixPermissions, dateAt(recorded), NSFileModificationDate, nil]];
            for (int o = 0; o < 12; o++) {
                setDate(probe, recorded + offsets[o]);
                BOOL expectedMatch = expected[f][o] == 'Y';
                if ([w matchesContentsOfURL:probeURL] != expectedMatch) {
                    printf("  date rule: recorded fraction %.2f offset %+.1f gave %d\n", fractions[f], offsets[o], !expectedMatch);
                    ok = NO;
                }
            }
        }
        expect(ok, "the date rule holds for every fraction of a second and offset observed");
        [fm removeItemAtPath:probe error:NULL];
    }

    // A wrapper made from data records the moment it was made: it matches a file dated then and not an old one.
    NSFileWrapper *fromData = [[[NSFileWrapper alloc] initRegularFileWithContents:[@"one" dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
    expect(![fromData matchesContentsOfURL:aURL], "a wrapper made from data does not match a file with an old date");
    setDate(a, (double)time(NULL));
    expect([fromData matchesContentsOfURL:aURL], "but matches a file dated when it was made, whatever the contents");
    setDate(a, T0);
    NSFileWrapper *linkFromDestination = [[[NSFileWrapper alloc] initSymbolicLinkWithDestinationURL:[NSURL fileURLWithPath:@"/somewhere/else"]] autorelease];
    setDate(link, (double)time(NULL));
    expect(![linkFromDestination matchesContentsOfURL:linkURL], "a link wrapper made from a destination records no date and matches nothing");
    setDate(link, T0);

    // Directories: the entries the wrapper has must match, extra entries on disk do not matter.
    NSString *extra = [dir stringByAppendingPathComponent:@"extra.txt"];
    put(extra, @"x");
    setDate(dir, T0);
    expect([wrapper matchesContentsOfURL:dirURL], "an entry the wrapper lacks does not break the match");
    [fm removeItemAtPath:extra error:NULL];
    setDate(dir, T0);
    [fm removeItemAtPath:gone error:NULL];
    setDate(dir, T0);
    expect(![wrapper matchesContentsOfURL:dirURL], "a directory lacking an entry the wrapper has does not match");
    put(gone, @"bye");
    setDate(gone, T0);
    setDate(dir, T0);
    expect([wrapper matchesContentsOfURL:dirURL], "and matches again once the entry is back");
    setDate(dir, T0 + 100);
    expect(![wrapper matchesContentsOfURL:dirURL], "a directory with another date does not match");
    setDate(dir, T0);
    setDate(b, T0 + 100);
    expect(![bWrapper matchesContentsOfURL:[NSURL fileURLWithPath:b]], "a regular file with another date does not match");
    expect(![subWrapper matchesContentsOfURL:[NSURL fileURLWithPath:sub]], "a directory with such a child does not match");
    expect(![wrapper matchesContentsOfURL:dirURL], "so the directory above it does not match either");
    expect([aWrapper matchesContentsOfURL:aURL], "a sibling that did not change still matches");
    setDate(b, T0);

    // Rereading: contents, additions and removals, at any depth.
    NSFileWrapper *aBefore = aWrapper;
    NSFileWrapper *subBefore = subWrapper;
    put(a, @"changed");
    setDate(a, T0 + 100);
    put([dir stringByAppendingPathComponent:@"new.txt"], @"fresh");
    [fm removeItemAtPath:b error:NULL];
    put([sub stringByAppendingPathComponent:@"deeper.txt"], @"deep");
    [fm removeItemAtPath:link error:NULL];
    symlink("/somewhere/else", [link fileSystemRepresentation]);
    setDate(link, T0 + 100);
    setDate(sub, T0 + 100);
    setDate(dir, T0 + 100);

    expect(![wrapper matchesContentsOfURL:dirURL], "the directory no longer matches");
    error = nil;
    expect([wrapper readFromURL:dirURL options:NSFileWrapperReadingImmediate error:&error], "the directory is reread");
    expect(error == nil, "a successful reread sets no error");
    expect([wrapper matchesContentsOfURL:dirURL], "the directory matches after the reread");
    NSDictionary *children = [wrapper fileWrappers];
    NSSet *names = [NSSet setWithArray:[children allKeys]];
    expect([names isEqualToSet:[NSSet setWithObjects:@"a.txt", @"sub", @"new.txt", @"link", @"gone.txt", nil]], "children were added and removed to match the directory");
    expect([children objectForKey:@"a.txt"] == aBefore && [children objectForKey:@"sub"] == subBefore,
           "the wrappers of nodes that remain are kept");
    expect([text([children objectForKey:@"a.txt"]) isEqualToString:@"changed"], "the contents of a kept file were reread");
    expect([text([children objectForKey:@"new.txt"]) isEqualToString:@"fresh"], "a new file has its contents");
    expect([[[children objectForKey:@"new.txt"] filename] isEqualToString:@"new.txt"], "a new child records its filename");
    NSDictionary *inner = [[children objectForKey:@"sub"] fileWrappers];
    expect([[NSSet setWithArray:[inner allKeys]] isEqualToSet:[NSSet setWithObject:@"deeper.txt"]], "the reread is recursive");
    expect([[[[children objectForKey:@"link"] symbolicLinkDestinationURL] path] isEqualToString:@"/somewhere/else"], "a link has its new destination");
    expect([[[[wrapper fileAttributes] objectForKey:NSFileModificationDate] description] isEqualToString:[dateAt(T0 + 100) description]], "the recorded attributes are the node's");

    // Immediate reading took the contents now: they survive the file going away.
    [fm removeItemAtPath:a error:NULL];
    expect([text([children objectForKey:@"a.txt"]) isEqualToString:@"changed"], "NSFileWrapperReadingImmediate read the contents in advance");

    // The contents of a wrapper that still matches are not read again, its attributes are (observed on macOS).
    put(a, @"again");
    setDate(a, T0 + 100);
    expect([[children objectForKey:@"a.txt"] matchesContentsOfURL:aURL], "(setup) the file has the recorded date");
    expect([wrapper readFromURL:dirURL options:NSFileWrapperReadingImmediate error:NULL], "a reread of what matches succeeds");
    expect([text([children objectForKey:@"a.txt"]) isEqualToString:@"changed"], "and does not read the contents of a file that still matches");
    chmod([a fileSystemRepresentation], 0600);
    NSFileWrapper *aFile = [children objectForKey:@"a.txt"];
    expect([aFile readFromURL:aURL options:NSFileWrapperReadingImmediate error:NULL], "rereading one file");
    expect([[[aFile fileAttributes] objectForKey:NSFilePosixPermissions] intValue] == 0600, "takes up the changed permissions");
    expect([text(aFile) isEqualToString:@"changed"], "without reading the contents");
    setDate(a, T0 + 200);
    expect([aFile readFromURL:aURL options:NSFileWrapperReadingImmediate error:NULL] && [text(aFile) isEqualToString:@"again"], "and reads them once the date has moved");

    // A directory is always enumerated: an entry added while the directory still matches is found by a reread.
    // Observed on macOS 26.1 (probe 147.R3), and on 26.7.3 and 10.14.4 (x86_64 and i386): the new entry appeared, a
    // child whose date still matched kept its contents.
    NSString *added = [dir stringByAppendingPathComponent:@"extra-entry.txt"];
    put(added, @"extra");
    setDate(added, T0 + 100);
    NSDate *recorded = [[wrapper fileAttributes] objectForKey:NSFileModificationDate];
    setDate(dir, [recorded timeIntervalSince1970]);
    NSFileWrapper *keptA = [[wrapper fileWrappers] objectForKey:@"a.txt"];
    expect([wrapper matchesContentsOfURL:dirURL], "(setup) the directory still matches with an entry it lacks");
    expect([wrapper readFromURL:dirURL options:NSFileWrapperReadingImmediate error:NULL], "a directory that matches is reread");
    expect([text([[wrapper fileWrappers] objectForKey:@"extra-entry.txt"]) isEqualToString:@"extra"], "and its new entry is found");
    expect([[wrapper fileWrappers] objectForKey:@"a.txt"] == keptA, "while the existing child stays the same wrapper");
    [fm removeItemAtPath:added error:NULL];
    setDate(dir, [recorded timeIntervalSince1970]);
    expect([wrapper readFromURL:dirURL options:0 error:NULL] && [[wrapper fileWrappers] objectForKey:@"extra-entry.txt"] == nil, "and a removed entry is dropped (a guard: this holds without the change too)");

    // A child whose node changed kind (a file replaced by a directory of the same name) is replaced here.
    [fm removeItemAtPath:[dir stringByAppendingPathComponent:@"new.txt"] error:NULL];
    [fm createDirectoryAtPath:[dir stringByAppendingPathComponent:@"new.txt"] withIntermediateDirectories:NO attributes:nil error:NULL];
    setDate([dir stringByAppendingPathComponent:@"new.txt"], T0 + 300);
    expect([wrapper readFromURL:dirURL options:0 error:NULL], "a directory with a child that changed kind is reread");
    expect([[[wrapper fileWrappers] objectForKey:@"new.txt"] isDirectory], "the child that changed kind is a directory wrapper now");

    // An existing child that cannot be reread does not fail the read of the directory (observed on macOS).
    if (geteuid() != 0) {
        NSString *z = [dir stringByAppendingPathComponent:@"z.txt"];
        put(z, @"z1");
        setDate(z, T0);
        setDate(dir, T0 + 400);
        expect([wrapper readFromURL:dirURL options:NSFileWrapperReadingImmediate error:NULL], "(setup) a new child is read");
        NSFileWrapper *zWrapper = [[wrapper fileWrappers] objectForKey:@"z.txt"];
        // written as a new file: the first contents may be mapped from the old one, which an in-place write would change
        [@"z2" writeToFile:z atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        setDate(z, T0 + 500);
        chmod([z fileSystemRepresentation], 0);
        setDate(dir, T0 + 500);
        error = nil;
        expect([wrapper readFromURL:dirURL options:NSFileWrapperReadingImmediate error:&error] && error == nil, "an unreadable child does not fail the read of the directory");
        expect([[wrapper fileWrappers] objectForKey:@"z.txt"] == zWrapper && [text(zWrapper) isEqualToString:@"z1"], "and keeps what it had");
        chmod([z fileSystemRepresentation], 0644);
    }

    // A child whose node became a link becomes a link wrapper (same object), as on macOS.
    NSString *swap = [dir stringByAppendingPathComponent:@"z.txt"];
    if (geteuid() != 0) {
        NSFileWrapper *zKept = [[wrapper fileWrappers] objectForKey:@"z.txt"];
        [fm removeItemAtPath:swap error:NULL];
        symlink("/swap/destination", [swap fileSystemRepresentation]);
        setDate(swap, T0 + 800);
        setDate(dir, T0 + 800);
        expect([wrapper readFromURL:dirURL options:0 error:NULL], "a directory with a child that became a link is reread");
        NSFileWrapper *zNow = [[wrapper fileWrappers] objectForKey:@"z.txt"];
        expect(zNow == zKept && [zNow isSymbolicLink] && ![zNow isRegularFile] &&
               [[[zNow symbolicLinkDestinationURL] path] isEqualToString:@"/swap/destination"], "the child is the same wrapper, now a link wrapper");
    }

    // A wrapper becomes the kind of a regular file or link it reads (observed on macOS 26.7.3 and 10.14.4).
    NSURL *swapURL = [NSURL fileURLWithPath:swap];
    NSFileWrapper *becomesLink = [[[NSFileWrapper alloc] initWithURL:aURL options:0 error:NULL] autorelease];
    NSFileWrapper *becomesLinkFromDir = [[[NSFileWrapper alloc] initWithURL:dirURL options:0 error:NULL] autorelease];
    error = nil;
    expect([becomesLink readFromURL:swapURL options:0 error:&error] && error == nil && [becomesLink isSymbolicLink] && ![becomesLink isRegularFile],
           "a regular file wrapper that reads a link becomes a link wrapper");
    expect([[[becomesLink symbolicLinkDestinationURL] path] isEqualToString:@"/swap/destination"] &&
           [[[becomesLink fileAttributes] objectForKey:NSFileType] isEqualToString:NSFileTypeSymbolicLink], "with the link's destination and attributes");
    expect([becomesLinkFromDir readFromURL:swapURL options:0 error:NULL] && [becomesLinkFromDir isSymbolicLink] && ![becomesLinkFromDir isDirectory] &&
           [[[becomesLinkFromDir symbolicLinkDestinationURL] path] isEqualToString:@"/swap/destination"], "so does a directory wrapper");
    expect([becomesLink readFromURL:aURL options:NSFileWrapperReadingImmediate error:NULL] && [becomesLink isRegularFile] && ![becomesLink isSymbolicLink] &&
           [text(becomesLink) isEqualToString:@"again"], "a link wrapper that reads a regular file becomes a regular file wrapper with its contents");
    expect([becomesLinkFromDir readFromURL:aURL options:0 error:NULL] && [becomesLinkFromDir isRegularFile] && ![becomesLinkFromDir isDirectory] &&
           [text(becomesLinkFromDir) isEqualToString:@"again"], "and so does a directory wrapper");
    expect([becomesLink matchesContentsOfURL:aURL] && ![becomesLink matchesContentsOfURL:swapURL], "the converted wrapper matches what it read");
    expect([text(becomesLink) length] == 5, "and can be read as a regular file");
    unlink([swap fileSystemRepresentation]);

    // A directory read into a wrapper that is not one fails and leaves the wrapper as it was (macOS raises).
    NSFileWrapper *file = [[[NSFileWrapper alloc] initWithURL:aURL options:0 error:NULL] autorelease];
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

    // A regular file wrapper rereads its own file once its date has moved.
    put(a, @"third");
    setDate(a, T0 + 600);
    expect(![file matchesContentsOfURL:aURL], "the file wrapper no longer matches its changed file");
    expect([file readFromURL:aURL options:0 error:NULL] && [text(file) isEqualToString:@"third"], "the file wrapper rereads it");
    expect([file matchesContentsOfURL:aURL], "and matches it again");

    // A link wrapper rereads the destination once its date has moved.
    NSFileWrapper *reader = [[[NSFileWrapper alloc] initWithURL:linkURL options:0 error:NULL] autorelease];
    [fm removeItemAtPath:link error:NULL];
    symlink("/another/place", [link fileSystemRepresentation]);
    setDate(link, T0 + 700);
    expect(![reader matchesContentsOfURL:linkURL], "a link wrapper does not match a link with another date");
    expect([reader readFromURL:linkURL options:0 error:NULL] &&
           [[[reader symbolicLinkDestinationURL] path] isEqualToString:@"/another/place"], "the link wrapper rereads the destination");
    expect([reader matchesContentsOfURL:linkURL], "and matches it again");

    [fm removeItemAtPath:dir error:NULL];
    [outer drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
