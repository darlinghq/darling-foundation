// Exercise the actual implementation with controlled syscall failures.
#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <libkern/OSAtomic.h>
#undef NDEBUG
#include <assert.h>

// Internal compilation definitions normally supplied by Foundation's prefix.
#ifndef CF_PRIVATE
#define CF_PRIVATE __attribute__((visibility("hidden")))
#endif
#ifndef UNLIKELY
#define UNLIKELY(x) __builtin_expect((x), 0)
#endif
@interface NSObject (FileIOProbeInternal)
- (BOOL)isNSString__;
@end

static int failureStage, failureCode, closeCount, freeCount;
static int injectedOpen(const char *path, int flags, ...) {
    if (failureStage == 0) { errno = failureCode; return -1; }
    return 91;
}
static int injectedStat(int fd, struct stat *info) {
    assert(fd == 91);
    if (failureStage == 1) { errno = failureCode; return -1; }
    memset(info, 0, sizeof(*info));
    info->st_mode = S_IFREG | 0600;
    info->st_size = 8;
    info->st_blksize = 8;
    return 0;
}
static ssize_t injectedRead(int fd, void *bytes, size_t length) {
    assert(fd == 91 && length == 8);
    errno = failureCode;
    return -1;
}
static int injectedClose(int fd) {
    assert(fd == 91);
    ++closeCount;
    errno = EBADF;
    return -1;
}
static void injectedFree(void *bytes) {
    ++freeCount;
    free(bytes);
    errno = ENOMEM;
}

#define open injectedOpen
#define fstat injectedStat
#define read injectedRead
#define close injectedClose
#define free injectedFree
#define _NSReadBytesFromFile ProbeReadBytesFromFile
#define _NSWriteBytesToFile ProbeWriteBytesToFile
#include "../src/_NSFileIO.m"
#undef open
#undef fstat
#undef read
#undef close
#undef free

int main(void) {
    @autoreleasepool {
        const int posixCodes[] = {ENOENT, ENOTDIR, EACCES, EPERM, EIO};
        const NSInteger cocoaCodes[] = {260, 260, 257, 257, 256};
        for (failureStage = 0; failureStage < 3; ++failureStage) {
            for (NSUInteger i = 0; i < 5; ++i) {
                for (int wantsError = 0; wantsError < 2; ++wantsError) {
                    failureCode = posixCodes[i];
                    closeCount = freeCount = 0;
                    NSUInteger length = 0;
                    BOOL vm = NO;
                    NSError *error = nil;
                    assert(ProbeReadBytesFromFile(@"/injected", 0, &length, &vm,
                        wantsError ? &error : NULL) == NULL);
                    assert(closeCount == (failureStage > 0 ? 1 : 0));
                    assert(freeCount == (failureStage == 2 ? 1 : 0));
                    if (wantsError) {
                        assert([[error domain] isEqual:NSCocoaErrorDomain]);
                        assert([error code] == cocoaCodes[i]);
                        NSError *underlying = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
                        assert([[underlying domain] isEqual:NSPOSIXErrorDomain]);
                        assert([underlying code] == failureCode);
                        assert([[[error userInfo] objectForKey:NSFilePathErrorKey] isEqual:@"/injected"]);
                    }
                }
            }
        }
    }
    puts("PASS: injected file read errors survive cleanup errno changes");
    return 0;
}
