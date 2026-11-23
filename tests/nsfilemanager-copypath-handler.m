// -[NSFileManager copyPath:toPath:handler:] against the documented contract: the source must exist and
// the destination must not, a directory is copied recursively with symbolic links copied as links, the
// handler hears -fileManager:willProcessPath: when the copy begins and -fileManager:shouldProceedAfterError:
// (a dictionary with @"Path", @"Error" and @"ToPath") on an error, a nil handler turns an error into NO,
// and the handler's answer is the result. Counts are checked as "at least once", and @"Path" only as a
// non-empty string, because the pages say "usually the source path" and "for each error". What the pages
// do not state (a nil path, the text of @"Error", callbacks for the entries inside a directory, a
// destination inside the source) is not tested. Not yet run on macOS.
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

static void run(NSString *root)
{
    NSFileManager *fm = [NSFileManager defaultManager];

    // A file is copied with its contents; the handler hears about the source path before the copy happens.
    NSString *file = [root stringByAppendingPathComponent:@"file"];
    NSString *fileCopy = [root stringByAppendingPathComponent:@"file-copy"];
    put(file, @"abc");
    RecordingHandler *handler = [[RecordingHandler alloc] init];
    handler->watchedPath = fileCopy;
    CHECK([fm copyPath:file toPath:fileCopy handler:handler], "copy a file returns YES");
    CHECK([get(fileCopy) isEqual:@"abc"], "copied file holds the source contents");
    CHECK([get(file) isEqual:@"abc"], "source file is left in place");
    CHECK([handler->processed containsObject:file], "willProcessPath: is sent with the source path");
    CHECK(handler->watchedPath != nil && !handler->watchedPathExistedAtCallback, "willProcessPath: is sent before the destination exists");
    CHECK([handler->errors count] == 0, "no error callback for a successful copy");

    // A nil handler is allowed.
    NSString *nilHandlerCopy = [root stringByAppendingPathComponent:@"nil-handler-copy"];
    CHECK([fm copyPath:file toPath:nilHandlerCopy handler:nil], "copy with a nil handler returns YES");
    CHECK([get(nilHandlerCopy) isEqual:@"abc"], "nil handler copy holds the contents");

    // A directory is copied with everything under it; a symbolic link is copied as a link, not followed.
    NSString *src = [root stringByAppendingPathComponent:@"src"];
    [fm createDirectoryAtPath:[src stringByAppendingPathComponent:@"sub"] withIntermediateDirectories:YES attributes:nil error:NULL];
    put([src stringByAppendingPathComponent:@"top"], @"top");
    put([src stringByAppendingPathComponent:@"sub/inner"], @"inner");
    symlink("sub/inner", [[src stringByAppendingPathComponent:@"link"] fileSystemRepresentation]);
    NSString *tree = [root stringByAppendingPathComponent:@"tree"];
    CHECK([fm copyPath:src toPath:tree handler:nil], "copy a directory tree returns YES");
    CHECK([get([tree stringByAppendingPathComponent:@"top"]) isEqual:@"top"], "top-level file copied");
    CHECK([get([tree stringByAppendingPathComponent:@"sub/inner"]) isEqual:@"inner"], "nested file copied");
    NSDictionary *linkAttributes = [fm attributesOfItemAtPath:[tree stringByAppendingPathComponent:@"link"] error:NULL];
    CHECK([linkAttributes[NSFileType] isEqual:NSFileTypeSymbolicLink], "symbolic link copied as a link");
    CHECK([[fm destinationOfSymbolicLinkAtPath:[tree stringByAppendingPathComponent:@"link"] error:NULL] isEqual:@"sub/inner"], "link target text preserved");

    // The destination must not exist: the copy fails and nothing is overwritten. With a handler that
    // answers NO, the error callback is consulted with the documented keys and the result is NO.
    NSString *existing = [root stringByAppendingPathComponent:@"existing"];
    put(existing, @"old");
    RecordingHandler *refusing = [[RecordingHandler alloc] init];
    refusing->proceed = NO;
    CHECK(![fm copyPath:file toPath:existing handler:refusing], "existing destination: handler answering NO gives NO");
    CHECK([get(existing) isEqual:@"old"], "existing destination is not overwritten");
    CHECK([refusing->errors count] >= 1, "existing destination: error callback consulted");
    NSDictionary *info = [refusing->errors firstObject];
    CHECK([info[@"Path"] isKindOfClass:[NSString class]] && [info[@"Path"] length] > 0, "errorInfo @\"Path\" is a non-empty string");
    CHECK(info[@"ToPath"] == nil || [info[@"ToPath"] isKindOfClass:[NSString class]], "errorInfo @\"ToPath\", when present, is a string");
    CHECK([info[@"Error"] isKindOfClass:[NSString class]] && [info[@"Error"] length] > 0, "errorInfo @\"Error\" is a non-empty string");
    CHECK([refusing->processed containsObject:file], "willProcessPath: also sent when the copy then fails");

    // If the handler's error callback answers YES, the method also returns YES.
    RecordingHandler *forgiving = [[RecordingHandler alloc] init];
    forgiving->proceed = YES;
    CHECK([fm copyPath:file toPath:existing handler:forgiving], "existing destination: handler answering YES gives YES");
    CHECK([forgiving->errors count] >= 1, "existing destination: forgiving handler consulted");
    CHECK([get(existing) isEqual:@"old"], "existing destination still not overwritten");

    // A nil handler with an error returns NO; so does a handler that lacks the error callback.
    CHECK(![fm copyPath:file toPath:existing handler:nil], "existing destination with a nil handler gives NO");
    ProgressOnlyHandler *progressOnly = [[ProgressOnlyHandler alloc] init];
    CHECK(![fm copyPath:file toPath:existing handler:progressOnly], "handler without the error callback gives NO");
    CHECK(progressOnly->processedCalls >= 1, "progress-only handler still hears willProcessPath:");
    ErrorOnlyHandler *errorOnly = [[ErrorOnlyHandler alloc] init];
    NSString *errorOnlyCopy = [root stringByAppendingPathComponent:@"error-only-copy"];
    CHECK([fm copyPath:file toPath:errorOnlyCopy handler:errorOnly], "handler without willProcessPath: copies fine");
    CHECK(errorOnly->errorCalls == 0, "no error callback when nothing failed");

    // The source must exist.
    NSString *missing = [root stringByAppendingPathComponent:@"missing"];
    NSString *missingCopy = [root stringByAppendingPathComponent:@"missing-copy"];
    CHECK(![fm copyPath:missing toPath:missingCopy handler:nil], "missing source with a nil handler gives NO");
    CHECK(![fm fileExistsAtPath:missingCopy], "no destination appears for a missing source");
    RecordingHandler *missingHandler = [[RecordingHandler alloc] init];
    missingHandler->proceed = NO;
    CHECK(![fm copyPath:missing toPath:missingCopy handler:missingHandler], "missing source: handler answering NO gives NO");
    CHECK([missingHandler->errors count] >= 1, "missing source: error callback consulted");
    CHECK([missingHandler->errors[0][@"Path"] length] > 0, "missing source: @\"Path\" is a non-empty string");

    // A destination whose parent is a regular file cannot be created: NO, and the handler is asked.
    RecordingHandler *blocked = [[RecordingHandler alloc] init];
    blocked->proceed = NO;
    NSString *underFile = [file stringByAppendingPathComponent:@"child"];
    CHECK(![fm copyPath:file toPath:underFile handler:blocked], "destination under a regular file gives NO");
    CHECK([blocked->errors count] >= 1, "destination under a regular file: error callback consulted");
    CHECK([blocked->errors[0][@"Error"] isKindOfClass:[NSString class]], "destination under a regular file: @\"Error\" is a string");
    CHECK(![fm copyPath:file toPath:underFile handler:nil], "destination under a regular file with a nil handler gives NO");

    // A source that is itself a symbolic link is copied as a link, not followed.
    NSString *topLink = [root stringByAppendingPathComponent:@"top-link"];
    NSString *topLinkCopy = [root stringByAppendingPathComponent:@"top-link-copy"];
    symlink("file", [topLink fileSystemRepresentation]);
    CHECK([fm copyPath:topLink toPath:topLinkCopy handler:nil], "copy a symbolic link returns YES");
    CHECK([[fm destinationOfSymbolicLinkAtPath:topLinkCopy error:NULL] isEqual:@"file"], "a symbolic link source is copied as a link");

    // File attributes such as permissions are copied.
    NSString *modeSrc = [root stringByAppendingPathComponent:@"mode-src"];
    NSString *modeCopy = [root stringByAppendingPathComponent:@"mode-copy"];
    put(modeSrc, @"m");
    chmod([modeSrc fileSystemRepresentation], 0640);
    CHECK([fm copyPath:modeSrc toPath:modeCopy handler:nil], "copy a file with a mode returns YES");
    CHECK(([[fm attributesOfItemAtPath:modeCopy error:NULL][NSFilePosixPermissions] unsignedIntegerValue] & 0777) == 0640, "file permissions are copied");
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
