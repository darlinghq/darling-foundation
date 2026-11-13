/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// A keyed archive without an NSSelector entry decodes to a descriptor with the
// compare: selector (as on macOS) instead of failing; a scripted keyed coder
// stands in for an archive that lacks the entry.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

@interface KeyedScript : NSCoder
{
@public
    NSDictionary *objects;
    BOOL ascending;
}
@end
@implementation KeyedScript
- (BOOL) allowsKeyedCoding { return YES; }
- (BOOL) containsValueForKey: (NSString *) key { return [objects objectForKey: key] != nil; }
- (id) decodeObjectForKey: (NSString *) key { return [objects objectForKey: key]; }
- (id) decodeObjectOfClass: (Class) cls forKey: (NSString *) key { return [objects objectForKey: key]; }
- (id) decodeObjectOfClasses: (NSSet *) classes forKey: (NSString *) key { return [objects objectForKey: key]; }
- (BOOL) decodeBoolForKey: (NSString *) key { return ascending; }
@end

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    KeyedScript *coder = [[[KeyedScript alloc] init] autorelease];
    coder->objects = [NSDictionary dictionaryWithObject: @"name" forKey: @"NSKey"];
    coder->ascending = YES;
    NSSortDescriptor *d = [[[NSSortDescriptor alloc] initWithCoder: coder] autorelease];
    expect(d != nil, @"decoding without NSSelector returns a descriptor");
    expect([d selector] == @selector(compare:), @"selector defaults to compare:");
    expect([[d key] isEqualToString: @"name"] && [d ascending], @"key and ascending are kept");

    coder->objects = [NSDictionary dictionaryWithObjectsAndKeys: @"name", @"NSKey", @"localizedCompare:", @"NSSelector", nil];
    d = [[[NSSortDescriptor alloc] initWithCoder: coder] autorelease];
    expect([d selector] == @selector(localizedCompare:), @"a present NSSelector is still used");

    [pool drain];
    return failures ? 1 : 0;
}
