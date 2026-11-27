// Copyright (C) 2026 Lubos Dolezel
//
// NSSearchPathForDirectoriesInDomains is called from many threads at once. The function keeps its results in a
// cache, so concurrent calls with new keys race on the cache unless it is locked. Sixteen threads each ask for
// every directory kind in every combination of domains and tilde expansion, starting together and in a
// different order, and every answer has to be the same array that one thread gets (a cache that races hands
// out an array that was freed, loses an entry or crashes in the dictionary). Run it several times in a row:
// a race does not show on every run.
// Build: clang -framework Foundation nspathutilities-searchpaths-threads.m (no ARC)
#import <Foundation/Foundation.h>
#include <pthread.h>
#include <stdio.h>

enum { kThreads = 16, kRounds = 40 };

static NSSearchPathDomainMask masks[] = {
    NSUserDomainMask, NSLocalDomainMask, NSNetworkDomainMask, NSSystemDomainMask,
    NSUserDomainMask | NSLocalDomainMask, NSAllDomainsMask,
};
static volatile int go;
static int failures[kThreads];

static void *worker(void *arg) {
    int index = (int) (intptr_t) arg;
    while (!go)
        ;
    for (int round = 0; round < kRounds; round++) {
        @autoreleasepool {
            for (int i = 0; i < 24; i++) {
                NSSearchPathDirectory directory = (NSSearchPathDirectory) (1 + (i + index * 7 + round) % 24);
                for (int m = 0; m < 6; m++)
                    for (int expand = 0; expand < 2; expand++) {
                        NSArray *paths = NSSearchPathForDirectoriesInDomains(directory, masks[(m + index) % 6], expand);
                        if (![paths isKindOfClass: [NSArray class]]) {
                            failures[index]++;
                            continue;
                        }
                        for (id path in paths)
                            if (![path isKindOfClass: [NSString class]] || [path length] == 0)
                                failures[index]++;
                    }
            }
        }
    }
    return NULL;
}

int main(void) {
    int total = 0;
    @autoreleasepool {
        // The answers one thread gets, before the threads start (the cache is cold for the rest of the keys).
        NSArray *expected = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        pthread_t threads[kThreads];
        for (int t = 0; t < kThreads; t++)
            pthread_create(&threads[t], NULL, worker, (void *) (intptr_t) t);
        go = 1;
        for (int t = 0; t < kThreads; t++)
            pthread_join(threads[t], NULL);
        for (int t = 0; t < kThreads; t++)
            total += failures[t];
        NSArray *again = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        if (![again isEqualToArray: expected]) {
            fprintf(stderr, "FAIL the cached answer changed\n");
            total++;
        }
    }
    if (total != 0) {
        fprintf(stderr, "FAIL %d bad answers\n", total);
        return 1;
    }
    printf("PASS nspathutilities-searchpaths-threads\n");
    return 0;
}
