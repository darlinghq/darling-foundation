#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        NSObject *object = [[[NSObject alloc] init] autorelease];

        NSHashTable<NSObject *> *weakTable = [NSHashTable weakObjectsHashTable];
        [weakTable addObject:object];
        expect([weakTable containsObject:object], @"weakObjectsHashTable should retain a weak reference until released");
        expect([weakTable member:object] == object, @"member: should return the equal stored object");
        expect([[weakTable allObjects] containsObject:object], @"allObjects should include the added object");
        expect([weakTable anyObject] != nil, @"anyObject should return a stored object");
        expect([[weakTable objectEnumerator] nextObject] != nil, @"objectEnumerator should enumerate stored objects");
        expect([[weakTable setRepresentation] containsObject:object], @"setRepresentation should include the added object");
        expect(weakTable.count == 1, @"count should be readable as a property");

        NSObject *mapValue = [[[NSObject alloc] init] autorelease];
        NSMapTable<NSString *, NSObject *> *strongToWeak = [NSMapTable strongToWeakObjectsMapTable];
        [strongToWeak setObject:mapValue forKey:@"key"];
        expect([strongToWeak objectForKey:@"key"] == mapValue, @"strongToWeakObjectsMapTable should round-trip the stored value");
        expect(strongToWeak.count == 1, @"NSMapTable.count should be readable as a property");

        NSMapTable<NSString *, NSObject *> *strongToStrong = [NSMapTable strongToStrongObjectsMapTable];
        NSMapTable<NSString *, NSObject *> *weakToStrong = [NSMapTable weakToStrongObjectsMapTable];
        NSMapTable<NSString *, NSObject *> *weakToWeak = [NSMapTable weakToWeakObjectsMapTable];
        expect(strongToStrong != nil && weakToStrong != nil && weakToWeak != nil,
               @"the remaining NSMapTable factory methods should return usable typed map tables");

        NSLog(@"PASS: NSHashTable/NSMapTable typed factories");
    }
    return 0;
}
