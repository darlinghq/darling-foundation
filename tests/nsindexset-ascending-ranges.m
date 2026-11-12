// Copyright (C) 2026 Lubos Dolezel
//
// NSMutableIndexSet keeps its ranges in ascending order whatever order they
// are added in.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

static NSString *ranges(NSIndexSet *set)
{
    NSMutableString *result = [NSMutableString string];
    [set enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
        [result appendFormat:@"{%lu,%lu}", (unsigned long)range.location, (unsigned long)range.length];
    }];
    return result;
}

static void checkAscending(NSIndexSet *set, NSUInteger count, NSUInteger first, NSUInteger last, const char *label)
{
    if ([set count] != count || [set firstIndex] != first || [set lastIndex] != last) {
        printf("FAIL %s: count %lu first %lu last %lu, ranges %s\n", label, (unsigned long)[set count],
               (unsigned long)[set firstIndex], (unsigned long)[set lastIndex], [ranges(set) UTF8String]);
        failures++;
    }
    // Walking the set forwards and backwards must visit the indexes in order.
    NSUInteger visited = 0, previous = NSNotFound;
    for (NSUInteger index = [set firstIndex]; index != NSNotFound; index = [set indexGreaterThanIndex:index]) {
        if (previous != NSNotFound && index <= previous) { printf("FAIL %s: %lu after %lu\n", label, (unsigned long)index, (unsigned long)previous); failures++; break; }
        previous = index;
        visited++;
    }
    CHECK(visited == count);
    visited = 0;
    previous = NSNotFound;
    for (NSUInteger index = [set lastIndex]; index != NSNotFound; index = [set indexLessThanIndex:index]) {
        if (previous != NSNotFound && index >= previous) { printf("FAIL %s: backwards %lu after %lu\n", label, (unsigned long)index, (unsigned long)previous); failures++; break; }
        previous = index;
        visited++;
    }
    CHECK(visited == count);
}

int main(void)
{
    @autoreleasepool
    {
        NSMutableIndexSet *ascending = [NSMutableIndexSet indexSet];
        for (NSUInteger index = 1; index <= 30; index += 4) [ascending addIndex:index];   // 1 5 9 ... 29
        NSString *expected = @"{1,1}{5,1}{9,1}{13,1}{17,1}{21,1}{25,1}{29,1}";
        CHECK([ranges(ascending) isEqualToString:expected]);
        checkAscending(ascending, 8, 1, 29, "single indexes ascending");

        NSMutableIndexSet *descending = [NSMutableIndexSet indexSet];
        for (NSInteger index = 29; index >= 1; index -= 4) [descending addIndex:(NSUInteger)index];
        CHECK([ranges(descending) isEqualToString:expected]);
        CHECK([ascending isEqualToIndexSet:descending]);

        NSMutableIndexSet *ranged = [NSMutableIndexSet indexSet];
        [ranged addIndexesInRange:NSMakeRange(10, 5)];
        [ranged addIndexesInRange:NSMakeRange(20, 5)];
        [ranged addIndexesInRange:NSMakeRange(30, 5)];
        [ranged addIndexesInRange:NSMakeRange(40, 5)];
        CHECK([ranges(ranged) isEqualToString:@"{10,5}{20,5}{30,5}{40,5}"]);
        checkAscending(ranged, 20, 10, 44, "ranges ascending");
        // Filling a gap merges the neighbours.
        [ranged addIndexesInRange:NSMakeRange(15, 5)];
        CHECK([ranges(ranged) isEqualToString:@"{10,15}{30,5}{40,5}"]);
        [ranged addIndexesInRange:NSMakeRange(25, 5)];
        [ranged addIndexesInRange:NSMakeRange(35, 5)];
        CHECK([ranges(ranged) isEqualToString:@"{10,35}"]);

        // Adding in the middle and at the ends in a mixed order.
        NSMutableIndexSet *mixed = [NSMutableIndexSet indexSet];
        NSUInteger order[] = {50, 10, 30, 70, 20, 60, 40, 5, 80};
        for (size_t i = 0; i < sizeof order / sizeof order[0]; i++) [mixed addIndex:order[i]];
        CHECK([ranges(mixed) isEqualToString:@"{5,1}{10,1}{20,1}{30,1}{40,1}{50,1}{60,1}{70,1}{80,1}"]);
        checkAscending(mixed, 9, 5, 80, "mixed");
        // Re-adding an index that is already present changes nothing.
        [mixed addIndex:30];
        [mixed addIndexesInRange:NSMakeRange(20, 1)];
        CHECK([mixed count] == 9);
        CHECK([mixed containsIndex:40] && ![mixed containsIndex:41]);
        [mixed removeIndex:40];
        CHECK([mixed count] == 8 && ![mixed containsIndex:40]);
        CHECK([mixed indexGreaterThanIndex:30] == 50);
        CHECK([mixed indexLessThanIndex:50] == 30);
        NSIndexSet *copy = [[mixed copy] autorelease];
        CHECK([copy isEqualToIndexSet:mixed]);
    }
    if (failures != 0) { printf("%d failures\n", failures); return 1; }
    printf("PASS: NSMutableIndexSet range order\n");
    return 0;
}
