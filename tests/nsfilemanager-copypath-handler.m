// -[NSFileManager copyPath:toPath:handler:] as observed on macOS 10.14.4 (x86_64 and i386) and 26.7.3 (identical on all):
// the handler hears -fileManager:willProcessPath: for every item with its destination path (a directory before its
// entries) before that destination exists, and -fileManager:shouldProceedAfterError: with a dictionary of exactly
// @"Path" and @"Error"; the destination's parent must exist and the destination must not; a YES answer continues with
// the next item and the call returns YES, a NO answer stops it and returns NO; without a handler or the error callback
// an error gives NO; a nil path gives NO, or raises NSInvalidArgumentException when the handler has the error callback. See the QUIRK comment in src/NSFileManager.m.
// Link and permission handling follows the documented contract (links are copied as links).
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

static int failures;
#define CHECK(cond, label) do { if (!(cond)) { printf("FAIL %s (line %d)\n", label, __LINE__); failures++; } } while (0)

static void put(NSString *path, NSString *text)
{
    [text writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

static NSString *get(NSString *path)
{
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
}

@interface RecordingHandler : NSObject
{
@public
    NSMutableArray *processed;
    NSMutableArray *errors;
    BOOL proceed;
    NSString *watchedPath;
    BOOL watchedPathExistedAtCallback;
}
@end

@implementation RecordingHandler

- (instancetype)init
{
    self = [super init];
    processed = [[NSMutableArray alloc] init];
    errors = [[NSMutableArray alloc] init];
    return self;
}

- (void)fileManager:(NSFileManager *)fm willProcessPath:(NSString *)path
{
    [processed addObject:path];
    if (watchedPath != nil)
    {
        watchedPathExistedAtCallback = [fm fileExistsAtPath:watchedPath];
    }
}

- (BOOL)fileManager:(NSFileManager *)fm shouldProceedAfterError:(NSDictionary *)errorInfo
{
    [errors addObject:errorInfo];
    return proceed;
}

@end

// Answers only the error callback.
@interface ErrorOnlyHandler : NSObject
{
@public
    int errorCalls;
}
@end

@implementation ErrorOnlyHandler

- (BOOL)fileManager:(NSFileManager *)fm shouldProceedAfterError:(NSDictionary *)errorInfo
{
    errorCalls++;
    return YES;
}

@end

// Answers only the progress callback, so an error has no handler to ask.
@interface ProgressOnlyHandler : NSObject
{
@public
    int processedCalls;
}
@end

@implementation ProgressOnlyHandler

- (void)fileManager:(NSFileManager *)fm willProcessPath:(NSString *)path
{
    processedCalls++;
}

@end

static BOOL raisesInvalidArgument(void (^block)(void))
{
    @try { block(); }
    @catch (NSException *e) { return [[e name] isEqualToString:NSInvalidArgumentException]; }
    return NO;
}

static NSString *errorPath(RecordingHandler *h, NSUInteger i) { return i < [h->errors count] ? h->errors[i][@"Path"] : nil; }
static NSString *errorText(RecordingHandler *h, NSUInteger i) { return i < [h->errors count] ? h->errors[i][@"Error"] : nil; }

static void run(NSString *root)
{
    NSFileManager *fm = [NSFileManager defaultManager];

    // A file is copied with its contents; the handler hears about the destination path before it exists.
    NSString *file = [root stringByAppendingPathComponent:@"file"];
    NSString *fileCopy = [root stringByAppendingPathComponent:@"file-copy"];
    put(file, @"abc");
    RecordingHandler *handler = [[RecordingHandler alloc] init];
    handler->watchedPath = fileCopy;
    CHECK([fm copyPath:file toPath:fileCopy handler:handler], "copy a file returns YES");
    CHECK([get(fileCopy) isEqual:@"abc"], "copied file holds the source contents");
    CHECK([get(file) isEqual:@"abc"], "source file is left in place");
    CHECK([handler->processed isEqual:@[ fileCopy ]], "willProcessPath: is sent once, with the destination path");
    CHECK(handler->watchedPath != nil && !handler->watchedPathExistedAtCallback, "willProcessPath: is sent before the destination exists");
    CHECK([handler->errors count] == 0, "no error callback for a successful copy");

    // A nil handler is allowed.
    NSString *nilHandlerCopy = [root stringByAppendingPathComponent:@"nil-handler-copy"];
    CHECK([fm copyPath:file toPath:nilHandlerCopy handler:nil], "copy with a nil handler returns YES");
    CHECK([get(nilHandlerCopy) isEqual:@"abc"], "nil handler copy holds the contents");

    // A directory is copied with everything under it; a symbolic link is copied as a link, not followed. The handler
    // hears about each item (destination path), a directory before its entries; the entry order is the directory order.
    NSString *src = [root stringByAppendingPathComponent:@"src"];
    [fm createDirectoryAtPath:[src stringByAppendingPathComponent:@"sub"] withIntermediateDirectories:YES attributes:nil error:NULL];
    put([src stringByAppendingPathComponent:@"top"], @"top");
    put([src stringByAppendingPathComponent:@"sub/inner"], @"inner");
    symlink("sub/inner", [[src stringByAppendingPathComponent:@"link"] fileSystemRepresentation]);
    NSString *tree = [root stringByAppendingPathComponent:@"tree"];
    RecordingHandler *treeHandler = [[RecordingHandler alloc] init];
    treeHandler->watchedPath = tree;
    CHECK([fm copyPath:src toPath:tree handler:treeHandler], "copy a directory tree returns YES");
    CHECK([get([tree stringByAppendingPathComponent:@"top"]) isEqual:@"top"], "top-level file copied");
    CHECK([get([tree stringByAppendingPathComponent:@"sub/inner"]) isEqual:@"inner"], "nested file copied");
    NSDictionary *linkAttributes = [fm attributesOfItemAtPath:[tree stringByAppendingPathComponent:@"link"] error:NULL];
    CHECK([linkAttributes[NSFileType] isEqual:NSFileTypeSymbolicLink], "symbolic link copied as a link");
    CHECK([[fm destinationOfSymbolicLinkAtPath:[tree stringByAppendingPathComponent:@"link"] error:NULL] isEqual:@"sub/inner"], "link target text preserved");
    NSSet *expectedProcessed = [NSSet setWithObjects:tree, [tree stringByAppendingPathComponent:@"top"], [tree stringByAppendingPathComponent:@"sub"],
                                [tree stringByAppendingPathComponent:@"sub/inner"], [tree stringByAppendingPathComponent:@"link"], nil];
    CHECK([treeHandler->processed count] == 5 && [[NSSet setWithArray:treeHandler->processed] isEqual:expectedProcessed],
          "willProcessPath: is sent once for every item, with its destination path");
    CHECK([[treeHandler->processed firstObject] isEqual:tree], "the directory is announced before its entries");
    NSUInteger subIndex = [treeHandler->processed indexOfObject:[tree stringByAppendingPathComponent:@"sub"]];
    NSUInteger innerIndex = [treeHandler->processed indexOfObject:[tree stringByAppendingPathComponent:@"sub/inner"]];
    CHECK(subIndex != NSNotFound && innerIndex != NSNotFound && subIndex < innerIndex, "a subdirectory is announced before its entries");
    CHECK([treeHandler->errors count] == 0, "no error callback for a successful tree copy");

    // The destination must not exist: nothing is overwritten. A handler answering NO makes the result NO; the error
    // callback gets exactly @"Path" (the destination) and @"Error".
    NSString *existing = [root stringByAppendingPathComponent:@"existing"];
    put(existing, @"old");
    RecordingHandler *refusing = [[RecordingHandler alloc] init];
    refusing->proceed = NO;
    CHECK(![fm copyPath:file toPath:existing handler:refusing], "existing destination: handler answering NO gives NO");
    CHECK([get(existing) isEqual:@"old"], "existing destination is not overwritten");
    CHECK([refusing->errors count] == 1, "existing destination: one error callback");
    NSSet *keys = [NSSet setWithArray:[[refusing->errors firstObject] allKeys]];
    CHECK(([keys isEqual:[NSSet setWithObjects:@"Path", @"Error", nil]]), "errorInfo has exactly @\"Path\" and @\"Error\"");
    CHECK([errorPath(refusing, 0) isEqual:existing], "existing destination: @\"Path\" is the destination");
    CHECK([errorText(refusing, 0) isEqual:@"Couldn't create"], "existing destination: @\"Error\" for a file");
    CHECK([refusing->processed isEqual:@[ existing ]], "willProcessPath: is also sent when the copy then fails");

    // A YES from the error callback makes the call return YES.
    RecordingHandler *forgiving = [[RecordingHandler alloc] init];
    forgiving->proceed = YES;
    CHECK([fm copyPath:file toPath:existing handler:forgiving], "existing destination: handler answering YES gives YES");
    CHECK([forgiving->errors count] == 1, "existing destination: forgiving handler consulted once");
    CHECK([get(existing) isEqual:@"old"], "existing destination still not overwritten");

    // A nil handler with an error returns NO; so does a handler that lacks the error callback.
    CHECK(![fm copyPath:file toPath:existing handler:nil], "existing destination with a nil handler gives NO");
    ProgressOnlyHandler *progressOnly = [[ProgressOnlyHandler alloc] init];
    CHECK(![fm copyPath:file toPath:existing handler:progressOnly], "handler without the error callback gives NO");
    CHECK(progressOnly->processedCalls == 1, "progress-only handler still hears willProcessPath:");
    ErrorOnlyHandler *errorOnly = [[ErrorOnlyHandler alloc] init];
    NSString *errorOnlyCopy = [root stringByAppendingPathComponent:@"error-only-copy"];
    CHECK([fm copyPath:file toPath:errorOnlyCopy handler:errorOnly], "handler without willProcessPath: copies fine");
    CHECK(errorOnly->errorCalls == 0, "no error callback when nothing failed");

    // An existing destination directory for a directory source: the directory text, and the entries are not copied.
    NSString *existingDir = [root stringByAppendingPathComponent:@"existing-dir"];
    [fm createDirectoryAtPath:existingDir withIntermediateDirectories:NO attributes:nil error:NULL];
    RecordingHandler *dirForgiving = [[RecordingHandler alloc] init];
    dirForgiving->proceed = YES;
    CHECK([fm copyPath:src toPath:existingDir handler:dirForgiving], "existing destination directory: handler answering YES gives YES");
    CHECK([errorText(dirForgiving, 0) isEqual:@"Couldn't create directory"] && [errorPath(dirForgiving, 0) isEqual:existingDir],
          "existing destination directory: @\"Error\" for a directory");
    CHECK([[fm contentsOfDirectoryAtPath:existingDir error:NULL] count] == 0, "existing destination directory: nothing copied into it");

    // The source must exist: its path is reported, and the progress callback is not sent.
    NSString *missing = [root stringByAppendingPathComponent:@"missing"];
    NSString *missingCopy = [root stringByAppendingPathComponent:@"missing-copy"];
    CHECK(![fm copyPath:missing toPath:missingCopy handler:nil], "missing source with a nil handler gives NO");
    CHECK(![fm fileExistsAtPath:missingCopy], "no destination appears for a missing source");
    RecordingHandler *missingHandler = [[RecordingHandler alloc] init];
    missingHandler->proceed = YES;
    CHECK([fm copyPath:missing toPath:missingCopy handler:missingHandler], "missing source: handler answering YES gives YES");
    CHECK([errorPath(missingHandler, 0) isEqual:missing] && [errorText(missingHandler, 0) isEqual:@"Couldn't open"], "missing source: @\"Path\" is the source");
    CHECK([missingHandler->processed count] == 0, "missing source: no willProcessPath:");

    // The destination's parent must be an existing directory: a missing parent is not created, and a regular file as a
    // parent is no better. The parent is the reported path, the progress callback is not sent.
    RecordingHandler *noParent = [[RecordingHandler alloc] init];
    NSString *absentParent = [root stringByAppendingPathComponent:@"absent/dir"];
    CHECK(![fm copyPath:file toPath:[absentParent stringByAppendingPathComponent:@"x"] handler:noParent], "missing destination parent gives NO");
    CHECK(![fm fileExistsAtPath:absentParent], "missing destination parent is not created");
    CHECK([errorPath(noParent, 0) isEqual:absentParent] && [errorText(noParent, 0) isEqual:@"Couldn't open"], "missing destination parent: the parent is reported");
    CHECK([noParent->processed count] == 0, "missing destination parent: no willProcessPath:");
    RecordingHandler *blocked = [[RecordingHandler alloc] init];
    NSString *underFile = [file stringByAppendingPathComponent:@"child"];
    CHECK(![fm copyPath:file toPath:underFile handler:blocked], "destination under a regular file gives NO");
    CHECK([errorPath(blocked, 0) isEqual:file], "destination under a regular file: the file is reported as the parent");
    CHECK(![fm copyPath:file toPath:underFile handler:nil], "destination under a regular file with a nil handler gives NO");

    // A nil path is an error without a path: NO without a handler, and an exception when the handler has the error callback.
    CHECK(![fm copyPath:nil toPath:[root stringByAppendingPathComponent:@"nil-src"] handler:nil], "nil source with a nil handler gives NO");
    CHECK(![fm copyPath:file toPath:nil handler:nil], "nil destination with a nil handler gives NO");
    CHECK(raisesInvalidArgument(^{ (void)[fm copyPath:nil toPath:[root stringByAppendingPathComponent:@"nil-src"] handler:[[RecordingHandler alloc] init]]; }), "nil source with an error callback raises");
    CHECK(raisesInvalidArgument(^{ (void)[fm copyPath:file toPath:nil handler:[[RecordingHandler alloc] init]]; }), "nil destination with an error callback raises");
    CHECK(![fm copyPath:nil toPath:[root stringByAppendingPathComponent:@"nil-src"] handler:progressOnly], "nil source with a handler lacking the error callback gives NO");

    // An item that cannot be copied in the middle of a tree: NO stops the copy, YES goes on with the next items.
    NSString *mid = [root stringByAppendingPathComponent:@"mid"];
    [fm createDirectoryAtPath:mid withIntermediateDirectories:NO attributes:nil error:NULL];
    for (NSString *name in @[ @"a", @"b", @"c" ]) put([mid stringByAppendingPathComponent:name], name);
    chmod([[mid stringByAppendingPathComponent:@"b"] fileSystemRepresentation], 0);
    if (access([[mid stringByAppendingPathComponent:@"b"] fileSystemRepresentation], R_OK) != 0)
    {
        RecordingHandler *stopping = [[RecordingHandler alloc] init];
        CHECK(![fm copyPath:mid toPath:[root stringByAppendingPathComponent:@"mid-no"] handler:stopping], "unreadable entry: handler answering NO gives NO");
        CHECK([stopping->errors count] == 1, "unreadable entry: one error callback");
        CHECK([errorPath(stopping, 0) isEqual:[[root stringByAppendingPathComponent:@"mid-no"] stringByAppendingPathComponent:@"b"]], "unreadable entry: the destination item is reported");
        RecordingHandler *going = [[RecordingHandler alloc] init];
        going->proceed = YES;
        NSString *midYes = [root stringByAppendingPathComponent:@"mid-yes"];
        CHECK([fm copyPath:mid toPath:midYes handler:going], "unreadable entry: handler answering YES gives YES");
        CHECK([going->errors count] == 1, "unreadable entry: one error callback with YES");
        CHECK([get([midYes stringByAppendingPathComponent:@"a"]) isEqual:@"a"] && [get([midYes stringByAppendingPathComponent:@"c"]) isEqual:@"c"],
              "unreadable entry: the other entries are copied after a YES");
    }
    else
    {
        printf("SKIP unreadable-entry checks: the file is still readable (running as root)\n");
    }
    chmod([[mid stringByAppendingPathComponent:@"b"] fileSystemRepresentation], 0600);

    // A source that is itself a symbolic link is copied as a link, not followed.
    NSString *topLink = [root stringByAppendingPathComponent:@"top-link"];
    NSString *topLinkCopy = [root stringByAppendingPathComponent:@"top-link-copy"];
    symlink("file", [topLink fileSystemRepresentation]);
    CHECK([fm copyPath:topLink toPath:topLinkCopy handler:nil], "copy a symbolic link returns YES");
    CHECK([[fm destinationOfSymbolicLinkAtPath:topLinkCopy error:NULL] isEqual:@"file"], "a symbolic link source is copied as a link");

    // File and directory permissions are copied.
    NSString *modeSrc = [root stringByAppendingPathComponent:@"mode-src"];
    NSString *modeCopy = [root stringByAppendingPathComponent:@"mode-copy"];
    put(modeSrc, @"m");
    chmod([modeSrc fileSystemRepresentation], 0640);
    CHECK([fm copyPath:modeSrc toPath:modeCopy handler:nil], "copy a file with a mode returns YES");
    CHECK(([[fm attributesOfItemAtPath:modeCopy error:NULL][NSFilePosixPermissions] unsignedIntegerValue] & 0777) == 0640, "file permissions are copied");
    NSString *dirModeSrc = [root stringByAppendingPathComponent:@"dir-mode-src"];
    NSString *dirModeCopy = [root stringByAppendingPathComponent:@"dir-mode-copy"];
    [fm createDirectoryAtPath:dirModeSrc withIntermediateDirectories:NO attributes:nil error:NULL];
    chmod([dirModeSrc fileSystemRepresentation], 0750);
    CHECK([fm copyPath:dirModeSrc toPath:dirModeCopy handler:nil], "copy a directory with a mode returns YES");
    CHECK(([[fm attributesOfItemAtPath:dirModeCopy error:NULL][NSFilePosixPermissions] unsignedIntegerValue] & 0777) == 0750, "directory permissions are copied");
}

int main(void)
{
    @autoreleasepool {
        char tmpl[] = "/tmp/fm-copypath-handler-XXXXXX";
        NSString *root = [NSString stringWithUTF8String:mkdtemp(tmpl)];
        @try
        {
            run(root);
        }
        @finally
        {
            [[NSFileManager defaultManager] removeItemAtPath:root error:NULL];
        }
    }
    return failures != 0;
}
