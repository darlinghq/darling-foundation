//
//  _NSFileErrors.m
//  Foundation
//
//  Copyright (C) 2026 Lubos Dolezel
//

#import "_NSFileErrors.h"
#import <Foundation/FoundationErrors.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSURL.h>
#import <errno.h>
#import <limits.h>
#import <stdlib.h>
#import <sys/stat.h>

NSInteger _NSFileErrorCodeForErrno(int err, BOOL reading)
{
    switch (err)
    {
        case ENOENT:
            return reading ? NSFileReadNoSuchFileError : NSFileNoSuchFileError;
        case EEXIST:
            return NSFileWriteFileExistsError;
        case EACCES:
        case EPERM:
            return reading ? NSFileReadNoPermissionError : NSFileWriteNoPermissionError;
        case ENOSPC:
            return NSFileWriteOutOfSpaceError;
        case EROFS:
            return NSFileWriteVolumeReadOnlyError;
        case ENAMETOOLONG:
            return reading ? NSFileReadUnknownError : NSFileWriteInvalidFileNameError;
        default:
            return reading ? NSFileReadUnknownError : NSFileWriteUnknownError;
    }
}

NSError *_NSFileErrorWithErrno(int err, NSString *path, BOOL reading, NSDictionary *extraInfo)
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (extraInfo != nil)
    {
        [info addEntriesFromDictionary:extraInfo];
    }
    if (path != nil)
    {
        [info setObject:path forKey:NSFilePathErrorKey];
    }
    [info setObject:[NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil] forKey:NSUnderlyingErrorKey];
    return [NSError errorWithDomain:NSCocoaErrorDomain code:_NSFileErrorCodeForErrno(err, reading) userInfo:info];
}

NSError *_NSFileTransferErrorWithErrno(int err, NSString *source, NSString *destination, NSString *variant, BOOL reading)
{
    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    if (source != nil)
    {
        [extra setObject:source forKey:@"NSSourceFilePathErrorKey"];
    }
    if (destination != nil)
    {
        [extra setObject:destination forKey:@"NSDestinationFilePath"];
    }
    if (variant != nil)
    {
        [extra setObject:[NSArray arrayWithObject:variant] forKey:@"NSUserStringVariant"];
    }
    return _NSFileErrorWithErrno(err, source, reading, extra);
}

NSError *_NSFileRemoveErrorWithErrno(int err, NSString *path)
{
    return _NSFileErrorWithErrno(err, path, NO, @{ @"NSUserStringVariant": @[ @"Remove" ] });
}

NSError *_NSFileItemReadError(int err, NSString *path)
{
    return _NSFileErrorWithErrno(err, path, YES, nil);
}

// The path with symbolic links resolved, or path when it cannot be resolved.
static NSString *_NSFileResolvedPath(NSString *path)
{
    char resolved[PATH_MAX];
    if (realpath([path fileSystemRepresentation], resolved) == NULL)
    {
        return path;
    }
    return [[NSFileManager defaultManager] stringWithFileSystemRepresentation:resolved length:strlen(resolved)];
}

NSError *_NSFileDirectoryListingError(int err, NSString *path, NSURL *url)
{
    BOOL permission = err == EACCES || err == EPERM;
    NSDictionary *folder = @{ @"NSUserStringVariant": @[ @"Folder" ] };
    if (permission)
    {
        // The path and the URL name the directory with its symbolic links resolved.
        NSString *resolved = _NSFileResolvedPath(path);
        NSMutableDictionary *extra = [NSMutableDictionary dictionaryWithObject:[NSURL fileURLWithPath:resolved isDirectory:NO]
                                                                         forKey:NSURLErrorKey];
        if (url == nil)
        {
            [extra addEntriesFromDictionary:folder];
        }
        return _NSFileErrorWithErrno(err, resolved, YES, extra);
    }
    if (url != nil)
    {
        return _NSFileErrorWithErrno(err, path, YES, @{ NSURLErrorKey: url });
    }
    struct stat st;
    if (err == ENOTDIR && lstat([path fileSystemRepresentation], &st) == 0 && !S_ISLNK(st.st_mode))
    {
        // The path itself names a file.
        NSMutableDictionary *extra = [NSMutableDictionary dictionaryWithDictionary:folder];
        [extra setObject:[NSURL fileURLWithPath:path isDirectory:YES] forKey:NSURLErrorKey];
        return _NSFileErrorWithErrno(err, path, YES, extra);
    }
    if (err == ENOENT || err == ENOTDIR)
    {
        // A missing directory, a path below a file and a link that does not lead to a directory: the
        // underlying error is an OSStatus (fnfErr), not an errno.
        NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:folder];
        [info setObject:path forKey:NSFilePathErrorKey];
        [info setObject:[NSError errorWithDomain:NSOSStatusErrorDomain code:-43 userInfo:nil] forKey:NSUnderlyingErrorKey];
        return [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError userInfo:info];
    }
    return _NSFileErrorWithErrno(err, path, YES, folder);
}
