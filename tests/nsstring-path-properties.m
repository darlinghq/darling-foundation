#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

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
