// Copyright (C) 2026 Lubos Dolezel
//
// -[NSFileManager enumeratorAtURL:includingPropertiesForKeys:options:errorHandler:]
// with an error handler: a directory that cannot be read is returned and then
// reported to the handler, whose answer decides whether enumeration goes on; a root
// that does not exist still gives an enumerator, which reports it. Expected values
// are what macOS 26.7.3 does (vd-upstream/mac-probes/url-enumerator-errors).
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

static int failures;
#define CHECK(cond, label) do { if (!(cond)) { printf("FAIL %s (line %d)\n", label, __LINE__); failures++; } } while (0)

static NSString *gRoot;

static NSString *rel(NSURL *url)
{
    NSString *p = [[url URLByStandardizingPath] path];
    return [p hasPrefix:gRoot] ? [p substringFromIndex:[gRoot length]] : p;
}

// Enumerates url; returns the sorted items and records the handler calls in calls.
static NSArray *enumerate(NSURL *url, BOOL answer, BOOL withHandler, NSMutableArray *calls, NSMutableArray *errors, BOOL *gotEnumerator)
{
    BOOL (^handler)(NSURL *, NSError *) = ^BOOL(NSURL *u, NSError *e) {
        [calls addObject:rel(u)];
        [errors addObject:e];
        return answer;
    };
    NSDirectoryEnumerator *e = [[NSFileManager defaultManager] enumeratorAtURL:url includingPropertiesForKeys:nil options:0 errorHandler:withHandler ? handler : nil];
    *gotEnumerator = e != nil;
    NSMutableArray *items = [NSMutableArray array];
    NSURL *item;
    while ((item = [e nextObject]))
        [items addObject:rel(item)];
    [items sortUsingSelector:@selector(compare:)];
    return items;
}

int main(void)
{
    @autoreleasepool {
        char tmpl[] = "/tmp/url-enum-errors-XXXXXX";
        if (mkdtemp(tmpl) == NULL)
            return 2;
        gRoot = [[[NSString stringWithUTF8String:tmpl] stringByResolvingSymlinksInPath] stringByAppendingString:@"/"];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *d = [gRoot stringByAppendingString:@"d"];
        [fm createDirectoryAtPath:[d stringByAppendingPathComponent:@"a"] withIntermediateDirectories:YES attributes:nil error:NULL];
        [fm createDirectoryAtPath:[d stringByAppendingPathComponent:@"b"] withIntermediateDirectories:YES attributes:nil error:NULL];
        [[NSData data] writeToFile:[d stringByAppendingPathComponent:@"a/1"] atomically:NO];
        [[NSData data] writeToFile:[d stringByAppendingPathComponent:@"b/2"] atomically:NO];
        [[NSData data] writeToFile:[d stringByAppendingPathComponent:@"c"] atomically:NO];
        NSURL *u = [NSURL fileURLWithPath:d isDirectory:YES];
        NSArray *all = @[@"d/a", @"d/b", @"d/b/2", @"d/c"];
        BOOL got;

        // A readable tree with a handler: everything, and no handler call.
        {
            NSMutableArray *calls = [NSMutableArray array], *errors = [NSMutableArray array];
            NSArray *items = enumerate(u, YES, YES, calls, errors, &got);
            CHECK(got, "enumerator with an error handler");
            CHECK([items isEqual:(@[@"d/a", @"d/a/1", @"d/b", @"d/b/2", @"d/c"])], "readable tree is enumerated");
            CHECK([calls count] == 0, "no handler call for a readable tree");
        }

        chmod([[d stringByAppendingPathComponent:@"a"] fileSystemRepresentation], 0);
        if (access([[d stringByAppendingPathComponent:@"a"] fileSystemRepresentation], R_OK) == 0) {
            printf("SKIP unreadable-directory checks: running with permission to read anything\n");
        } else {
            NSMutableArray *calls = [NSMutableArray array], *errors = [NSMutableArray array];
            NSArray *items = enumerate(u, YES, YES, calls, errors, &got);
            CHECK([items isEqual:all], "handler YES: the unreadable directory is returned and the rest follows");
            CHECK([calls isEqual:@[@"d/a"]], "handler YES: called once, for the unreadable directory");
            NSError *e = [errors firstObject];
            CHECK([[e domain] isEqual:@"NSCocoaErrorDomain"] && [e code] == NSFileReadNoPermissionError, "unreadable directory: NSFileReadNoPermissionError");

            calls = [NSMutableArray array]; errors = [NSMutableArray array];
            items = enumerate(u, NO, YES, calls, errors, &got);
            CHECK([items isEqual:@[@"d/a"]], "handler NO: enumeration ends after the unreadable directory");
            CHECK([calls isEqual:@[@"d/a"]], "handler NO: called once");

            calls = [NSMutableArray array]; errors = [NSMutableArray array];
            items = enumerate(u, YES, NO, calls, errors, &got);
            CHECK([items isEqual:all], "no handler: enumeration goes on");
        }
        chmod([[d stringByAppendingPathComponent:@"a"] fileSystemRepresentation], 0755);

        {
            NSMutableArray *calls = [NSMutableArray array], *errors = [NSMutableArray array];
            NSURL *missing = [NSURL fileURLWithPath:[gRoot stringByAppendingString:@"missing"] isDirectory:YES];
            NSArray *items = enumerate(missing, YES, YES, calls, errors, &got);
            CHECK(got, "missing root: an enumerator is still returned");
            CHECK([items count] == 0, "missing root: no items");
            CHECK([calls isEqual:@[@"missing"]], "missing root: the handler is called with the root");
            NSError *e = [errors firstObject];
            CHECK([[e domain] isEqual:@"NSCocoaErrorDomain"] && [e code] == NSFileReadNoSuchFileError, "missing root: NSFileReadNoSuchFileError");
        }

        [fm removeItemAtPath:[NSString stringWithUTF8String:tmpl] error:NULL];
    }
    if (failures == 0)
        printf("PASS url-directory-enumerator-errors\n");
    return failures != 0;
}
