#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

static void expectNilFailure(id collection, NSString *path)
{
    BOOL raised = NO;
    @try { [collection valueForKeyPath:path]; }
    @catch (NSException *exception) { raised = [[exception name] isEqual:NSInvalidArgumentException]; }
    assert((raised));
}

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
        expectNilFailure(@[@{}], @"@unionOfObjects.missing");
        expectNilFailure(@[@{}], @"@distinctUnionOfObjects.missing");
        expectNilFailure(@[@[@{}]], @"@unionOfArrays.missing");
        expectNilFailure(@[@[@{}]], @"@distinctUnionOfArrays.missing");
        expectNilFailure([NSSet setWithObject:[NSSet setWithObject:@{}]], @"@distinctUnionOfSets.missing");
        assert(([[@[@1, @2, @3] valueForKeyPath:@"@sum.self"] intValue] == 6));
        assert(([[objects valueForKeyPath:@"@count"] unsignedIntegerValue] == 3));
    }
    puts("PASS: KVC unions, duplicates, nesting, key paths, nil rejection and aggregates");
    return 0;
}
