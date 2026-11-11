#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

int main()
{
    @autoreleasepool {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
        NSString *subDir = [tmpDir stringByAppendingPathComponent:@"sub"];
        NSString *file1 = [tmpDir stringByAppendingPathComponent:@"file1.txt"];
        NSString *file2 = [subDir stringByAppendingPathComponent:@"file2.txt"];

        [fm createDirectoryAtPath:subDir withIntermediateDirectories:YES attributes:nil error:NULL];
        [@"hello" writeToFile:file1 atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        [@"world" writeToFile:file2 atomically:YES encoding:NSUTF8StringEncoding error:NULL];

        NSURL *dirURL = [NSURL fileURLWithPath:tmpDir isDirectory:YES];

        // Test 1: Default options (0) -> should recurse and find file2.txt in sub/
        NSDirectoryEnumerator *e1 = [fm enumeratorAtURL:dirURL
                             includingPropertiesForKeys:nil
                                                options:0
                                           errorHandler:nil];
        NSMutableArray *urls1 = [NSMutableArray array];
        for (NSURL *u in e1) {
            [urls1 addObject:[u lastPathComponent]];
        }

        BOOL foundFile2_recursive = [urls1 containsObject:@"file2.txt"];
        printf("Test 1 (default 0, recursive): found file2.txt = %s\n", foundFile2_recursive ? "YES" : "NO");

        // Test 2: NSDirectoryEnumerationSkipsSubdirectoryDescendants -> should NOT find file2.txt
        NSDirectoryEnumerator *e2 = [fm enumeratorAtURL:dirURL
                             includingPropertiesForKeys:nil
                                                options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                           errorHandler:nil];
        NSMutableArray *urls2 = [NSMutableArray array];
        for (NSURL *u in e2) {
            [urls2 addObject:[u lastPathComponent]];
        }

        BOOL foundFile2_shallow = [urls2 containsObject:@"file2.txt"];
        printf("Test 2 (skips descendants): found file2.txt = %s\n", foundFile2_shallow ? "YES" : "NO");

        [fm removeItemAtPath:tmpDir error:NULL];

        if (foundFile2_recursive && !foundFile2_shallow) {
            printf("PASS: NSDirectoryEnumerationSkipsSubdirectoryDescendants correctly controls recursion.\n");
            return 0;
        } else {
            printf("FAIL: recursion mismatch! recursive=%d, shallow=%d\n", foundFile2_recursive, foundFile2_shallow);
            return 1;
        }
    }
}
