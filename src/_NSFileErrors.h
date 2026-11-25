//
//  _NSFileErrors.h
//  Foundation
//
//  Copyright (C) 2026 Lubos Dolezel
//

#import <Foundation/NSError.h>

// Errors of failed file system operations, in the form the NSFileManager and NSData calls report
// them: an NSCocoaErrorDomain error (NSFileWriteNoPermissionError, NSFileWriteFileExistsError, ...)
// with the failing path in NSFilePathErrorKey and the errno as an NSPOSIXErrorDomain error in
// NSUnderlyingErrorKey.

// The Cocoa error code for an errno. A write maps ENOENT to NSFileNoSuchFileError, a read to
// NSFileReadNoSuchFileError; permission failures are NSFileWriteNoPermissionError and
// NSFileReadNoPermissionError; what has no code of its own is NSFileWriteUnknownError or
// NSFileReadUnknownError.
NSInteger _NSFileErrorCodeForErrno(int err, BOOL reading);

// The error for err on path. extraInfo (may be nil) is added to the userInfo.
NSError *_NSFileErrorWithErrno(int err, NSString *path, BOOL reading, NSDictionary *extraInfo);

// The error of a copy, move or hard link of source to destination: variant is "Copy", "Move" or
// "Link". The userInfo names the source (also as the path), the destination and the variant.
NSError *_NSFileTransferErrorWithErrno(int err, NSString *source, NSString *destination, NSString *variant, BOOL reading);

// The error of removing path.
NSError *_NSFileRemoveErrorWithErrno(int err, NSString *path);

// The error of reading file system metadata (attributes of an item, the destination of a symbolic
// link, the sub-paths of a directory): a Cocoa read error with the errno underneath.
NSError *_NSFileItemReadError(int err, NSString *path);

// The error of listing the directory path. url is the directory for the URL-taking call and nil for
// the path-taking one, whose errors differ in their userInfo.
NSError *_NSFileDirectoryListingError(int err, NSString *path, NSURL *url);
