// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: a dictionary literal is archived as NSDictionary and decodes
// under secure coding. Observed on macOS 26.7.3 (x86_64) with the same calls:
// the literal's classForCoder and classForKeyedArchiver are NSDictionary, the
// archive names only NSDictionary and NSObject, and the round trip succeeds.
#import <Foundation/Foundation.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

int main(void)
{
    @autoreleasepool {
        NSDictionary *literal = @{ @"a": @1, @"b": @"two" };
        report("classForCoder", [literal classForCoder] == [NSDictionary class]);
        report("classForKeyedArchiver", [literal classForKeyedArchiver] == [NSDictionary class]);

        NSData *data = [NSKeyedArchiver archivedDataWithRootObject: literal requiringSecureCoding: YES error: NULL];
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData: data options: 0 format: NULL error: NULL];
        BOOL namesOnlyDictionary = NO;
        for (id object in plist[@"$objects"]) {
            if ([object isKindOfClass: [NSDictionary class]] && object[@"$classname"] != nil)
                namesOnlyDictionary = [object[@"$classes"] isEqual: @[ @"NSDictionary", @"NSObject" ]];
        }
        report("archived class names", namesOnlyDictionary);

        NSSet *classes = [NSSet setWithObjects: [NSDictionary class], [NSString class], [NSNumber class], nil];
        NSError *error = nil;
        NSDictionary *decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses: classes fromData: data error: &error];
        report("secure round trip", error == nil && [decoded isEqual: literal]);
    }
    return failures != 0;
}
