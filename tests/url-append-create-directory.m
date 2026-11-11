#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static int failures;

static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

int main(void)
{
    @autoreleasepool
    {
        char temp[] = "/private/tmp/darling-url-append-XXXXXX";
        if (!mkdtemp(temp))
            return 2;
        NSString *base = [NSString stringWithUTF8String:temp];
        NSURL *baseURL = [NSURL fileURLWithPath:base];
        NSFileManager *fm = [NSFileManager defaultManager];

        NSURL *missing = [baseURL URLByAppendingPathComponent:@"missing"];
        expect([[missing path] isEqualToString:[base stringByAppendingPathComponent:@"missing"]],
               [NSString stringWithFormat:@"appending a missing name keeps the joined path (%@)", [missing path]]);
        expect(![[missing absoluteString] hasSuffix:@"/"], @"a missing name gets no trailing slash");

        NSURL *viaTmp = [[NSURL fileURLWithPath:@"/tmp"] URLByAppendingPathComponent:@"darling-url-append-missing"];
        expect([[viaTmp path] isEqualToString:@"/tmp/darling-url-append-missing"],
               [NSString stringWithFormat:@"appending to /tmp keeps the joined path (%@)", [viaTmp path]]);

        NSURL *file = [baseURL URLByAppendingPathComponent:@"file"];
        [[NSData data] writeToURL:file atomically:NO];
        NSURL *underFile = [file URLByAppendingPathComponent:@"child"];
        expect([[underFile path] isEqualToString:[base stringByAppendingPathComponent:@"file/child"]],
               @"appending under a regular file still joins the path");

        NSString *nested = [base stringByAppendingPathComponent:@"a/b/c"];
        NSError *error = nil;
        BOOL created = [fm createDirectoryAtPath:nested withIntermediateDirectories:YES attributes:nil error:&error];
        BOOL isDir = NO;
        expect(created && error == nil && [fm fileExistsAtPath:nested isDirectory:&isDir] && isDir,
               [NSString stringWithFormat:@"createDirectoryAtPath:withIntermediateDirectories:YES attributes:nil (%@)", error]);

        NSURL *existing = [baseURL URLByAppendingPathComponent:@"a"];
        expect([[existing absoluteString] hasSuffix:@"/"], @"an existing directory gets a trailing slash");

        error = nil;
        created = [fm createDirectoryAtPath:nested withIntermediateDirectories:YES attributes:nil error:&error];
        expect(created && error == nil, @"creating an existing directory with intermediates succeeds");

        error = nil;
        NSString *single = [base stringByAppendingPathComponent:@"single"];
        created = [fm createDirectoryAtPath:single withIntermediateDirectories:NO attributes:nil error:&error];
        expect(created && [fm fileExistsAtPath:single], @"createDirectoryAtPath:withIntermediateDirectories:NO attributes:nil");

        [fm removeItemAtPath:base error:NULL];
    }
    printf("failures=%d\n", failures);
    return failures ? 1 : 0;
}
