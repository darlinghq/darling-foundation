// Copyright (C) 2026 Lubos Dolezel
//
// Weak NSHashTable, NSMapTable and NSPointerArray members are registered with the runtime once per
// slot and unregistered when the entry or the table goes away. A slot registered twice, or left
// registered after its memory is freed, makes the runtime print "__weak variable at ... holds ...
// instead of ..." on stderr when the referent dies. The test captures stderr and requires that no
// such message appears, and checks that weak members are zeroed when their objects die.
#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static int failures;
// The check runs in its own autorelease pool: reading a weak slot returns an autoreleased strong
// reference, which would otherwise keep the referent alive until the outer pool drains.
#define CHECK(cond) do { @autoreleasepool { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } } while (0)

static int savedStderr = -1;
static char capturePath[] = "/tmp/weak-collection-registration.XXXXXX";

static void beginCapture(void)
{
    int fd = mkstemp(capturePath);
    savedStderr = dup(2);
    dup2(fd, 2);
    close(fd);
}

// Returns the number of runtime weak-variable complaints written to stderr since beginCapture.
static int endCapture(void)
{
    fflush(stderr);
    dup2(savedStderr, 2);
    close(savedStderr);
    FILE *f = fopen(capturePath, "r");
    char line[512];
    int complaints = 0;
    while (f != NULL && fgets(line, sizeof line, f) != NULL)
    {
        if (strstr(line, "__weak variable") != NULL)
        {
            complaints++;
        }
    }
    if (f != NULL)
    {
        fclose(f);
    }
    unlink(capturePath);
    return complaints;
}

static NSObject *newObject(void)
{
    return [[NSObject alloc] init];
}

int main(void)
{
    @autoreleasepool
    {
        beginCapture();

        // Objects die while the weak hash table is alive: the members are zeroed.
        NSHashTable *hash = [NSHashTable weakObjectsHashTable];
        NSObject *a = newObject(), *b = newObject(), *c = newObject();
        @autoreleasepool { [hash addObject:a]; }
        @autoreleasepool { [hash addObject:b]; }
        @autoreleasepool { [hash addObject:c]; }
        @autoreleasepool { [hash addObject:a]; }
        CHECK([hash containsObject:a] && [hash containsObject:b]);
        @autoreleasepool { [hash removeObject:b]; }
        CHECK(![hash containsObject:b]);
        [b release];
        [a release];
        CHECK([[hash allObjects] count] == 1 && [hash containsObject:c]);
        [c release];
        CHECK([[hash allObjects] count] == 0);

        // The table dies before its members.
        NSHashTable *shortLived = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory capacity:0];
        NSObject *d = newObject(), *e = newObject();
        @autoreleasepool { [shortLived addObject:d]; }
        @autoreleasepool { [shortLived addObject:e]; }
        [shortLived release];
        [d release];
        [e release];

        // Enough members to grow the table and move nodes between buckets.
        NSHashTable *many = [NSHashTable weakObjectsHashTable];
        NSMutableArray *owners = [NSMutableArray array];
        for (int i = 0; i < 200; i++)
        {
            NSObject *o = newObject();
            @autoreleasepool { [many addObject:o]; }
            [owners addObject:o];
            [o release];
        }
        CHECK([[many allObjects] count] == 200);
        [owners removeAllObjects];
        CHECK([[many allObjects] count] == 0);

        // Weak map table members and pointer array slots.
        NSMapTable *weakKeys = [NSMapTable weakToStrongObjectsMapTable];
        NSMapTable *weakValues = [NSMapTable strongToWeakObjectsMapTable];
        NSPointerArray *array = [NSPointerArray weakObjectsPointerArray];
        NSObject *k = newObject(), *v = newObject();
        @autoreleasepool { [weakKeys setObject:@"value" forKey:k]; }
        @autoreleasepool { [weakValues setObject:v forKey:@"key"]; }
        @autoreleasepool { [array addPointer:v]; }
        CHECK([weakKeys objectForKey:k] != nil && [weakValues objectForKey:@"key"] == v);
        [k release];
        [v release];
        CHECK([[[weakKeys keyEnumerator] allObjects] count] == 0);
        CHECK([weakValues objectForKey:@"key"] == nil);
        CHECK([array pointerAtIndex:0] == NULL);

        CHECK(endCapture() == 0);
    }
    if (failures == 0)
    {
        printf("PASS\n");
    }
    return failures == 0 ? 0 : 1;
}
