/*
 This file is part of Darling.

 Copyright (C) 2026 redminote11tech

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/NSDistributedLock.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSException.h>
#import <Foundation/NSFileManager.h>

#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

@implementation NSDistributedLock

+ (nullable NSDistributedLock *)lockWithPath:(NSString *)path {
    return [[[self alloc] initWithPath:path] autorelease];
}

- (nullable instancetype)init {
    return [self initWithPath:@""];
}

- (nullable instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        // According to Apple docs, path must be an absolute path
        if (!path || ![path isAbsolutePath]) {
            [self release];
            return nil;
        }
        
        _path = [path copy];
        _isLocked = NO;
    }
    return self;
}

- (void)dealloc {
    if (_isLocked) {
        [self unlock];
    }
    [_path release];
    [super dealloc];
}

- (BOOL)tryLock {
    if (_isLocked) {
        return NO; // Apple's implementation returns NO if called twice on the same lock object
    }

    // Atomically create the directory
    const char *cPath = [_path fileSystemRepresentation];
    if (mkdir(cPath, 0777) == 0) {
        // Success: we created the directory and acquired the lock
        _isLocked = YES;
        return YES;
    }

    // If it failed because it already exists, someone else holds the lock
    if (errno == EEXIST) {
        return NO;
    }

    // For any other error (permissions, read-only FS), we also return NO
    return NO;
}

- (void)unlock {
    if (!_isLocked) {
        return;
    }

    const char *cPath = [_path fileSystemRepresentation];
    rmdir(cPath); // Ignore errors, as Apple's implementation does not raise exceptions here either

    _isLocked = NO;
}

- (void)breakLock {
    const char *cPath = [_path fileSystemRepresentation];
    
    // We attempt to remove the directory regardless of who owns it.
    if (rmdir(cPath) == 0) {
        // Lock broken successfully
        // If we held the lock locally, we no longer do
        _isLocked = NO;
    } else {
        if (errno != ENOENT) {
            // It might be an actual file instead of a directory (e.g. if someone else used an incompatible lock mechanism)
            // or the directory is not empty. Let's try unlink as a fallback, or raise on severe failure.
            if (unlink(cPath) == 0) {
                 _isLocked = NO;
            }
        }
    }
}

- (NSDate *)lockDate {
    const char *cPath = [_path fileSystemRepresentation];
    struct stat st;
    
    if (stat(cPath, &st) == 0) {
        // Return the modification or creation time
        // Apple docs say "date the lock was created"
        struct timespec ts = st.st_ctimespec;
        return [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)ts.tv_sec + ((NSTimeInterval)ts.tv_nsec / 1000000000.0)];
    }
    
    return nil; // Lock does not exist
}

@end
