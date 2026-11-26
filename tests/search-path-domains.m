// Copyright (C) 2026 Lubos Dolezel
//
// NSSearchPathForDirectoriesInDomains and -[NSFileManager URLsForDirectory:inDomains:]
// for each domain, not only the user domain. Expected values are what macOS 26.7.3 and
// Mac OS X 10.14.4 return (vd-upstream/mac-probes/search-paths-enumerator on both).
#import <Foundation/Foundation.h>
#include <pthread.h>
#include <stdio.h>

static void *concurrentPathsWorker(void *arg)
{
    (void)arg;
    NSSearchPathDomainMask masks[] = { NSUserDomainMask, NSLocalDomainMask, NSNetworkDomainMask, NSSystemDomainMask, NSAllDomainsMask };
    NSSearchPathDirectory dirs[] = {
        NSApplicationSupportDirectory, NSLibraryDirectory, NSCachesDirectory,
        NSDocumentDirectory, NSApplicationDirectory, NSDownloadsDirectory,
        NSDesktopDirectory, NSMoviesDirectory
    };
    for (int i = 0; i < 100; i++) {
        @autoreleasepool {
            for (int d = 0; d < 8; d++) {
                for (int m = 0; m < 5; m++) {
                    for (int expand = 0; expand < 2; expand++) {
                        NSArray *arr = NSSearchPathForDirectoriesInDomains(dirs[d], masks[m], expand ? YES : NO);
                        if (![arr isKindOfClass:[NSArray class]])
                            return (void *)(intptr_t)1;
                    }
                }
            }
        }
    }
    return NULL;
}

static int failures;
#define CHECK(cond, label) do { if (!(cond)) { printf("FAIL %s (line %d)\n", label, __LINE__); failures++; } } while (0)

static NSArray *paths(NSSearchPathDirectory dir, NSSearchPathDomainMask mask)
{
    return NSSearchPathForDirectoriesInDomains(dir, mask, YES);
}

// The URLs name the same directories as the paths, as directory URLs.
static BOOL urlsMatchPaths(NSSearchPathDirectory dir, NSSearchPathDomainMask mask)
{
    NSArray *p = paths(dir, mask);
    NSArray *u = [[NSFileManager defaultManager] URLsForDirectory:dir inDomains:mask];
    if ([u count] != [p count])
        return NO;
    for (NSUInteger i = 0; i < [u count]; i++) {
        NSURL *url = u[i];
        if (![url isFileURL] || ![[url absoluteString] hasSuffix:@"/"] || ![[url path] isEqual:p[i]])
            return NO;
    }
    return YES;
}

int main(void)
{
    pthread_t threads[4];
    for (int t = 0; t < 4; t++)
        CHECK(pthread_create(&threads[t], NULL, concurrentPathsWorker, NULL) == 0, "spawn search-path worker");
    for (int t = 0; t < 4; t++) {
        void *res = (void *)(intptr_t)1;
        CHECK(pthread_join(threads[t], &res) == 0 && res == NULL, "join search-path worker");
    }

    @autoreleasepool {
        NSString *home = NSHomeDirectory();
        NSString *userSupport = [home stringByAppendingPathComponent:@"Library/Application Support"];

        CHECK([paths(NSApplicationSupportDirectory, NSUserDomainMask) isEqual:@[userSupport]], "user application support");
        CHECK([paths(NSApplicationSupportDirectory, NSLocalDomainMask) isEqual:@[@"/Library/Application Support"]], "local application support");
        CHECK([paths(NSApplicationSupportDirectory, NSNetworkDomainMask) isEqual:@[@"/Network/Library/Application Support"]], "network application support");
        CHECK([paths(NSApplicationSupportDirectory, NSUserDomainMask | NSLocalDomainMask) isEqual:(@[userSupport, @"/Library/Application Support"])], "user and local application support");
        NSArray *all = paths(NSApplicationSupportDirectory, NSAllDomainsMask);
        CHECK([all count] >= 3 && [all[0] isEqual:userSupport] && [all[1] isEqual:@"/Library/Application Support"]
            && [all[2] isEqual:@"/Network/Library/Application Support"], "all domains application support, user domain first");

        CHECK([paths(NSLibraryDirectory, NSLocalDomainMask) isEqual:@[@"/Library"]], "local library");
        CHECK([paths(NSLibraryDirectory, NSSystemDomainMask) containsObject:@"/System/Library"], "system library");
        CHECK([paths(NSCachesDirectory, NSLocalDomainMask) isEqual:@[@"/Library/Caches"]], "local caches");
        CHECK([paths(NSCachesDirectory, NSNetworkDomainMask) count] == 0, "no network caches");
        CHECK([paths(NSDocumentDirectory, NSLocalDomainMask) count] == 0, "no local documents");
        CHECK([paths(NSApplicationDirectory, NSLocalDomainMask) isEqual:@[@"/Applications"]], "local applications");

        NSSearchPathDomainMask masks[] = { NSUserDomainMask, NSLocalDomainMask, NSNetworkDomainMask, NSSystemDomainMask, NSAllDomainsMask };
        NSSearchPathDirectory dirs[] = { NSApplicationSupportDirectory, NSLibraryDirectory, NSCachesDirectory, NSDocumentDirectory, NSApplicationDirectory };
        for (int d = 0; d < 5; d++)
            for (int m = 0; m < 5; m++)
                if (!urlsMatchPaths(dirs[d], masks[m])) {
                    printf("FAIL URLsForDirectory:%lu inDomains:0x%lx\n", (unsigned long)dirs[d], (unsigned long)masks[m]);
                    failures++;
                }
        NSArray *allURLs = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSAllDomainsMask];
        CHECK([allURLs count] >= 3 && [[allURLs[1] absoluteString] hasSuffix:@"/Library/Application%20Support/"], "all domains URLs are directory URLs");
    }
    if (failures == 0)
        printf("PASS search-path-domains\n");
    return failures != 0;
}
