#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <stdio.h>
#include <errno.h>

int main(void)
{
    @autoreleasepool {
        char directory[] = "/tmp/foundation-symlink-XXXXXX";
        assert(mkdir("/tmp", 0777) == 0 || errno == EEXIST);
        if (!mkdtemp(directory)) { perror("mkdtemp"); abort(); }
        NSString *root = [NSString stringWithUTF8String:directory];
        NSString *target = [root stringByAppendingPathComponent:@"target"];
        NSString *link = [root stringByAppendingPathComponent:@"link"];
        NSFileManager *manager = [NSFileManager defaultManager];
        NSData *payload = [@"unchanged" dataUsingEncoding:NSUTF8StringEncoding];
        assert([payload writeToFile:target atomically:NO]);
        NSError *error = nil;
        assert([manager createSymbolicLinkAtPath:link withDestinationPath:target error:&error]);
        assert(error == nil);
        char contents[4096];
        ssize_t count = readlink([link fileSystemRepresentation], contents, sizeof(contents));
        assert(count == strlen([target UTF8String]));
        assert(memcmp(contents, [target UTF8String], count) == 0);
        assert([[NSData dataWithContentsOfFile:link] isEqual:payload]);
        assert(![manager createSymbolicLinkAtPath:link withDestinationPath:target error:&error]);
        assert(error != nil);
        assert(unlink([link fileSystemRepresentation]) == 0);

        // A relative, nonexistent destination must be stored verbatim. Creating
        // a dangling link is valid and must not create the target instead.
        NSString *missing = @"missing-target";
        error = nil;
        assert([manager createSymbolicLinkAtPath:link withDestinationPath:missing error:&error]);
        assert(error == nil);
        count = readlink([link fileSystemRepresentation], contents, sizeof(contents));
        assert(count == strlen([missing UTF8String]));
        assert(memcmp(contents, [missing UTF8String], count) == 0);
        struct stat info;
        assert(lstat([[root stringByAppendingPathComponent:missing] fileSystemRepresentation], &info) == -1);
        assert([[NSData dataWithContentsOfFile:target] isEqual:payload]);
        assert(unlink([link fileSystemRepresentation]) == 0);
        assert(unlink([target fileSystemRepresentation]) == 0);
        assert(rmdir(directory) == 0);
    }
    puts("PASS: symbolic-link location, destination text and target preservation");
    return 0;
}
