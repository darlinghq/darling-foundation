//
//  _NSFileErrors.m
//  Foundation
//
//  Copyright (C) 2026 Lubos Dolezel
//

#import "_NSFileErrors.h"
#import <Foundation/FoundationErrors.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSPathUtilities.h>
#import <errno.h>

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
