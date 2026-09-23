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
        NSNumber *original = @42;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:original];

        NSError *error = nil;
        NSNumber *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSNumber class]
                                                                fromData:data
                                                                   error:&error];
        expect(error == nil, @"unarchivedObjectOfClass:fromData:error: should not report an error");
        expect([decoded isEqual:original], @"unarchivedObjectOfClass:fromData:error: should round-trip the value");

        NSSet *classes = [NSSet setWithObject:[NSNumber class]];
        NSNumber *decodedAny = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                     fromData:data
                                                                        error:&error];
        expect(error == nil, @"unarchivedObjectOfClasses:fromData:error: should not report an error");
        expect([decodedAny isEqual:original], @"unarchivedObjectOfClasses:fromData:error: should round-trip the value");

        NSLog(@"PASS: NSKeyedUnarchiver unarchivedObjectOfClass(es):fromData:error: still work from Objective-C");
    }
    return 0;
}
