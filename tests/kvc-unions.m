#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool {
        NSArray *objects = @[@"a", @"b", @"a"];
        NSArray *nested = @[objects, @[@"c", @"a"]];
        assert(([[objects valueForKeyPath:@"@unionOfObjects.self"] isEqual:objects]));
        id distinct = [objects valueForKeyPath:@"@distinctUnionOfObjects.self"];
        assert(([distinct isKindOfClass:[NSArray class]]));
        assert(([distinct count] == 2));
        assert(([[NSSet setWithArray:distinct] isEqual:[NSSet setWithArray:@[@"a", @"b"]]]));
        assert(([[nested valueForKeyPath:@"@unionOfArrays.self"] isEqual:@[@"a", @"b", @"a", @"c", @"a"]]));
        distinct = [nested valueForKeyPath:@"@distinctUnionOfArrays.self"];
        assert(([distinct isKindOfClass:[NSArray class]] && [distinct count] == 3));
        assert(([[NSSet setWithArray:distinct] isEqual:[NSSet setWithArray:@[@"a", @"b", @"c"]]]));

        NSSet *sets = [NSSet setWithArray:@[[NSSet setWithArray:objects], [NSSet setWithArray:@[@"b", @"c"]]]];
        distinct = [sets valueForKeyPath:@"@distinctUnionOfSets.self"];
        assert(([distinct isKindOfClass:[NSSet class]]));
        assert(([distinct isEqual:[NSSet setWithArray:@[@"a", @"b", @"c"]]]));

        NSArray *records = @[@{@"info": @{@"name": @"a"}}, @{@"info": @{@"name": @"b"}}];
        assert(([[records valueForKeyPath:@"@unionOfObjects.info.name"] isEqual:@[@"a", @"b"]]));
        distinct = [records valueForKeyPath:@"@distinctUnionOfObjects.info.name"];
        assert(([[NSSet setWithArray:distinct] isEqual:[NSSet setWithArray:@[@"a", @"b"]]]));
        assert(([[@[] valueForKeyPath:@"@unionOfObjects.self"] count] == 0));
        assert(([[@[] valueForKeyPath:@"@unionOfArrays.self"] count] == 0));
        // Nil values: the object unions omit them; the array union keeps the NSNull that
        // mapping a key path over an array produces (observed on macOS).
        NSArray *sparse = @[@{@"k": @"a"}, @{}];
        assert(([[sparse valueForKeyPath:@"@unionOfObjects.k"] isEqual:@[@"a"]]));
        assert(([[sparse valueForKeyPath:@"@distinctUnionOfObjects.k"] isEqual:@[@"a"]]));
        assert(([[@[sparse] valueForKeyPath:@"@unionOfArrays.k"] isEqual:@[@"a", [NSNull null]]]));
        distinct = [[NSSet setWithObject:[NSSet setWithArray:sparse]] valueForKeyPath:@"@distinctUnionOfSets.k"];
        assert(([distinct isEqual:[NSSet setWithObject:@"a"]]));
        BOOL raised = NO;
        @try { [@[@"notAnArray"] valueForKeyPath:@"@unionOfArrays.self"]; }
        @catch (NSException *exception) { raised = [[exception name] isEqual:NSInvalidArgumentException]; }
        assert(raised);
        assert(([[@[@1, @2, @3] valueForKeyPath:@"@sum.self"] intValue] == 6));
        assert(([[objects valueForKeyPath:@"@count"] unsignedIntegerValue] == 3));
    }
    puts("PASS: KVC unions, duplicates, nesting, key paths, nil handling and aggregates");
    return 0;
}
