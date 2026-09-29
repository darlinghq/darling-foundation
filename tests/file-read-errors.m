#import <Foundation/Foundation.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

static void checkReadError(NSString *path, int posixCode) {
    NSError *error = nil;
    assert([NSData dataWithContentsOfFile:path options:0 error:&error] == nil);
    assert([[error domain] isEqual:NSCocoaErrorDomain]);
    assert([error code] == 260);
    assert([[[error userInfo] objectForKey:NSFilePathErrorKey] isEqual:path]);
    NSError *underlying = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
    assert([[underlying domain] isEqual:NSPOSIXErrorDomain]);
    assert([underlying code] == posixCode);
    assert([NSData dataWithContentsOfFile:path options:0 error:NULL] == nil);
}

int main(void) {
    @autoreleasepool {
        mkdir("/tmp", 0777);
        char directory[] = "/tmp/read-errors-XXXXXX";
        assert(mkdtemp(directory));
        NSString *root = [NSString stringWithUTF8String:directory];
        checkReadError([root stringByAppendingPathComponent:@"missing"], ENOENT);
        NSString *file = [root stringByAppendingPathComponent:@"file"];
        int fd = open([file fileSystemRepresentation], O_CREAT | O_WRONLY, 0600);
        assert(fd >= 0);
        assert(write(fd, "abc", 3) == 3);
        assert(close(fd) == 0);
        checkReadError([file stringByAppendingPathComponent:@"child"], ENOTDIR);
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfFile:file options:0 error:&error];
        assert([data isEqual:[@"abc" dataUsingEncoding:NSUTF8StringEncoding]]);
        assert(error == nil);
        assert(unlink([file fileSystemRepresentation]) == 0);
        assert(rmdir(directory) == 0);
    }
    puts("PASS: Cocoa read errors preserve POSIX cause and path");
    return 0;
}
