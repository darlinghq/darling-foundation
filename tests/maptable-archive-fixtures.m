// Copyright (C) 2026 Lubos Dolezel
//
// Keyed archives of NSMapTable and NSHashTable with strong, copy and weak members: round trips, the
// layout of weak members, and archives made by macOS (fixtures). Expected values were observed on
// macOS 26.7.3 and 10.14.4 (the same file builds and passes there).
//
// test_quirk_weak_table_members_are_conditional: a weak member is archived as the object itself when
// the object is also encoded unconditionally elsewhere in the archive (before or after the table),
// and as a "$null" string otherwise; decoding keeps the entries whose members came back.
//
// usage: maptable-archive-fixtures <tests/maptable-archive-fixtures directory>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

static NSData *archive(id root, NSPropertyListFormat format)
{
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [archiver setOutputFormat:format];
    [archiver encodeObject:root forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    NSData *data = [[[archiver encodedData] retain] autorelease];
    [archiver release];
    return data;
}

static id unarchive(NSData *data)
{
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:NULL];
    [unarchiver setRequiresSecureCoding:NO];
    id root = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [[root retain] autorelease];
    [unarchiver finishDecoding];
    [unarchiver release];
    return root;
}

static id roundTrip(id root)
{
    return unarchive(archive(root, NSPropertyListBinaryFormat_v1_0));
}

static NSUInteger uidValue(id uid)
{
    // A reference to another archived object: CF$UID in the property list.
    if ([uid isKindOfClass:[NSDictionary class]])
    {
        return [uid[@"CF$UID"] unsignedIntegerValue];
    }
    const char *text = [[uid description] UTF8String];
    const char *value = strstr(text, "value = ");
    return value != NULL ? (NSUInteger)strtoul(value + 8, NULL, 10) : 0;
}

// The archived fields of the first object with an NS.count key and what its $N references resolve to
// (the members, then the nil that ends them, shown as "nil").
static NSArray *tableMembers(NSData *data, NSMutableDictionary **fieldsOut)
{
    NSMutableArray *members = [NSMutableArray array];
    id plist = (id)CFPropertyListCreateWithData(NULL, (CFDataRef)data, kCFPropertyListMutableContainers, NULL, NULL);
    NSArray *objects = plist[@"$objects"];
    for (id object in objects)
    {
        if (![object isKindOfClass:[NSDictionary class]] || object[@"NS.count"] == nil || object[@"$class"] == nil)
        {
            continue;
        }
        if (fieldsOut != NULL)
        {
            *fieldsOut = object;
        }
        for (int i = 0; object[[NSString stringWithFormat:@"$%d", i]] != nil; i++)
        {
            id reference = object[[NSString stringWithFormat:@"$%d", i]];
            if ([reference isKindOfClass:[NSNumber class]])
            {
                continue;  // the options
            }
            NSUInteger index = uidValue(reference);
            id target = objects[index];
            // The archive's nil entry is index 0; a "$null" string object elsewhere is a dropped weak member.
            [members addObject:index == 0 ? @"nil" : [target isKindOfClass:[NSString class]] ? target : @"<object>"];
        }
        break;
    }
    [plist autorelease];
    return members;
}

static NSData *withCount(NSData *data, int count)
{
    CFMutableDictionaryRef plist = (CFMutableDictionaryRef)CFPropertyListCreateWithData(NULL, (CFDataRef)data, kCFPropertyListMutableContainers, NULL, NULL);
    for (id object in (NSArray *)CFDictionaryGetValue(plist, @"$objects"))
    {
        if ([object isKindOfClass:[NSMutableDictionary class]] && object[@"NS.count"] != nil)
        {
            object[@"NS.count"] = @(count);
        }
    }
    NSData *result = (NSData *)CFPropertyListCreateData(NULL, plist, kCFPropertyListBinaryFormat_v1_0, 0, NULL);
    CFRelease(plist);
    return [result autorelease];
}

static void checkTwoEntries(NSMapTable *map, const char *what)
{
    if (map == nil || ![map isKindOfClass:[NSMapTable class]])
    {
        printf("FAIL %s: not a map table\n", what);
        failures++;
        return;
    }
    if ([map count] != 2 || ![[map objectForKey:@"key1"] isEqual:@"val1"] || ![[map objectForKey:@"key2"] isEqual:@"val2"])
    {
        printf("FAIL %s: count %lu key1 %s key2 %s\n", what, (unsigned long)[map count],
               [[[map objectForKey:@"key1"] description] UTF8String], [[[map objectForKey:@"key2"] description] UTF8String]);
        failures++;
    }
}

static void checkHash(NSHashTable *table, NSUInteger count, const char *what)
{
    if (![table isKindOfClass:[NSHashTable class]] || [table count] != count ||
        (count == 2 && !([table containsObject:@"key1"] && [table containsObject:@"key2"])))
    {
        printf("FAIL %s: count %lu\n", what, (unsigned long)[table count]);
        failures++;
    }
}

// The several-tables archive: @[ members, weak-to-strong {key1: val1}, strong {key2: val2}, weak hash {key1, key2},
// strong-to-weak {key2: val1} ], every table decoded with its own $0, $1, ... keys.
static void checkSeveralTables(NSArray *root, const char *what)
{
    if ([root count] != 5)
    {
        printf("FAIL %s: root has %lu elements\n", what, (unsigned long)[root count]);
        failures++;
        return;
    }
    NSMapTable *m1 = root[1], *m2 = root[2], *m4 = root[4];
    NSHashTable *h3 = root[3];
    if ([m1 count] != 1 || ![[m1 objectForKey:@"key1"] isEqual:@"val1"] || [m2 count] != 1 || ![[m2 objectForKey:@"key2"] isEqual:@"val2"] ||
        [h3 count] != 2 || ![h3 containsObject:@"key1"] || [m4 count] != 1 || ![[m4 objectForKey:@"key2"] isEqual:@"val1"])
    {
        printf("FAIL %s: counts %lu %lu %lu %lu\n", what, (unsigned long)[m1 count], (unsigned long)[m2 count], (unsigned long)[h3 count], (unsigned long)[m4 count]);
        failures++;
    }
}

static NSData *fixture(const char *dir, const char *os, const char *name)
{
    NSString *path = [NSString stringWithFormat:@"%s/%s/%s.plist", dir, os, name];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil)
    {
        printf("FAIL: cannot read %s\n", [path UTF8String]);
        failures++;
    }
    return data;
}

int main(int argc, char **argv)
{
    if (argc < 2)
    {
        printf("usage: %s <fixture dir>\n", argv[0]);
        return 2;
    }
    @autoreleasepool
    {
        NSString *k1 = [NSString stringWithFormat:@"key%d", 1], *k2 = [NSString stringWithFormat:@"key%d", 2];
        NSString *v1 = [NSString stringWithFormat:@"val%d", 1], *v2 = [NSString stringWithFormat:@"val%d", 2];

        // Strong and copy members are archived as themselves and come back.
        NSMapTable *strong = [NSMapTable strongToStrongObjectsMapTable];
        [strong setObject:v1 forKey:k1];
        [strong setObject:v2 forKey:k2];
        checkTwoEntries(roundTrip(@[ strong ])[0], "strong map round trip");
        NSMapTable *copying = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsCopyIn
                                                    valueOptions:NSPointerFunctionsStrongMemory];
        [copying setObject:v1 forKey:k1];
        [copying setObject:v2 forKey:k2];
        checkTwoEntries(roundTrip(@[ copying ])[0], "copy map round trip");
        NSHashTable *strongHash = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory];
        [strongHash addObject:k1];
        [strongHash addObject:k2];
        checkHash(roundTrip(@[ strongHash ])[0], 2, "strong hash round trip");

        // test_quirk_weak_table_members_are_conditional: members encoded elsewhere come back, in either order
        NSMapTable *weakKeys = [NSMapTable weakToStrongObjectsMapTable];
        [weakKeys setObject:v1 forKey:k1];
        [weakKeys setObject:v2 forKey:k2];
        checkTwoEntries(roundTrip(@[ @[ k1, k2 ], weakKeys ])[1], "weak keys, keys archived first");
        checkTwoEntries(roundTrip(@[ weakKeys, @[ k1, k2 ] ])[0], "weak keys, keys archived after");
        NSMapTable *weakValues = [NSMapTable strongToWeakObjectsMapTable];
        [weakValues setObject:v1 forKey:k1];
        [weakValues setObject:v2 forKey:k2];
        checkTwoEntries(roundTrip(@[ @[ v1, v2 ], weakValues ])[1], "weak values");
        NSMapTable *weakWeak = [NSMapTable weakToWeakObjectsMapTable];
        [weakWeak setObject:v1 forKey:k1];
        [weakWeak setObject:v2 forKey:k2];
        checkTwoEntries(roundTrip(@[ @[ k1, v1, k2, v2 ], weakWeak ])[1], "weak keys and values");
        NSHashTable *weakHash = [NSHashTable weakObjectsHashTable];
        [weakHash addObject:k1];
        [weakHash addObject:k2];
        checkHash(roundTrip(@[ @[ k1, k2 ], weakHash ])[1], 2, "weak hash round trip");

        // Several tables in one archive: the keys of each table's entries count from $0 again
        NSMapTable *m1 = [NSMapTable weakToStrongObjectsMapTable], *m4 = [NSMapTable strongToWeakObjectsMapTable];
        [m1 setObject:v1 forKey:k1];
        [m4 setObject:v1 forKey:k2];
        NSMapTable *m2 = [NSMapTable strongToStrongObjectsMapTable];
        [m2 setObject:v2 forKey:k2];
        checkSeveralTables(roundTrip(@[ @[ k1, k2, v1, v2 ], m1, m2, weakHash, m4 ]), "several tables round trip");

        // Members that are not encoded elsewhere are dropped; the others stay.
        NSMapTable *decoded = roundTrip(@[ weakKeys ])[0];
        CHECK([decoded isKindOfClass:[NSMapTable class]] && [decoded count] == 0);
        decoded = roundTrip(@[ @[ k1 ], weakKeys ])[1];
        CHECK([decoded count] == 1 && [[decoded objectForKey:@"key1"] isEqual:@"val1"] && [decoded objectForKey:@"key2"] == nil);
        NSHashTable *decodedHash = roundTrip(@[ weakHash ])[0];
        checkHash(decodedHash, 0, "weak hash, members not archived");
        decodedHash = roundTrip(@[ @[ k2 ], weakHash ])[1];
        CHECK([decodedHash count] == 1 && [decodedHash containsObject:@"key2"]);

        // Layout: the table's slots reference the member objects, or are "$null" strings
        NSMutableDictionary *fields = nil;
        NSArray *members = tableMembers(archive(@[ @[ k1, k2 ], weakKeys ], NSPropertyListXMLFormat_v1_0), &fields);
        CHECK([members count] == 5 && ([members[0] isEqual:@"key1"] || [members[0] isEqual:@"key2"]) && [members[4] isEqual:@"nil"]);
        CHECK([members[1] isEqual:@"val1"] || [members[1] isEqual:@"val2"]);
        CHECK([fields[@"NS.count"] intValue] == 2 && [fields[@"$0"] intValue] == NSPointerFunctionsWeakMemory && [fields[@"$1"] intValue] == 0);
        members = tableMembers(archive(@[ weakKeys ], NSPropertyListXMLFormat_v1_0), NULL);
        CHECK([members count] == 5 && [members[0] isEqual:@"$null"] && [members[2] isEqual:@"$null"] && [members[4] isEqual:@"nil"]);
        members = tableMembers(archive(@[ weakHash ], NSPropertyListXMLFormat_v1_0), NULL);
        CHECK([members count] == 3 && [members[0] isEqual:@"$null"] && [members[1] isEqual:@"$null"] && [members[2] isEqual:@"nil"]);

        // A count larger than the archived entries fails the decoding (macOS) or yields what was archived.
        NSData *oversized = withCount(archive(@[ @[ k1, k2 ], weakKeys ], NSPropertyListBinaryFormat_v1_0), 2000000000);
        NSMapTable *oversizedMap = unarchive(oversized)[1];  // returns at once, not after 2 billion entries
        CHECK(oversizedMap == nil || ([oversizedMap isKindOfClass:[NSMapTable class]] && [oversizedMap count] == 2));
        NSData *negative = withCount(archive(@[ strong ], NSPropertyListBinaryFormat_v1_0), -1);
        NSMapTable *negativeMap = unarchive(negative)[0];
        CHECK(negativeMap == nil || [negativeMap count] == 0);

        // Pointer-personality weak keys, as an NSStackView's containers hold their views
        NSArray *o1 = @[ @"first" ], *o2 = @[ @"second" ];
        NSMapTable *pointers = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality
                                                     valueOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];
        [pointers setObject:@1 forKey:o1];
        [pointers setObject:@2 forKey:o2];
        NSArray *back = roundTrip(@[ @[ o1, o2 ], pointers ]);
        NSMapTable *pointersBack = back[1];
        CHECK([pointersBack count] == 2 && [[pointersBack objectForKey:back[0][0]] isEqual:@1] && [[pointersBack objectForKey:back[0][1]] isEqual:@2]);

        // Archives made by macOS (10.14.4 and 26.7.3)
        const char *systems[] = { "macos10.14", "macos26" };
        for (int s = 0; s < 2; s++)
        {
            const char *os = systems[s];
            NSArray *root = unarchive(fixture(argv[1], os, "weak-keys"));
            checkTwoEntries(root[1], [[NSString stringWithFormat:@"%s weak-keys", os] UTF8String]);
            root = unarchive(fixture(argv[1], os, "weak-values"));
            checkTwoEntries(root[1], [[NSString stringWithFormat:@"%s weak-values", os] UTF8String]);
            root = unarchive(fixture(argv[1], os, "weak-weak"));
            checkTwoEntries(root[1], [[NSString stringWithFormat:@"%s weak-weak", os] UTF8String]);
            root = unarchive(fixture(argv[1], os, "copy-strong"));
            checkTwoEntries(root[0], [[NSString stringWithFormat:@"%s copy-strong", os] UTF8String]);
            root = unarchive(fixture(argv[1], os, "weak-hash"));
            checkHash(root[1], 2, [[NSString stringWithFormat:@"%s weak-hash", os] UTF8String]);
            root = unarchive(fixture(argv[1], os, "strong-hash"));
            checkHash(root[0], 2, [[NSString stringWithFormat:@"%s strong-hash", os] UTF8String]);
            root = unarchive(fixture(argv[1], os, "weak-keys-partial"));
            CHECK([root[1] count] == 1 && [[root[1] objectForKey:@"key1"] isEqual:@"val1"]);
            root = unarchive(fixture(argv[1], os, "weak-keys-unreferenced"));
            CHECK([root count] == 1 && [root[0] isKindOfClass:[NSMapTable class]] && [root[0] count] == 0);
            checkSeveralTables(unarchive(fixture(argv[1], os, "several-tables")), [[NSString stringWithFormat:@"%s several-tables", os] UTF8String]);
            root = unarchive(fixture(argv[1], os, "weak-pointer-keys"));
            NSMapTable *map = root[1];
            CHECK([map count] == 2 && [[map objectForKey:root[0][0]] isEqual:@1] && [[map objectForKey:root[0][1]] isEqual:@2]);
        }
    }
    if (failures != 0)
    {
        printf("FAIL (%d)\n", failures);
        return 1;
    }
    printf("PASS\n");
    return 0;
}
