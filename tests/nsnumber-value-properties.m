#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <limits.h>
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
        NSNumber *negative = [NSNumber numberWithInt:-42];
        // Property and message syntax must agree.
        expect(negative.charValue == [negative charValue], @"charValue");
        expect(negative.shortValue == -42, @"shortValue");
        expect(negative.intValue == -42, @"intValue");
        expect(negative.longValue == -42, @"longValue");
        expect(negative.longLongValue == -42, @"longLongValue");
        expect(negative.integerValue == -42, @"integerValue");
        expect([negative.stringValue isEqualToString:@"-42"], @"stringValue");

        NSNumber *unsignedNumber = [NSNumber numberWithUnsignedLongLong:ULLONG_MAX];
        expect(unsignedNumber.unsignedLongLongValue == ULLONG_MAX, @"unsignedLongLongValue");
        expect(unsignedNumber.unsignedLongValue == ULONG_MAX, @"unsignedLongValue");
        expect(unsignedNumber.unsignedIntegerValue == NSUIntegerMax, @"unsignedIntegerValue");

        NSNumber *small = [NSNumber numberWithUnsignedChar:200];
        expect(small.unsignedCharValue == 200, @"unsignedCharValue");
        expect(small.unsignedShortValue == 200, @"unsignedShortValue");
        expect(small.unsignedIntValue == 200, @"unsignedIntValue");

        NSNumber *real = [NSNumber numberWithDouble:2.5];
        expect(real.doubleValue == 2.5, @"doubleValue");
        expect(real.floatValue == 2.5f, @"floatValue");
        expect(real.intValue == 2, @"intValue truncates");

        expect([NSNumber numberWithBool:YES].boolValue && ![NSNumber numberWithBool:NO].boolValue, @"boolValue");

        NSDecimalNumber *decimal = [NSDecimalNumber decimalNumberWithString:@"1.5"];
        expect(decimal.doubleValue == 1.5 && decimal.intValue == 1, @"NSDecimalNumber overrides");

        // The accessors are implemented by the concrete subclasses; NSNumber itself holds no storage.
        unsigned int count = 0;
        free(class_copyIvarList([NSNumber class], &count));
        expect(count == 0, @"NSNumber has no synthesized ivars");

        NSLog(@"PASS: NSNumber value properties");
    }
    return 0;
}
