/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// -[NSFileWrapper serializedRepresentation] and -initWithSerializedRepresentation:.
//
// The sample data below was produced by NSFileWrapper on macOS 26.7.3 and on Mac OS X 10.14.4 (the bytes
// are identical on both) for wrappers whose attributes were set explicitly (mkfix-filewrapper.m).
// Checks: reading them gives the tree they were made from; writing the same tree gives data of the same
// size that reads back to the same tree (macOS orders the entries by hash, so the bytes themselves may
// differ in order); malformed data gives nil. The malformed-data part is skipped when run against
// Apple's Foundation, which raises an exception for some malformed data.
#import <Foundation/Foundation.h>
#include <stdio.h>

#ifdef VD_USE_OWN_IMPL
@interface NSFileWrapper (VDRenamed)
- (NSData *) vdSerializedRepresentation;
- (id) vdInitWithSerializedRepresentation: (NSData *) data;
@end
#define SERIALIZE(w) [(w) vdSerializedRepresentation]
#define DESERIALIZE(d) [[NSFileWrapper alloc] vdInitWithSerializedRepresentation: (d)]
#else
#define SERIALIZE(w) [(w) serializedRepresentation]
#define DESERIALIZE(d) [[NSFileWrapper alloc] initWithSerializedRepresentation: (d)]
#endif

static int failures;
#define CHECK(cond, what) do { if (!(cond)) { printf("FAIL: %s\n", what); failures++; } } while (0)

static NSString *const treeSample = @"cnRmZAAAAAADAAAABQAAAAcAAABwaWMucG5nBwAAAFRYVC5ydGYDAAAAbG5rAwAAAHN1YgEAAAAuDwAAABIAAAAOAAAASAAAAIAAAAABAAAABwAAAFBOR0RBVEEBAAAACgAAAHtccnRmMSBoaX0BAAAABgAAAC90bXAvdAMAAAACAAAAAQAAAHoBAAAALgkAAAAlAAAAAQAAAAEAAABaAQAAAB0AAAABAAAAAQAAAHoQAAAAAPFTZaQBAAAAAAAAAAAAAAEAAAB4AAAABAAAAAcAAABwaWMucG5nBwAAAFRYVC5ydGYDAAAAbG5rAwAAAHN1YhAAAAAQAAAAEAAAABAAAAAA8VNlpAEAAAAAAAAAAAAAAPFTZaQBAAAAAAAAAAAAAADxU2X/AQAABAAAAAAAAAAAAAAA7QEAAAEAAAAAAAAA";
static NSString *const namedDirectorySample = @"cnRmZAAAAAADAAAABAAAABcAAABfX0BVVEY4UHJlZmVycmVkTmFtZUBfXxMAAABfX0BQcmVmZXJyZWROYW1lQF9fAQAAAHEBAAAALhAAAAAQAAAACQAAACUAAAABAAAACAAAAGRvYy5ydGZkAQAAAAgAAABkb2MucnRmZAEAAAABAAAAUQEAAAAdAAAAAQAAAAEAAABxEAAAAADxU2WkAQAAAAAAAAAAAAA=";
static NSString *const regularSample = @"cnRmZAAAAAADAAAABAAAAAIAAAAuLhMAAABfX0BQcmVmZXJyZWROYW1lQF9fFwAAAF9fQFVURjhQcmVmZXJyZWROYW1lQF9fAQAAAC4LAAAADQAAAA0AAAAmAAAAAQAAAAMAAABhYmMBAAAABQAAAGEudHh0AQAAAAUAAABhLnR4dAEAAAAeAAAAAQAAAAIAAAAuLhAAAAAAAAAApAEAAAIAAAABAAAA";
static NSString *const emptyDirectorySample = @"cnRmZAAAAAADAAAAAAAAAA==";

static NSData *decode(NSString *base64) {
    return [[NSData alloc] initWithBase64EncodedString: base64 options: 0];
}

static NSDictionary *attrs(NSString *type, int mode) {
    return @{ NSFileType: type, NSFilePosixPermissions: @(mode),
              NSFileModificationDate: [NSDate dateWithTimeIntervalSince1970: 1700000000] };
}

static NSFileWrapper *file(NSString *name, NSString *text) {
    NSFileWrapper *w = [[NSFileWrapper alloc] initRegularFileWithContents: [text dataUsingEncoding: NSUTF8StringEncoding]];
    [w setPreferredFilename: name];
    [w setFileAttributes: attrs(NSFileTypeRegular, 0644)];
    return w;
}

static NSFileWrapper *makeTree(void) {
    NSFileWrapper *dir = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
    [dir addFileWrapper: file(@"TXT.rtf", @"{\\rtf1 hi}")];
    [dir addFileWrapper: file(@"pic.png", @"PNGDATA")];
    NSFileWrapper *sub = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
    [sub setPreferredFilename: @"sub"];
    [sub setFileAttributes: attrs(NSFileTypeDirectory, 0755)];
    [sub addFileWrapper: file(@"z", @"Z")];
    [dir addFileWrapper: sub];
    NSFileWrapper *link = [[NSFileWrapper alloc] initSymbolicLinkWithDestinationURL: [NSURL fileURLWithPath: @"/tmp/t"]];
    [link setPreferredFilename: @"lnk"];
    [link setFileAttributes: attrs(NSFileTypeSymbolicLink, 0777)];
    [dir addFileWrapper: link];
    return dir;
}

// Whether two wrappers hold the same names, kinds, contents and attributes.
static BOOL sameTree(NSFileWrapper *a, NSFileWrapper *b) {
    if ([a isDirectory] != [b isDirectory] || [a isRegularFile] != [b isRegularFile] ||
        [a isSymbolicLink] != [b isSymbolicLink])
        return NO;
    if ([a isRegularFile])
        return [[a regularFileContents] isEqualToData: [b regularFileContents]];
    if ([a isSymbolicLink])
        return [[[a symbolicLinkDestinationURL] path] isEqual: [[b symbolicLinkDestinationURL] path]];
    NSDictionary *ca = [a fileWrappers], *cb = [b fileWrappers];
    if (![[ca allKeys] isEqualToArray: [cb allKeys]] &&
        ![[NSSet setWithArray: [ca allKeys]] isEqualToSet: [NSSet setWithArray: [cb allKeys]]])
        return NO;
    for (NSString *name in ca) {
        NSFileWrapper *x = [ca objectForKey: name], *y = [cb objectForKey: name];
        if (y == nil || !sameTree(x, y) || ![[x preferredFilename] isEqual: [y preferredFilename]])
            return NO;
        NSNumber *px = [[x fileAttributes] objectForKey: NSFilePosixPermissions];
        NSNumber *py = [[y fileAttributes] objectForKey: NSFilePosixPermissions];
        if (![px isEqual: py])
            return NO;
    }
    return YES;
}

static NSData *word(uint32_t v) {
    unsigned char b[4] = { v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff };
    return [NSData dataWithBytes: b length: 4];
}

// A dictionary of directories nested to the given depth, as a file's data.
static NSData *nestedDirectories(int depth) {
    NSMutableData *dictionary = [NSMutableData data];
    [dictionary appendData: word(0)];
    for (int i = 0; i < depth; i++) {
        NSMutableData *value = [NSMutableData data];
        [value appendData: word(3)];
        [value appendData: dictionary];
        NSMutableData *outer = [NSMutableData data];
        [outer appendData: word(1)];
        [outer appendData: word(1)];
        [outer appendBytes: "d" length: 1];
        [outer appendData: word((uint32_t) [value length])];
        [outer appendData: value];
        dictionary = outer;
    }
    NSMutableData *data = [NSMutableData dataWithBytes: "rtfd" length: 4];
    [data appendData: word(0)];
    [data appendData: word(3)];
    [data appendData: dictionary];
    return data;
}

int main(void) {
    @autoreleasepool {
        // Reading
        NSData *treeData = decode(treeSample);
        NSFileWrapper *tree = DESERIALIZE(treeData);
        CHECK(tree != nil && [tree isDirectory], "tree sample reads as a directory");
        NSDictionary *children = [tree fileWrappers];
        CHECK([children count] == 4, "tree has four entries");
        NSFileWrapper *rtf = [children objectForKey: @"TXT.rtf"];
        CHECK([rtf isRegularFile] && [[rtf regularFileContents] isEqualToData: [@"{\\rtf1 hi}" dataUsingEncoding: NSUTF8StringEncoding]],
              "TXT.rtf contents");
        CHECK([[rtf preferredFilename] isEqual: @"TXT.rtf"] && [[rtf filename] isEqual: @"TXT.rtf"], "TXT.rtf names");
        CHECK([[[rtf fileAttributes] objectForKey: NSFilePosixPermissions] intValue] == 0644, "TXT.rtf permissions");
        CHECK([[[rtf fileAttributes] objectForKey: NSFileModificationDate] timeIntervalSince1970] == 1700000000, "TXT.rtf modification date");
        NSFileWrapper *sub = [children objectForKey: @"sub"];
        CHECK([sub isDirectory] && [[sub fileWrappers] count] == 1, "sub directory");
        CHECK([[[[sub fileWrappers] objectForKey: @"z"] regularFileContents] length] == 1, "sub/z contents");
        CHECK([[[sub fileAttributes] objectForKey: NSFilePosixPermissions] intValue] == 0755, "sub permissions");
        NSFileWrapper *lnk = [children objectForKey: @"lnk"];
        CHECK([lnk isSymbolicLink] && [[[lnk symbolicLinkDestinationURL] path] isEqual: @"/tmp/t"], "symbolic link");

        NSFileWrapper *named = DESERIALIZE(decode(namedDirectorySample));
        CHECK(named != nil && [named isDirectory] && [[named preferredFilename] isEqual: @"doc.rtfd"], "named directory");
        CHECK([[[[named fileWrappers] objectForKey: @"q"] regularFileContents] length] == 1, "named directory child");

        NSFileWrapper *regular = DESERIALIZE(decode(regularSample));
        CHECK(regular != nil && [regular isRegularFile] && [[regular preferredFilename] isEqual: @"a.txt"] &&
              [[regular regularFileContents] isEqualToData: [@"abc" dataUsingEncoding: NSUTF8StringEncoding]], "regular file root");

        NSFileWrapper *empty = DESERIALIZE(decode(emptyDirectorySample));
        CHECK(empty != nil && [empty isDirectory] && [[empty fileWrappers] count] == 0, "empty directory");

        // Writing
        NSFileWrapper *original = makeTree();
        NSData *written = SERIALIZE(original);
        CHECK([written length] == [treeData length], "tree serialization has the size macOS produces");
        CHECK([written length] >= 4 && memcmp([written bytes], "rtfd", 4) == 0, "serialization starts with rtfd");
        NSFileWrapper *back = DESERIALIZE(written);
        CHECK(back != nil && sameTree(original, back), "tree round trip");
        CHECK(sameTree(tree, back), "own data reads like the macOS sample");

        NSFileWrapper *emptyOwn = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
        CHECK([SERIALIZE(emptyOwn) isEqualToData: decode(emptyDirectorySample)], "empty directory bytes");

        NSFileWrapper *leaf = file(@"a.txt", @"abc");
        NSData *leafData = SERIALIZE(leaf);
        CHECK([leafData length] == [decode(regularSample) length], "regular file serialization size");
        NSFileWrapper *leafBack = DESERIALIZE(leafData);
        CHECK(leafBack != nil && [leafBack isRegularFile] && [[leafBack preferredFilename] isEqual: @"a.txt"], "regular file round trip");

        NSFileWrapper *namedOwn = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
        [namedOwn setPreferredFilename: @"doc.rtfd"];
        [namedOwn addFileWrapper: file(@"q", @"Q")];
        CHECK([SERIALIZE(namedOwn) length] == [decode(namedDirectorySample) length], "named directory serialization size");
        NSFileWrapper *namedBack = DESERIALIZE(SERIALIZE(namedOwn));
        CHECK([[namedBack preferredFilename] isEqual: @"doc.rtfd"], "named directory round trip");

#ifdef VD_USE_OWN_IMPL
        // Malformed data gives nil, never a crash or a partial wrapper.
        CHECK(DESERIALIZE([NSData data]) == nil, "empty data");
        CHECK(DESERIALIZE([NSData dataWithBytes: "junk" length: 4]) == nil, "junk data");
        int accepted = 0;
        for (NSUInteger n = 0; n + 1 < [treeData length]; n++)
            if (DESERIALIZE([treeData subdataWithRange: NSMakeRange(0, n)]) != nil)
                accepted++;
        CHECK(accepted == 0, "no truncation of the tree sample is accepted");
        NSMutableData *trailing = [treeData mutableCopy];
        [trailing appendData: word(7)];
        CHECK(DESERIALIZE(trailing) == nil, "trailing bytes are rejected");
        NSMutableData *version = [treeData mutableCopy];
        ((unsigned char *) [version mutableBytes])[8] = 4;
        CHECK(DESERIALIZE(version) == nil, "unknown version");
        NSMutableData *huge = [treeData mutableCopy];
        memset((unsigned char *) [huge mutableBytes] + 12, 0xff, 4);
        CHECK(DESERIALIZE(huge) == nil, "huge entry count");
        CHECK(DESERIALIZE(nestedDirectories(5)) != nil, "moderate nesting is read");
        CHECK(DESERIALIZE(nestedDirectories(1000)) == nil, "excessive nesting is refused");
        // Every single-byte change either fails or yields a wrapper; none may crash.
        for (NSUInteger i = 0; i < [treeData length]; i++) {
            NSMutableData *mutated = [treeData mutableCopy];
            ((unsigned char *) [mutated mutableBytes])[i] ^= 0xff;
            (void) DESERIALIZE(mutated);
        }
#endif
    }
    printf(failures ? "FAIL\n" : "PASS\n");
    return failures != 0;
}
