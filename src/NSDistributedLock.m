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
        return YES; // We already hold it
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
        [NSException raise:NSGenericException format:@"NSDistributedLock: Attempt to unlock a lock not held by this instance (path: %@)", _path];
        return;
    }

    const char *cPath = [_path fileSystemRepresentation];
    if (rmdir(cPath) != 0) {
        // It's possible another process forcefully broke our lock
        if (errno == ENOENT) {
             _isLocked = NO;
             return;
        }
        [NSException raise:NSGenericException format:@"NSDistributedLock: Failed to remove lock directory at path: %@, error: %s", _path, strerror(errno)];
    }

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
#ifdef __APPLE__
        struct timespec ts = st.st_ctimespec;
#else
        // Use mtime on Linux/others as a close approximation of creation time for directories
        struct timespec ts = st.st_mtim;
#endif
        return [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)ts.tv_sec + ((NSTimeInterval)ts.tv_nsec / 1000000000.0)];
    }
    
    return nil; // Lock does not exist
}

@end
