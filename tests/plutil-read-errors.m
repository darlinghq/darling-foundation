#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#undef NDEBUG
#include <assert.h>
#define main plutil_main
#include "../tools/plutil.m"
#undef main

static void checkCommand(int argc, const char **argv, const char *message) {
    int descriptors[2];
    assert(pipe(descriptors) == 0);
    int saved = dup(STDERR_FILENO);
    assert(saved >= 0);
    assert(dup2(descriptors[1], STDERR_FILENO) >= 0);
    close(descriptors[1]);
    int status = plutil_main(argc, argv);
    assert(dup2(saved, STDERR_FILENO) >= 0);
    close(saved);
    char buffer[256] = {0};
    ssize_t count = read(descriptors[0], buffer, sizeof(buffer) - 1);
    close(descriptors[0]);
    assert(count >= 0);
    assert(status == 1);
    assert(strcmp(buffer, message) == 0);
}
int main(void) {
    @autoreleasepool {
        mkdir("/tmp", 0777);
        char dir[] = "/tmp/plutil-errors-XXXXXX";
        assert(mkdtemp(dir));
        char path[256];
        snprintf(path, sizeof(path), "%s/input", dir);
        const char *lint[] = {"plutil", "-lint", path};
        const char *convert[] = {"plutil", "-convert", "xml1", path};
        checkCommand(3, lint, "plutil: could not read input file\n");
        checkCommand(4, convert, "plutil: could not read input file\n");
        int fd = open(path, O_WRONLY | O_CREAT, 0600);
        assert(fd >= 0);
        assert(write(fd, "<broken", 7) == 7);
        assert(close(fd) == 0);
        checkCommand(3, lint, "plutil: invalid property list\n");
        checkCommand(4, convert, "plutil: input is not a property list\n");
        NSDictionary *expected = @{ @"answer": @42 };
        NSData *xml = [NSPropertyListSerialization dataWithPropertyList:expected
            format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
        assert(xml != nil);
        NSString *inputPath = [NSString stringWithUTF8String:path];
        assert([xml writeToFile:inputPath atomically:NO]);
        assert(plutil_main(3, lint) == 0);
        char output[256];
        snprintf(output, sizeof(output), "%s/output", dir);
        const char *binary[] = {"plutil", "-convert", "binary1", "-o", output, path};
        assert(plutil_main(6, binary) == 0);
        NSData *encoded = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:output]];
        NSPropertyListFormat format = 0;
        id decoded = [NSPropertyListSerialization propertyListWithData:encoded
            options:NSPropertyListImmutable format:&format error:NULL];
        assert([decoded isEqual:expected] && format == NSPropertyListBinaryFormat_v1_0);
        const char *backToXML[] = {"plutil", "-convert", "xml1", output};
        assert(plutil_main(4, backToXML) == 0);
        encoded = [NSData dataWithContentsOfFile:[NSString stringWithUTF8String:output]];
        decoded = [NSPropertyListSerialization propertyListWithData:encoded
            options:NSPropertyListImmutable format:&format error:NULL];
        assert([decoded isEqual:expected] && format == NSPropertyListXMLFormat_v1_0);
        assert(unlink(output) == 0);
        assert(unlink(path) == 0);
        assert(rmdir(dir) == 0);
    }
    puts("PASS: plutil distinguishes unreadable and malformed inputs");
    return 0;
}
