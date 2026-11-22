// -[NSOrderedSet valueForKey:] and key paths through an ordered set.
// Contract: developer.apple.com/documentation/foundation/nsorderedset/value(forkey:): an ordered set of the results of
// -valueForKey: on each member; it may have fewer members than the receiver, since a nil result leaves no entry
// and it holds no duplicates. NSOrderedSet has no page of its own for -valueForKeyPath:; a key path is resolved
// by NSObject's -valueForKeyPath:, key by key (the Key-Value Coding Programming Guide), so each step maps over
// the ordered set the previous one gave.
// Built without ARC.
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
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSDictionary *c = @{ @"name": @"c", @"size": @1, @"inner": @{ @"v": @"x" } };
    NSDictionary *a = @{ @"name": @"a", @"size": @1 };
    NSDictionary *none = @{};
    NSDictionary *b = @{ @"name": @"b", @"inner": @{ @"v": @"y" } };
    NSDictionary *again = @{ @"name": @"c", @"inner": @{ @"v": @"x" } };
    NSOrderedSet *set = [NSOrderedSet orderedSetWithObjects:c, a, none, b, again, nil];

    id names = [set valueForKey:@"name"];
    expect([names isKindOfClass:[NSOrderedSet class]], "the result is an ordered set");
    expect([names isEqual:[NSOrderedSet orderedSetWithObjects:@"c", @"a", @"b", nil]],
           "the members' values are kept in the order of the receiver, without nil results and duplicates");
    expect([names count] < [set count], "the result may have fewer members than the receiver");

    expect([[set valueForKey:@"size"] isEqual:[NSOrderedSet orderedSetWithObject:@1]],
           "equal values from different members collapse into one");
    id missing = [set valueForKey:@"missing"];
    expect(missing != nil && [missing isKindOfClass:[NSOrderedSet class]] && [missing count] == 0,
           "a key no member has gives an empty ordered set, not nil");
    id empty = [[NSOrderedSet orderedSet] valueForKey:@"name"];
    expect(empty != nil && [empty count] == 0, "an empty ordered set gives an empty ordered set");

    NSMutableOrderedSet *mutableSet = [NSMutableOrderedSet orderedSetWithObjects:b, a, nil];
    id fromMutable = [mutableSet valueForKey:@"name"];
    expect(fromMutable != mutableSet && [fromMutable isEqual:[NSOrderedSet orderedSetWithObjects:@"b", @"a", nil]],
           "a mutable ordered set gives a new ordered set of its members' values, in order");
    [mutableSet addObject:none];
    expect([names count] == 3, "an earlier result is not changed by a later change of the receiver");

    expect([[set valueForKeyPath:@"inner.v"] isEqual:[NSOrderedSet orderedSetWithObjects:@"x", @"y", nil]],
           "a key path maps over the ordered set at each step");
    expect([[set valueForKeyPath:@"name"] isEqual:names], "a key path of one key is the key");

    [pool drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
