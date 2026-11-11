#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

int main(void)
{
    @autoreleasepool {
        assert(mkdir("/tmp", 0777) == 0 || errno == EEXIST);
        char path[] = "/tmp/truncate-offset-XXXXXX";
        int fd = mkstemp(path);
        assert(fd >= 0);
        assert(unlink(path) == 0);
        assert(write(fd, "abcdefghij", 10) == 10);
        NSFileHandle *handle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:NO];
        [handle seekToFileOffset:7];
        [handle truncateFileAtOffset:3];
        assert([handle offsetInFile] == 3);
        struct stat info;
        assert(fstat(fd, &info) == 0 && info.st_size == 3);
        [handle writeData:[@"Z" dataUsingEncoding:NSUTF8StringEncoding]];
        assert(fstat(fd, &info) == 0 && info.st_size == 4);
        char bytes[8];
        assert(pread(fd, bytes, 4, 0) == 4);
        assert(memcmp(bytes, "abcZ", 4) == 0);
        [handle seekToFileOffset:2];
        [handle truncateFileAtOffset:8];
        assert([handle offsetInFile] == 8);
        assert(fstat(fd, &info) == 0 && info.st_size == 8);
        assert(pread(fd, bytes, 8, 0) == 8);
        assert(memcmp(bytes, "abcZ\0\0\0\0", 8) == 0);
        [handle truncateFileAtOffset:0];
        assert([handle offsetInFile] == 0);
        assert(fstat(fd, &info) == 0 && info.st_size == 0);
        [handle closeFile];
        [handle release];
    }
    puts("PASS: truncation position, subsequent write, extension and zero length");
    return 0;
}
