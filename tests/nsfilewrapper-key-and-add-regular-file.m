// -[NSFileWrapper keyForFileWrapper:] and -[NSFileWrapper addRegularFileWithContents:preferredFilename:].
// Contract: developer.apple.com/documentation/foundation/filewrapper/keyforchildfilewrapper(_:) (the Swift name of
// -keyForFileWrapper:) and developer.apple.com/documentation/foundation/filewrapper/addregularfile(withcontents:preferredfilename:).
// The key is the unique name a directory stores a child under, nil when the wrapper is not a child of the
// directory; adding a regular file is a convenience for creating the wrapper, giving it the preferred name and
// adding it with -addFileWrapper:, returning that key; both raise NSInternalInconsistencyException on a wrapper
// that is not a directory, and the add raises NSInvalidArgumentException for a nil or empty name.
// Built without ARC.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expect(BOOL ok, const char *what)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok)
        failures++;
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *e) {
        return [e name];
    }
    return nil;
}

int main(void)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSData *one = [@"one" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *two = [@"two" dataUsingEncoding:NSUTF8StringEncoding];

    NSFileWrapper *dir = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{}];
    NSString *key1 = [dir addRegularFileWithContents:one preferredFilename:@"a.txt"];
    expect([key1 isEqualToString:@"a.txt"], "a free preferred name is the key it is added under");
    NSFileWrapper *child1 = [[dir fileWrappers] objectForKey:key1];
    expect(child1 != nil && [child1 isRegularFile] && [[child1 regularFileContents] isEqualToData:one],
           "the new child is a regular file wrapper with the contents");
    expect([[child1 preferredFilename] isEqualToString:@"a.txt"], "the new child has the preferred name");

    NSString *key2 = [dir addRegularFileWithContents:two preferredFilename:@"a.txt"];
    expect(key2 != nil && ![key2 isEqualToString:key1], "a name already in use gets another, unique key");
    NSFileWrapper *child2 = [[dir fileWrappers] objectForKey:key2];
    expect(child2 != nil && child2 != child1 && [[child2 preferredFilename] isEqualToString:@"a.txt"],
           "the second child keeps the preferred name, only its key differs");
    expect([[dir fileWrappers] count] == 2, "both children are in the directory");

    expect([[dir keyForFileWrapper:child1] isEqualToString:key1], "the key of the first child");
    expect([[dir keyForFileWrapper:child2] isEqualToString:key2], "the key of the second child");

    NSFileWrapper *stranger = [[NSFileWrapper alloc] initRegularFileWithContents:one];
    expect([dir keyForFileWrapper:stranger] == nil, "a wrapper that is not a child has no key");
    [dir removeFileWrapper:child1];
    expect([dir keyForFileWrapper:child1] == nil, "a removed child has no key");
    expect([[dir keyForFileWrapper:child2] isEqualToString:key2], "the other child keeps its key");

    // Wrong receiver.
    expect([raised(^{ [stranger keyForFileWrapper:child2]; }) isEqualToString:NSInternalInconsistencyException],
           "the key lookup on a regular file wrapper raises NSInternalInconsistencyException");
    expect([raised(^{ [stranger addRegularFileWithContents:two preferredFilename:@"b.txt"]; })
               isEqualToString:NSInternalInconsistencyException],
           "adding a regular file to a regular file wrapper raises NSInternalInconsistencyException");

    // macOS 26.7.3 and 10.14.4 (black-box observation): the receiver is checked before the arguments, so a
    // non directory raises NSInternalInconsistencyException even for a nil or empty name, and for a nil child.
    expect([raised(^{ [stranger addRegularFileWithContents:two preferredFilename:nil]; })
               isEqualToString:NSInternalInconsistencyException],
           "a nil name on a regular file wrapper raises NSInternalInconsistencyException (receiver first)");
    expect([raised(^{ [stranger addRegularFileWithContents:two preferredFilename:@""]; })
               isEqualToString:NSInternalInconsistencyException],
           "an empty name on a regular file wrapper raises NSInternalInconsistencyException (receiver first)");
    expect([raised(^{ [stranger keyForFileWrapper:nil]; }) isEqualToString:NSInternalInconsistencyException],
           "the key lookup of nil on a regular file wrapper raises NSInternalInconsistencyException");
    expect([dir keyForFileWrapper:nil] == nil, "the key of a nil child is nil");
    expect([raised(^{ [dir addRegularFileWithContents:nil preferredFilename:@"nodata.txt"]; }) == nil,
           "nil contents with a valid name raise nothing");

    // Bad names, on a directory.
    expect([raised(^{ [dir addRegularFileWithContents:two preferredFilename:nil]; })
               isEqualToString:NSInvalidArgumentException],
           "a nil name raises NSInvalidArgumentException");
    expect([raised(^{ [dir addRegularFileWithContents:two preferredFilename:@""]; })
               isEqualToString:NSInvalidArgumentException],
           "an empty name raises NSInvalidArgumentException");
    expect([[dir fileWrappers] count] == 2, "a refused add leaves the directory as it was (child2 and nodata.txt)");

    [stranger release];
    [dir release];
    [pool drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
