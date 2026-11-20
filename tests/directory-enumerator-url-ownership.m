// Copyright (C) 2026 Lubos Dolezel
//
// -[NSFileManager enumeratorAtURL:...] returns autoreleased URLs: once the
// caller has retained each one and both the autorelease pool and the
// enumerator are gone, the caller's reference is the only one left. Built
// without ARC. Values are those observed on macOS 26.7.3, where the program
// builds and runs too.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expect(BOOL ok, const char *what)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok)
        failures++;
}

int main(void)
{
    NSAutoreleasePool *outer = [NSAutoreleasePool new];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"urlown.%d", getpid()]];
    [fm createDirectoryAtPath:[dir stringByAppendingPathComponent:@"sub"]
  withIntermediateDirectories:YES attributes:nil error:NULL];
    [@"a" writeToFile:[dir stringByAppendingPathComponent:@"a.txt"] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
    [@"c" writeToFile:[dir stringByAppendingPathComponent:@"sub/c.txt"] atomically:NO encoding:NSUTF8StringEncoding error:NULL];

    NSMutableArray *urls = [NSMutableArray new];
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSDirectoryEnumerator *e = [[fm enumeratorAtURL:[NSURL fileURLWithPath:dir]
                         includingPropertiesForKeys:nil options:0 errorHandler:nil] retain];
    for (NSURL *url in e)
        [urls addObject:url];
    [e release];
    [pool drain];

    expect([urls count] == 3, "three URLs are returned");
    BOOL owned = YES;
    for (NSURL *url in urls) {
        if ([url retainCount] != 1) {
            printf("  %s has %lu references, 1 expected\n", [[url lastPathComponent] UTF8String],
                   (unsigned long)[url retainCount]);
            owned = NO;
        }
    }
    expect(owned, "the array holds the only reference to each URL");
    BOOL readable = YES;
    for (NSURL *url in urls)
        readable &= [[url lastPathComponent] length] > 0;
    expect(readable, "the URLs stay valid");
    [urls release];

    [fm removeItemAtPath:dir error:NULL];
    [outer drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
