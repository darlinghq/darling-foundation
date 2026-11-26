// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: the NSComparisonMethods category of NSObject
// (https://developer.apple.com/documentation/objectivec/nsobject/nscomparisonmethods).
// The equality tests go through -isEqual: and the ordering tests through
// -compare:; -doesContain: asks an array whether it has the object. Expected
// values were observed on macOS 26.7.3 (x86_64) with the same inputs.
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
        NSNumber *one = @1, *two = @2;
        NSString *a = @"a", *b = @"b";

        report("isEqualTo: equal numbers", [one isEqualTo:@1]);
        report("isEqualTo: different numbers", ![one isEqualTo:two]);
        report("isEqualTo: equal strings, different objects",
               [a isEqualTo:[NSMutableString stringWithString:@"a"]]);
        report("isNotEqualTo:", [a isNotEqualTo:b] && ![a isNotEqualTo:@"a"]);

        report("isLessThan:", [one isLessThan:two] && ![two isLessThan:one] && ![one isLessThan:@1]);
        report("isLessThanOrEqualTo:", [one isLessThanOrEqualTo:two] && [one isLessThanOrEqualTo:@1]
               && ![two isLessThanOrEqualTo:one]);
        report("isGreaterThan:", [b isGreaterThan:a] && ![a isGreaterThan:b] && ![a isGreaterThan:@"a"]);
        report("isGreaterThanOrEqualTo:", [b isGreaterThanOrEqualTo:a] && [b isGreaterThanOrEqualTo:@"b"]
               && ![a isGreaterThanOrEqualTo:b]);

        NSArray *array = @[ one, a ];
        report("doesContain: an element", [array doesContain:@"a"] && [array doesContain:@1]);
        report("doesContain: not an element", ![array doesContain:two]);
    }
    return failures != 0;
}
