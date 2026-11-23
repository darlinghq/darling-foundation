//
//  _NSFileIO.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "_NSFileIO.h"

#import <Foundation/FoundationErrors.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSError.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSMutableDictionary.h>
#import <fcntl.h>
#import <errno.h>
#import <string.h>
#import <unistd.h>
#import <libkern/OSAtomic.h>
#import <stdio.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import "NSErrorInternal.h"
#import "_NSFileErrors.h"

static NSError *NSFileReadError(int errorCode, NSString *path)
{
    NSInteger code = NSFileReadUnknownError;
    switch (errorCode) {
        case ENOENT:
            code = NSFileReadNoSuchFileError;
            break;
        case EACCES:
        case EPERM:
            code = NSFileReadNoPermissionError;
            break;
    }
    NSError *underlying = [NSError errorWithDomain:NSPOSIXErrorDomain
        code:errorCode userInfo:nil];
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        underlying, NSUnderlyingErrorKey,
        [NSString stringWithUTF8String:strerror(errorCode)], NSLocalizedDescriptionKey,
        nil];
    if (path != nil) [info setObject:path forKey:NSFilePathErrorKey];
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:info];
}

void *_NSReadBytesFromFile(NSString *path, NSDataReadingOptions readOptionsMask, NSUInteger *length, BOOL *vm, NSError **err)
{
    *length = 0;

    // Paths are used in the file system representation, which is how files are created; a file that
    // exists only under the spelling of the caller is found as a fallback (see NSFileManager.m).
    int fd = open([path fileSystemRepresentation], O_RDONLY);
    if (fd < 0 && errno == ENOENT && strcmp([path UTF8String], [path fileSystemRepresentation]) != 0)
    {
        fd = open([path UTF8String], O_RDONLY);
    }
    if (fd < 0)
    {
        if (err != NULL)
        {
            *err = NSFileReadError(errno, path);
        }
        return NULL;
    }
    struct stat statInfo;
    int result = fstat(fd, &statInfo);
    if (UNLIKELY(result != 0))
    {
        int errorCode = errno;
        close(fd);
        if (err != NULL)
        {
            *err = NSFileReadError(errorCode, path);
        }
        return NULL;
    }
    if (S_ISDIR(statInfo.st_mode))
    {
        close(fd);
        if (err != NULL)
        {
            *err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoPermissionError userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"the path %@ is a directory", path]}];
        }
        return NULL;
    }
    off_t len = statInfo.st_size;
    *length = len;

    if (readOptionsMask & NSDataReadingMappedIfSafe)
    {
        *vm = NO;
        void *bytes = mmap(0, len, PROT_READ, MAP_SHARED, fd, 0);
        if (bytes != MAP_FAILED)
        {
            *vm = YES;

            close(fd);
            return bytes;
        }
    }

    blksize_t preferred_block_size = statInfo.st_blksize;

    // Maybe a special file such as a file in the /proc or /sys virtual filesystems.
    // See http://unix.stackexchange.com/questions/80324/determining-if-a-file-system-object-is-a-procfs-sysfs-etc-virtual-file-which
    BOOL file_size_unknown = statInfo.st_size == 0;
    if (file_size_unknown)
    {
        // Keep reading file until EOF.
        len = preferred_block_size;
    }

    void *bytes = malloc(len);
    if (UNLIKELY(bytes == NULL))
    {
        if (err != NULL)
        {
            *err = [NSError _outOfMemoryError];
        }
        close(fd);
        return nil;
    }
    size_t offset = 0;

    while (offset < len)
    {
        size_t buffer_size = MIN(len - offset, preferred_block_size);
        ssize_t amt = read(fd, (char *)bytes + offset, buffer_size);
        if (amt < 0)
        {
            int errorCode = errno;
            free(bytes);
            bytes = NULL;
            if (err != NULL)
            {
                *err = NSFileReadError(errorCode, path);
            }
            break;
        }

        offset += amt;

        // if hit EOF, break regardless, otherwise we loop forever
        if (amt == 0)
        {
            len = offset;
            *length = len;
            bytes = reallocf(bytes, len);

            if (UNLIKELY(bytes == NULL))
            {
                if (err != NULL)
                {
                    *err = [NSError _outOfMemoryError];
                }
            }

            break;
        }

        if (file_size_unknown)
        {
            // Allocate more memory and continue reading
            len = offset + preferred_block_size;
            bytes = reallocf(bytes, len);

            if (UNLIKELY(bytes == NULL))
            {
                if (err != NULL)
                {
                    *err = [NSError _outOfMemoryError];
                }
                break;
            }
        }
    }

    close(fd);

    return bytes;
}

BOOL _NSWriteBytesToFile(NSData *data, id pathOrURL, NSDataWritingOptions options, NSError **errorPtr)
{
    if (![pathOrURL isNSString__])
    {
        if (![pathOrURL isFileURL])
        {
            if (errorPtr != NULL)
            {
                *errorPtr = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnsupportedSchemeError
                    userInfo:@{ NSURLErrorKey: pathOrURL }];
            }
            return NO;
        }
        pathOrURL = [pathOrURL path];
    }
    NSString *dest = pathOrURL;
    BOOL atomic = (options & NSDataWritingAtomic) != 0;
    if (atomic)
    {
        static int atomicId = 0;
        atomicId = OSAtomicIncrement32(&atomicId);
        pathOrURL = [pathOrURL stringByAppendingFormat:@".tmp%d", atomicId];
    }
    int fd = -1;
    const char *path = [pathOrURL fileSystemRepresentation];
    BOOL withoutOverwriting = (options & NSDataWritingWithoutOverwriting) != 0;
    if (withoutOverwriting)
    {
        // Anything at the destination, a dangling link included, makes the write fail with EEXIST. (The
        // temporary file of an atomic write never exists, so the destination is what must not.)
        struct stat info;
        if (lstat([dest fileSystemRepresentation], &info) == 0)
        {
            if (errorPtr != NULL)
            {
                *errorPtr = _NSFileErrorWithErrno(EEXIST, dest, NO, nil);
            }
            return NO;
        }
    }
    // A file is created exclusively when it must not overwrite anything (also when the destination is
    // a dangling link).
    fd = open(path, O_WRONLY | O_CREAT | (withoutOverwriting ? O_EXCL : O_TRUNC), 0644);
    if (fd == -1)
    {
        if (errorPtr != NULL)
        {
            int openErrno = errno;
            // QUIRK: creating the temporary file of an atomic write in a missing or unwritable
            // directory carries the user string variant "Folder" (a string, not an array, unlike
            // copy, move, link and remove). Not documented. Evidence: black-box observation on
            // macOS 10.14.4 and 26.7.3 (tier 2). Test: tests/nsfilemanager-cocoa-errors.m,
            // "atomic write into an unwritable folder carries the Folder variant".
            NSDictionary *extra = (atomic && (openErrno == ENOENT || openErrno == EACCES))
                ? @{ @"NSUserStringVariant": @"Folder" } : nil;
            *errorPtr = _NSFileErrorWithErrno(openErrno, dest, NO, extra);
        }
        return NO;
    }
    uint8_t *buffer = (uint8_t *)[data bytes];
    NSUInteger remaining = [data length];
    while (remaining > 0)
    {
        ssize_t amt = write(fd, buffer, remaining);
        if (amt < 0)
        {
            if (errno == EINTR)
            {
                continue;
            }
            else
            {
                if (errorPtr != NULL)
                {
                    *errorPtr = _NSFileErrorWithErrno(errno, dest, NO, nil);
                }
            }
            close(fd);
            if (atomic)
            {
                unlink(path);
            }
            return NO;
        }
        else if (amt == 0)
        {
            break;
        }
        else
        {
            remaining -= amt;
            buffer += amt;
        }
    }
    close(fd);
    if (remaining == 0 && atomic)
    {
        if (rename([pathOrURL fileSystemRepresentation], [dest fileSystemRepresentation]) != -1)
        {
            return YES;
        }
        else
        {
            int renameErrno = errno;
            unlink(path);
            if (errorPtr != NULL)
            {
                *errorPtr = _NSFileErrorWithErrno(renameErrno, dest, NO, nil);
            }
            return NO;
        }
    }
    else
    {
        if (atomic)
        {
            unlink(path);
        }
        // the error was already set hopefully by the amout being negative.
        return remaining == 0;
    }
}
