/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// -[NSUnarchiver versionForClassName:] returns the class version recorded in
// the archive, including a recorded 0, and NSNotFound for a class that the
// archive does not mention (documented as the "not recorded" result).
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

@interface VersionSeven : NSObject <NSCoding>
@end

@implementation VersionSeven
+ (void) initialize
{
    if (self == [VersionSeven class])
        [self setVersion: 7];
}
- (void) encodeWithCoder: (NSCoder *) coder
{
    int value = 3;
    [coder encodeValueOfObjCType: "i" at: &value];
}
- (id) initWithCoder: (NSCoder *) coder
{
    int value;
    [coder decodeValueOfObjCType: "i" at: &value];
    return self;
}
@end

@interface VersionZero : VersionSeven
@end

@implementation VersionZero
+ (void) initialize
{
    if (self == [VersionZero class])
        [self setVersion: 0];
}
@end

int main(void)
{
    @autoreleasepool {
        NSArray *root = [NSArray arrayWithObjects: [[VersionSeven new] autorelease],
                                                  [[VersionZero new] autorelease], nil];
        NSData *data = [NSArchiver archivedDataWithRootObject: root];
        NSUnarchiver *unarchiver = [[NSUnarchiver alloc] initForReadingWithData: data];

        expect([unarchiver versionForClassName: @"VersionSeven"] == NSNotFound,
               @"nothing is recorded before decoding");
        expect([unarchiver decodeObject] != nil, @"archive decodes");
        expect([unarchiver versionForClassName: @"VersionSeven"] == 7,
               @"recorded version is returned");
        expect([unarchiver versionForClassName: @"VersionZero"] == 0,
               @"a recorded version 0 is 0, not NSNotFound");
        expect([unarchiver versionForClassName: @"NSView"] == NSNotFound,
               @"a class the archive does not mention gives NSNotFound");
        expect([unarchiver versionForClassName: @"NoSuchClassAnywhere"] == NSNotFound,
               @"an unknown class name gives NSNotFound");

        NSData *plain = [NSArchiver archivedDataWithRootObject: @"plain"];
        NSUnarchiver *second = [[NSUnarchiver alloc] initForReadingWithData: plain];
        [second decodeObject];
        expect([second versionForClassName: @"NSArray"] == NSNotFound,
               @"a second archive without that class gives NSNotFound");
    }
    if (failures == 0)
        printf("OK\n");
    return failures != 0;
}
