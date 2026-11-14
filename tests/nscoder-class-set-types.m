/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// -decodeObjectOfClasses:forKey: takes an NSSet<Class> and -allowedClasses is a readonly NSSet<Class>
// property, as in the public NSCoder declaration. Compiling this file with -Werror=incompatible-pointer-types
// -Werror=nullability checks the declared types; the run checks that the set reaches the decoded object's
// -initWithCoder: through -allowedClasses and that it is empty outside a class-restricted decode.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

static NSSet<Class> *observedClasses;
static BOOL sawAllowedClasses;

@interface ClassSetProbe : NSObject <NSSecureCoding>
@end

@implementation ClassSetProbe
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSSet<Class> *classes = coder.allowedClasses;
    sawAllowedClasses = YES;
    observedClasses = [classes copy];
    return [super init];
}
@end

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject: [[[ClassSetProbe alloc] init] autorelease] requiringSecureCoding: YES error: NULL];
    NSKeyedUnarchiver *u = [[[NSKeyedUnarchiver alloc] initForReadingFromData: data error: NULL] autorelease];
    [u setRequiresSecureCoding: YES];

    NSSet<Class> *outside = u.allowedClasses;
    expect(outside == nil || [outside count] == 0, @"allowedClasses is empty outside a class-restricted decode");

    NSSet<Class> *wanted = [NSSet setWithObjects: [ClassSetProbe class], [NSString class], nil];
    id decoded = [u decodeObjectOfClasses: wanted forKey: NSKeyedArchiveRootObjectKey];
    expect([decoded isKindOfClass: [ClassSetProbe class]], @"decodeObjectOfClasses: with an NSSet<Class> decodes the object");
    expect(sawAllowedClasses && [observedClasses isEqualToSet: wanted], @"allowedClasses returns the set during the decode");

    id missing = [u decodeObjectOfClasses: wanted forKey: @"no-such-key"];
    expect(missing == nil, @"decodeObjectOfClasses: returns nil for a missing key");

    [pool drain];
    return failures ? 1 : 0;
}
