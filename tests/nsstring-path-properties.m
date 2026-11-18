#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>
#include <mach/mach.h>

static size_t residentSize(void)
{
    struct mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count);
    return info.resident_size;
}

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        NSString *path = @"/tmp/darling/report.tar.gz";
        expect([path.lastPathComponent isEqualToString:@"report.tar.gz"], @"lastPathComponent");
        expect([path.pathExtension isEqualToString:@"gz"], @"pathExtension");
        expect([path.stringByDeletingPathExtension isEqualToString:@"/tmp/darling/report.tar"], @"stringByDeletingPathExtension");
        expect([path.stringByDeletingLastPathComponent isEqualToString:@"/tmp/darling"], @"stringByDeletingLastPathComponent");
        expect([path.pathComponents isEqualToArray:(@[ @"/", @"tmp", @"darling", @"report.tar.gz" ])], @"pathComponents");
        expect(path.absolutePath && path.isAbsolutePath, @"absolutePath");
        expect(!@"relative/path".absolutePath, @"relative path is not absolute");
        expect([@"".lastPathComponent isEqualToString:@""], @"empty lastPathComponent");
        expect([@"/a/b/".lastPathComponent isEqualToString:@"b"], @"lastPathComponent ignores trailing slashes");
        expect([@"/".lastPathComponent isEqualToString:@"/"], @"lastPathComponent of the root");
        expect([@"//".lastPathComponent isEqualToString:@"/"], @"lastPathComponent of repeated slashes");
        expect([@"name".lastPathComponent isEqualToString:@"name"], @"lastPathComponent of a single name");
        expect([@"/name".lastPathComponent isEqualToString:@"name"], @"lastPathComponent of a top-level name");
        expect([@"a/b".lastPathComponent isEqualToString:@"b"], @"lastPathComponent of a relative path");

        // Repeated calls (as made by sorting and filtering code) leave little behind in the pool.
        NSString *long1 = [NSString stringWithFormat:@"/tmp/darling/folder/entry-%d.txt", 1];
        size_t before = residentSize();
        for (int i = 0; i < 50000; i++)
        {
            (void)[long1 lastPathComponent];
        }
        size_t grown = residentSize() - before;
        expect(grown < 8 * 1024 * 1024, @"lastPathComponent does not leave much temporary data");
        expect([@"/a/./b/../c".stringByStandardizingPath isEqualToString:@"/a/c"], @"stringByStandardizingPath");

        NSString *home = NSHomeDirectory();
        NSString *expanded = @"~/notes.txt".stringByExpandingTildeInPath;
        expect([expanded isEqualToString:[home stringByAppendingPathComponent:@"notes.txt"]], @"stringByExpandingTildeInPath");
        if (![home isEqualToString:@"/"])
        {
            expect([expanded.stringByAbbreviatingWithTildeInPath isEqualToString:@"~/notes.txt"], @"stringByAbbreviatingWithTildeInPath");
        }
        expect([@"/".stringByResolvingSymlinksInPath isEqualToString:@"/"], @"stringByResolvingSymlinksInPath");
        expect(strcmp(@"/tmp/x".fileSystemRepresentation, "/tmp/x") == 0, @"fileSystemRepresentation");
    }
    NSLog(@"PASS: NSString path properties");
    return 0;
}
