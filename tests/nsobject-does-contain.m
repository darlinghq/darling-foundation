// Copyright (C) 2026 Lubos Dolezel
//
// -[NSObject doesContain:] (NSComparisonMethods), see
// https://developer.apple.com/documentation/objectivec/nsobject-swift.class/doescontain(_:) . The NSObject default
// is YES only for an NSArray receiver whose indexOfObjectIdenticalTo: lookup of the argument finds something, so the
// match is by identity, not by isEqual:; every other receiver gives NO.
#import <Foundation/Foundation.h>
#include <stdio.h>

// Darling's public NSScriptWhoseTests.h does not declare the NSComparisonMethods category (macOS declares it
// there); the test declares the one method it calls so it builds either way.
@interface NSObject (DoesContainTestDeclaration)
- (BOOL)doesContain:(id)object;
@end

static int failures;

static void expectBool(const char *label, BOOL actual, BOOL expected)
{
    BOOL ok = actual == expected;
    printf("%s: %s\n", ok ? "PASS" : "FAIL", label);
    if (!ok)
        failures++;
}

// Answers indexOfObjectIdenticalTo: itself, so the test shows the result follows that message and not containsObject:
// or indexOfObject:.
@interface IndexProbeArray : NSArray
{
    NSUInteger answer;
}
- (instancetype)initWithAnswer:(NSUInteger)value;
@end

@implementation IndexProbeArray
- (instancetype)initWithAnswer:(NSUInteger)value
{
    self = [super init];
    answer = value;
    return self;
}
- (NSUInteger)count { return 0; }
- (id)objectAtIndex:(NSUInteger)index { return nil; }
- (NSUInteger)indexOfObjectIdenticalTo:(id)object { return answer; }
- (NSUInteger)indexOfObject:(id)object { return NSNotFound; }
- (BOOL)containsObject:(id)object { return NO; }
@end

int main(void)
{
    @autoreleasepool {
        // The same object instances go into the array and into the calls: the match is by identity.
        NSMutableString *a = [NSMutableString stringWithString:@"a"];
        NSMutableString *b = [NSMutableString stringWithString:@"b"];
        NSMutableString *c = [NSMutableString stringWithString:@"c"];
        NSMutableString *z = [NSMutableString stringWithString:@"z"];
        NSArray *array = @[a, b, c];

        expectBool("array contains an element", [array doesContain:b], YES);
        expectBool("array contains its first element", [array doesContain:a], YES);
        expectBool("array does not contain a missing object", [array doesContain:z], NO);

        // The lookup is by identity: an equal but distinct object is not found.
        NSMutableString *held = [NSMutableString stringWithString:@"held"];
        NSMutableString *twin = [NSMutableString stringWithString:@"held"];
        NSArray *identity = @[held];
        expectBool("array finds the identical object", [identity doesContain:held], YES);
        expectBool("equal but distinct object is not found", [identity doesContain:twin], NO);
        expectBool("containsObject: still matches by isEqual: (contrast)", [identity containsObject:twin], YES);

        expectBool("empty array", [@[] doesContain:a], NO);
        expectBool("mutable array", [[NSMutableArray arrayWithObject:a] doesContain:a], YES);

        // Only an NSArray receiver can contain anything.
        expectBool("string receiver", [@"abc" doesContain:b], NO);
        expectBool("set receiver", [[NSSet setWithObject:a] doesContain:a], NO);
        expectBool("dictionary receiver", [@{@"k": a} doesContain:a], NO);
        expectBool("number receiver", [@1 doesContain:a], NO);

        // The result follows the receiver's own indexOfObjectIdenticalTo:.
        expectBool("subclass reporting a hit", [[[IndexProbeArray alloc] initWithAnswer:0] doesContain:z], YES);
        expectBool("subclass reporting NSNotFound", [[[IndexProbeArray alloc] initWithAnswer:NSNotFound] doesContain:z], NO);
    }
    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures ? 1 : 0;
}
