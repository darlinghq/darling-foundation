// -[NSArray setValue:forKey:], -[NSSet setValue:forKey:] and -[NSOrderedSet setValue:forKey:] send
// -setValue:forKey: with the same value and key to each member. Documented in the three method references:
// developer.apple.com/documentation/foundation/nsarray/setvalue(_:forkey:),
// .../nsset/setvalue(_:forkey:) and .../nsorderedset/setvalue(_:forkey:). The undefined-key case follows
// from sending the message to each member: the member's own -setValue:forUndefinedKey: runs.
// Built without ARC.
#import <Foundation/Foundation.h>
#include <stdio.h>

@interface Member : NSObject {
    NSString *_name;
    int _sets;
}
- (void)setName:(NSString *)name;
- (NSString *)name;
- (int)sets;
@end

@implementation Member
- (void)setName:(NSString *)name
{
    [_name autorelease];
    _name = [name copy];
    _sets++;
}
- (NSString *)name { return _name; }
- (int)sets { return _sets; }
- (void)dealloc
{
    [_name release];
    [super dealloc];
}
@end

static int failures;

static void expect(BOOL ok, const char *what)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok)
        failures++;
}

static BOOL raisesUndefinedKey(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [[exception name] isEqualToString:NSUndefinedKeyException];
    }
    return NO;
}

static Member *member(void)
{
    return [[[Member alloc] init] autorelease];
}

int main(void)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    Member *a = member(), *b = member(), *c = member();

    // NSArray: every item receives the value, an item listed twice receives it twice.
    NSArray *array = [NSArray arrayWithObjects:a, b, a, nil];
    [array setValue:@"array" forKey:@"name"];
    expect([[a name] isEqualToString:@"array"] && [[b name] isEqualToString:@"array"], "NSArray: every item receives the value");
    expect([a sets] == 2 && [b sets] == 1, "NSArray: -setValue:forKey: is sent once per item");

    // NSMutableArray inherits it.
    NSMutableArray *mutableArray = [NSMutableArray arrayWithObjects:a, b, nil];
    [mutableArray setValue:@"mutable" forKey:@"name"];
    expect([[a name] isEqualToString:@"mutable"] && [[b name] isEqualToString:@"mutable"], "NSMutableArray: every item receives the value");

    // NSSet and NSCountedSet.
    NSSet *set = [NSSet setWithObjects:a, b, c, nil];
    [set setValue:@"set" forKey:@"name"];
    expect([[a name] isEqualToString:@"set"] && [[b name] isEqualToString:@"set"] && [[c name] isEqualToString:@"set"],
           "NSSet: every member receives the value");
    NSCountedSet *counted = [NSCountedSet setWithObjects:a, b, nil];
    [counted setValue:@"counted" forKey:@"name"];
    expect([[a name] isEqualToString:@"counted"] && [[b name] isEqualToString:@"counted"], "NSCountedSet: every member receives the value");

    // NSOrderedSet and NSMutableOrderedSet.
    NSOrderedSet *ordered = [NSOrderedSet orderedSetWithObjects:a, b, c, nil];
    [ordered setValue:@"ordered" forKey:@"name"];
    expect([[a name] isEqualToString:@"ordered"] && [[b name] isEqualToString:@"ordered"] && [[c name] isEqualToString:@"ordered"],
           "NSOrderedSet: every member receives the value");
    NSMutableOrderedSet *mutableOrdered = [NSMutableOrderedSet orderedSetWithObjects:a, b, nil];
    [mutableOrdered setValue:@"mutable ordered" forKey:@"name"];
    expect([[a name] isEqualToString:@"mutable ordered"] && [[c name] isEqualToString:@"ordered"],
           "NSMutableOrderedSet: its members receive the value, others do not");

    // A nil value is passed through to the members.
    [array setValue:nil forKey:@"name"];
    expect([a name] == nil && [b name] == nil, "NSArray: nil is passed to the members");
    [set setValue:nil forKey:@"name"];
    expect([c name] == nil, "NSSet: nil is passed to the members");
    [ordered setValue:nil forKey:@"name"];
    expect([a name] == nil && [c name] == nil, "NSOrderedSet: nil is passed to the members");

    // Members need not be of one class: dictionaries take the value as an entry.
    // The two dictionaries differ (an NSSet holds one of two equal members, and they are equal once both got the same entry).
    NSMutableDictionary *d1 = [NSMutableDictionary dictionaryWithObject:@1 forKey:@"id"];
    NSMutableDictionary *d2 = [NSMutableDictionary dictionaryWithObject:@2 forKey:@"id"];
    [[NSArray arrayWithObjects:d1, d2, nil] setValue:@"v" forKey:@"k"];
    expect([[d1 objectForKey:@"k"] isEqual:@"v"] && [[d2 objectForKey:@"k"] isEqual:@"v"], "NSArray of dictionaries: each gets the entry");
    [[NSSet setWithObjects:d1, d2, nil] setValue:@"w" forKey:@"k"];
    expect([[d1 objectForKey:@"k"] isEqual:@"w"] && [[d2 objectForKey:@"k"] isEqual:@"w"], "NSSet of dictionaries: each gets the entry");
    [[NSOrderedSet orderedSetWithObjects:d1, d2, nil] setValue:@"x" forKey:@"k"];
    expect([[d1 objectForKey:@"k"] isEqual:@"x"] && [[d2 objectForKey:@"k"] isEqual:@"x"], "NSOrderedSet of dictionaries: each gets the entry");

    // An empty collection has nothing to send it to.
    [[NSArray array] setValue:@"nothing" forKey:@"name"];
    [[NSSet set] setValue:@"nothing" forKey:@"name"];
    [[NSOrderedSet orderedSet] setValue:@"nothing" forKey:@"name"];
    expect(YES, "empty collections accept the call");

    // A key the members do not define raises from the member's own undefined-key handling.
    Member *probe = member();
    expect(raisesUndefinedKey(^{ [[NSArray arrayWithObject:probe] setValue:@"x" forKey:@"noSuchKey"]; }), "NSArray: an undefined key raises NSUndefinedKeyException");
    expect(raisesUndefinedKey(^{ [[NSSet setWithObject:probe] setValue:@"x" forKey:@"noSuchKey"]; }), "NSSet: an undefined key raises NSUndefinedKeyException");
    expect(raisesUndefinedKey(^{ [[NSOrderedSet orderedSetWithObject:probe] setValue:@"x" forKey:@"noSuchKey"]; }), "NSOrderedSet: an undefined key raises NSUndefinedKeyException");

    [pool drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
