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
