#import <Foundation/Foundation.h>
#import <objc/message.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

// The Swift Foundation overlay names these with @objc(...) and Swift callers
// send them through objc_msgSend; no header declares them.
static id getSubscript(id dict, id key)
{
    return ((id (*)(id, SEL, id))objc_msgSend)(dict, sel_registerName("__swift_objectForKeyedSubscript:"), key);
}

static void setSubscript(id dict, id object, id key)
{
    ((void (*)(id, SEL, id, id))objc_msgSend)(dict, sel_registerName("__swift_setObject:forKeyedSubscript:"), object, key);
}

static id initWithDictionary(id allocated, id other)
{
    return ((id (*)(id, SEL, id))objc_msgSend)(allocated, sel_registerName("__swiftInitWithDictionary_NSDictionary:"), other);
}

// A subclass that implements only the primitives, to check the initializer
// goes through -initWithObjects:forKeys:count:.
@interface PrimitiveDictionary : NSDictionary {
    NSDictionary *_storage;
@public
    BOOL _designatedCalled;
}
@end

@implementation PrimitiveDictionary
- (instancetype)initWithObjects:(const id [])objects forKeys:(const id <NSCopying> [])keys count:(NSUInteger)count
{
    _storage = [[NSDictionary alloc] initWithObjects:objects forKeys:keys count:count];
    _designatedCalled = YES;
    return self;
}
- (void)dealloc { [_storage release]; [super dealloc]; }
- (NSUInteger)count { return [_storage count]; }
- (id)objectForKey:(id)key { return [_storage objectForKey:key]; }
- (NSEnumerator *)keyEnumerator { return [_storage keyEnumerator]; }
@end

int main(void)
{
    @autoreleasepool {
        NSDictionary *source = [NSDictionary dictionaryWithObjectsAndKeys:@"one", @"a", @2, @"b", nil];

        SEL getter = sel_registerName("__swift_objectForKeyedSubscript:");
        SEL setter = sel_registerName("__swift_setObject:forKeyedSubscript:");
        SEL init = sel_registerName("__swiftInitWithDictionary_NSDictionary:");
        assert([source respondsToSelector:getter]);
        assert([[NSMutableDictionary dictionary] respondsToSelector:getter]);
        assert([[NSMutableDictionary dictionary] respondsToSelector:setter]);
        assert([NSDictionary instancesRespondToSelector:init]);

        // Getter: present and absent keys, on immutable and mutable receivers.
        assert([getSubscript(source, @"a") isEqual:@"one"]);
        assert([getSubscript(source, @"b") isEqual:@2]);
        assert(getSubscript(source, @"missing") == nil);
        NSMutableDictionary *mutable = [NSMutableDictionary dictionaryWithDictionary:source];
        assert([getSubscript(mutable, @"a") isEqual:@"one"]);

        // Setter: insert, replace, remove with nil, remove an absent key.
        setSubscript(mutable, @"three", @"c");
        assert([mutable count] == 3);
        assert([[mutable objectForKey:@"c"] isEqual:@"three"]);
        setSubscript(mutable, @"uno", @"a");
        assert([mutable count] == 3);
        assert([[mutable objectForKey:@"a"] isEqual:@"uno"]);
        setSubscript(mutable, nil, @"a");
        assert([mutable count] == 2);
        assert([mutable objectForKey:@"a"] == nil);
        setSubscript(mutable, nil, @"never-there");
        assert([mutable count] == 2);

        // The key is copied, as -setObject:forKey: does.
        NSMutableString *key = [NSMutableString stringWithString:@"k"];
        setSubscript(mutable, @"v", key);
        [key appendString:@"changed"];
        assert([[mutable objectForKey:@"k"] isEqual:@"v"]);

        // Initializer: immutable copy with the same contents.
        NSDictionary *copy = initWithDictionary([NSDictionary alloc], source);
        assert(copy != nil);
        assert([copy isEqualToDictionary:source]);
        [copy release];

        // From NSMutableDictionary it gives a mutable dictionary, independent
        // of its source.
        NSMutableDictionary *mutableCopy = initWithDictionary([NSMutableDictionary alloc], source);
        assert([mutableCopy isEqualToDictionary:source]);
        [mutableCopy setObject:@"new" forKey:@"z"];
        assert([mutableCopy count] == 3);
        assert([source count] == 2);
        [mutableCopy release];

        // Empty and nil sources give an empty dictionary.
        NSDictionary *empty = initWithDictionary([NSDictionary alloc], [NSDictionary dictionary]);
        assert(empty != nil && [empty count] == 0);
        [empty release];
        NSDictionary *fromNil = initWithDictionary([NSDictionary alloc], nil);
        assert(fromNil != nil && [fromNil count] == 0);
        [fromNil release];

        // A subclass receives the contents through its designated initializer.
        PrimitiveDictionary *primitive = initWithDictionary([PrimitiveDictionary alloc], source);
        assert([primitive isKindOfClass:[PrimitiveDictionary class]]);
        assert(primitive->_designatedCalled);
        assert([primitive isEqualToDictionary:source]);
        assert([getSubscript(primitive, @"a") isEqual:@"one"]);
        [primitive release];

        // And a primitive-only subclass works as the source.
        PrimitiveDictionary *primitiveSource = [[PrimitiveDictionary alloc] initWithObjects:(id[]){@"x"} forKeys:(id[]){@"y"} count:1];
        NSDictionary *fromPrimitive = initWithDictionary([NSDictionary alloc], primitiveSource);
        assert([[fromPrimitive objectForKey:@"y"] isEqual:@"x"]);
        [fromPrimitive release];
        [primitiveSource release];
    }
    puts("PASS: NSDictionary Swift overlay selectors");
    return 0;
}
