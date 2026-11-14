/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// -[NSSortDescriptor initWithCoder:] with a non-keyed coder (old nibs and
// archives): the key, a flag byte for ascending and the selector name are read
// in that order; a missing selector name gives compare:. A scripted coder
// stands in for the old archive.
#import <Foundation/Foundation.h>
#include <stdarg.h>
#include <stdio.h>

static int failures;

static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

@interface ScriptedCoder : NSCoder
{
@public
    NSMutableArray *objects;
    char flag;
    NSMutableArray *calls;
}
@end

@implementation ScriptedCoder
- (BOOL) allowsKeyedCoding { return NO; }
- (NSInteger) versionForClassName: (NSString *) name { return 0; }
- (unsigned) systemVersion { return 1000; }
- (void) decodeValueOfObjCType: (const char *) type at: (void *) p
{
    [calls addObject: [NSString stringWithUTF8String: type]];
    if (type[0] == 'c')
        *(char *) p = flag;
}
- (void) decodeValuesOfObjCTypes: (const char *) types, ...
{
    va_list ap;
    va_start(ap, types);
    void *p = va_arg(ap, void *);
    va_end(ap);
    [calls addObject: [NSString stringWithFormat: @"multi:%s", types]];
    if (types[0] == 'c')
        *(char *) p = flag;
}
- (id) decodeObject
{
    [calls addObject: @"obj"];
    if ([objects count] == 0)
        return nil;
    id o = [[objects objectAtIndex: 0] retain];
    [objects removeObjectAtIndex: 0];
    return [o autorelease];
}
@end

static NSSortDescriptor *decode(NSArray *objs, char flag, NSArray **calls)
{
    ScriptedCoder *coder = [[ScriptedCoder alloc] init];
    coder->objects = [[objs mutableCopy] autorelease];
    coder->flag = flag;
    coder->calls = [NSMutableArray array];
    NSSortDescriptor *d = [[[NSSortDescriptor alloc] initWithCoder: coder] autorelease];
    if (calls)
        *calls = coder->calls;
    [coder release];
    return d;
}

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSArray *calls = nil;

    NSSortDescriptor *d = decode([NSArray arrayWithObjects: @"name", @"localizedCompare:", nil], 1, &calls);
    expect(d != nil, @"non-keyed decode returns a descriptor");
    expect([[d key] isEqualToString: @"name"], @"key decoded");
    expect([d ascending], @"flag 1 is ascending");
    expect([d selector] == @selector(localizedCompare:), @"selector name decoded");
    expect([[calls componentsJoinedByString: @" "] isEqualToString: @"obj multi:c obj"], @"read order is object, byte, object");

    d = decode([NSArray arrayWithObjects: @"name", @"caseInsensitiveCompare:", nil], 0, NULL);
    expect(![d ascending], @"flag 0 is descending");
    expect([d selector] == @selector(caseInsensitiveCompare:), @"selector with descending");

    d = decode([NSArray arrayWithObjects: @"name", nil], 1, NULL);
    expect([d selector] == @selector(compare:), @"missing selector name gives compare:");

    d = decode([NSArray array], 1, NULL);
    expect(d != nil && [d key] == nil && [d selector] == @selector(compare:), @"nil key stays nil");

    [pool drain];
    return failures ? 1 : 0;
}
