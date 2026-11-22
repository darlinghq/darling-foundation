// Copyright (C) 2026 Darling Team
//
// Guest test: NSScriptWhoseTest, NSLogicalTest and NSSpecifierTest. The expected values come from the
// public documentation for these classes (developer.apple.com, Foundation), not from observation of
// macOS. The empty and nil list results (AND is true, OR is false), the exception for a nil NOT
// subtest and the unimplemented NSSpecifierTest result (always NO, it logs that it is a stub) are the implementation's own choices, not
// documented behavior.
#import <Foundation/Foundation.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

// A test whose result is fixed, to feed the logical combinations.
@interface FixedTest : NSScriptWhoseTest
{
    BOOL _value;
}
- (instancetype)initWithValue:(BOOL)value;
@end

@implementation FixedTest
- (instancetype)initWithValue:(BOOL)value
{
    if ((self = [super init]))
        _value = value;
    return self;
}
- (BOOL)isTrue
{
    return _value;
}
@end

static NSScriptWhoseTest *constant(BOOL value)
{
    return [[FixedTest alloc] initWithValue:value];
}

static BOOL andOf(NSArray *tests)
{
    return [[[NSLogicalTest alloc] initAndTestWithTests:tests] isTrue];
}

static BOOL orOf(NSArray *tests)
{
    return [[[NSLogicalTest alloc] initOrTestWithTests:tests] isTrue];
}

static BOOL notOf(NSScriptWhoseTest *test)
{
    return [[[NSLogicalTest alloc] initNotTestWithTest:test] isTrue];
}

int main(void)
{
    @autoreleasepool {
        NSScriptWhoseTest *T = constant(YES);
        NSScriptWhoseTest *F = constant(NO);

        report("NSScriptWhoseTest superclass is NSObject", [NSScriptWhoseTest superclass] == [NSObject class]);
        report("NSLogicalTest superclass is NSScriptWhoseTest", [NSLogicalTest superclass] == [NSScriptWhoseTest class]);
        report("NSSpecifierTest superclass is NSScriptWhoseTest", [NSSpecifierTest superclass] == [NSScriptWhoseTest class]);

        report("base isTrue is NO", ![[[NSScriptWhoseTest alloc] init] isTrue]);

        report("and: T T", andOf(@[T, T]));
        report("and: T F", !andOf(@[T, F]));
        report("and: F T", !andOf(@[F, T]));
        report("and: F F", !andOf(@[F, F]));
        report("and: single true", andOf(@[T]));
        report("and: single false", !andOf(@[F]));
        report("and: three with one false", !andOf(@[T, T, F]));

        report("or: T T", orOf(@[T, T]));
        report("or: T F", orOf(@[T, F]));
        report("or: F T", orOf(@[F, T]));
        report("or: F F", !orOf(@[F, F]));
        report("or: single true", orOf(@[T]));
        report("or: single false", !orOf(@[F]));
        report("or: three with one true", orOf(@[F, F, T]));

        report("not: true", !notOf(T));
        report("not: false", notOf(F));

        // Implementation choices, not documented.
        report("empty and is true", andOf(@[]));
        report("empty or is false", !orOf(@[]));
        report("nil and behaves like empty", andOf(nil));
        report("nil or behaves like empty", !orOf(nil));

        BOOL raised = NO;
        @try {
            [[NSLogicalTest alloc] initNotTestWithTest:nil];
        } @catch (NSException *e) {
            raised = [[e name] isEqualToString:NSInvalidArgumentException];
        }
        report("not with a nil test raises NSInvalidArgumentException", raised);

        // Plain NSArray locals: the header types the elements as NSSpecifierTest, but any test is accepted.
        NSArray *innerAnd = @[T, F];
        NSArray *nestedTests = @[[[NSLogicalTest alloc] initAndTestWithTests:innerAnd], [[NSLogicalTest alloc] initNotTestWithTest:F]];
        NSScriptWhoseTest *nested = [[NSLogicalTest alloc] initOrTestWithTests:nestedTests];
        report("nested or(and(T, F), not(F))", [nested isTrue]);

        NSMutableArray *mutableTests = [NSMutableArray arrayWithObject:T];
        NSLogicalTest *copied = [[NSLogicalTest alloc] initAndTestWithTests:mutableTests];
        [mutableTests addObject:F];
        report("later changes to the passed array do not affect the test", [copied isTrue]);

        report("logical tests are NSScriptWhoseTest instances", [nested isKindOfClass:[NSScriptWhoseTest class]]);

        // The numeric values are a GUESS, so only distinctness is checked.
        NSTestComparisonOperation ops[] = { NSEqualToComparison, NSLessThanOrEqualToComparison, NSLessThanComparison,
            NSGreaterThanOrEqualToComparison, NSGreaterThanComparison, NSBeginsWithComparison,
            NSEndsWithComparison, NSContainsComparison };
        BOOL distinct = YES;
        for (int i = 0; i < 8; i++)
            for (int j = i + 1; j < 8; j++)
                if (ops[i] == ops[j])
                    distinct = NO;
        report("the 8 comparison constants are pairwise distinct", distinct);

        NSSpecifierTest *specifier = [[NSSpecifierTest alloc] initWithObjectSpecifier:nil
                                                                   comparisonOperator:NSEqualToComparison
                                                                           testObject:@"x"];
        report("NSSpecifierTest constructs", specifier != nil);
        // Placeholder pins: the comparison is not implemented, so isTrue is NO until it is.
        report("NSSpecifierTest isTrue is NO (placeholder pin)", ![specifier isTrue]);
        report("NSSpecifierTest in an and is NO (placeholder pin)", !andOf(@[T, specifier]));
        report("NSSpecifierTest in an or with true is YES", orOf(@[specifier, T]));
    }
    printf("%s\n", failures ? "FAILED" : "PASSED");
    return failures != 0;
}
