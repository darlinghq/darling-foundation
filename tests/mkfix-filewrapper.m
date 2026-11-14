/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// Writes serializedRepresentation of fixed wrapper trees as "name<TAB>base64" lines, run on macOS to
// produce the samples embedded in nsfilewrapper-serialized-representation.m.
#import <Foundation/Foundation.h>

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
static void emit(const char *name, NSFileWrapper *w) {
    printf("%s\t%s\n", name, [[[w serializedRepresentation] base64EncodedStringWithOptions: 0] UTF8String]);
}
int main(void) {
    @autoreleasepool {
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
        emit("tree", dir);

        NSFileWrapper *named = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
        [named setPreferredFilename: @"doc.rtfd"];
        [named addFileWrapper: file(@"q", @"Q")];
        emit("named-directory", named);

        NSFileWrapper *leaf = file(@"a.txt", @"abc");
        emit("regular", leaf);

        NSFileWrapper *emptyDir = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: @{}];
        emit("empty-directory", emptyDir);
    }
    return 0;
}
