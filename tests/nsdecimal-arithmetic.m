#import <Foundation/Foundation.h>
#include <stdlib.h>

// Expected values come from Apple's Foundation overlay tests (swift-corelibs-foundation
// Darwin/Foundation-swiftoverlay-Tests/TestDecimal.swift, run against macOS) and from
// swift-foundation's DecimalTests.swift, where noted.

static int failures = 0;

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        failures++;
    }
}

static NSDecimal decimalInt(long long value)
{
    return [[NSNumber numberWithLongLong:value] decimalValue];
}

static NSDecimal decimalString(NSString *string)
{
    NSDecimal value;
    NSScanner *scanner = [NSScanner scannerWithString:string];
    if (![scanner scanDecimal:&value])
    {
        NSLog(@"FAIL: cannot scan %@", string);
        exit(1);
    }
    return value;
}

static NSString *str(NSDecimal value)
{
    return NSDecimalString(&value, nil);
}

static NSDecimal mantissa(int exponent, unsigned short m0, unsigned short m1, unsigned short m2, unsigned short m3,
                          unsigned short m4, unsigned short m5, unsigned short m6, unsigned short m7)
{
    NSDecimal value = {0};
    unsigned short digits[8] = {m0, m1, m2, m3, m4, m5, m6, m7};
    int length = 8;
    while (length > 0 && digits[length - 1] == 0)
    {
        length--;
    }
    value._exponent = exponent;
    value._length = length;
    memcpy(value._mantissa, digits, sizeof(digits));
    return value;
}

static void expectString(NSDecimal value, NSString *expected, NSString *what)
{
    NSString *actual = str(value);
    expect([actual isEqualToString:expected], [NSString stringWithFormat:@"%@: expected %@, got %@", what, expected, actual]);
}

static void expectOp(NSCalculationError (*op)(NSDecimal *, const NSDecimal *, const NSDecimal *, NSRoundingMode),
                     NSDecimal left, NSDecimal right, NSRoundingMode mode, NSCalculationError expectedError,
                     NSString *expected, NSString *what)
{
    NSDecimal result;
    NSCalculationError error = op(&result, &left, &right, mode);
    expect(error == expectedError, [NSString stringWithFormat:@"%@: error %lu, expected %lu", what, (unsigned long)error, (unsigned long)expectedError]);
    expectString(result, expected, what);
}

static void testDivision(void)
{
    NSDecimal one = decimalInt(1), two = decimalInt(2), three = decimalInt(3), zero = decimalInt(0);
    expectOp(NSDecimalDivide, one, three, NSRoundPlain, NSCalculationNoError, @"0.33333333333333333333333333333333333333", @"1/3");
    expectOp(NSDecimalDivide, two, three, NSRoundPlain, NSCalculationNoError, @"0.66666666666666666666666666666666666666", @"2/3");
    expectOp(NSDecimalDivide, decimalInt(-1), three, NSRoundPlain, NSCalculationNoError, @"-0.33333333333333333333333333333333333333", @"-1/3");
    expectOp(NSDecimalDivide, decimalInt(-6), decimalInt(-3), NSRoundPlain, NSCalculationNoError, @"2", @"-6/-3");
    expectOp(NSDecimalDivide, decimalInt(10), decimalInt(4), NSRoundPlain, NSCalculationNoError, @"2.5", @"10/4");
    expectOp(NSDecimalDivide, decimalInt(65536), decimalInt(65536), NSRoundPlain, NSCalculationNoError, @"1", @"65536/65536");
    expectOp(NSDecimalDivide, one, zero, NSRoundPlain, NSCalculationDivideByZero, @"NaN", @"1/0");
    expectOp(NSDecimalDivide, zero, three, NSRoundPlain, NSCalculationNoError, @"0", @"0/3");

    // macOS: 1010 / (16/9) = 568.12500000000000000000000000000248554.
    NSDecimal repeating;
    NSDecimal sixteen = decimalInt(16), nine = decimalInt(9), thousandTen = decimalInt(1010);
    NSDecimalDivide(&repeating, &sixteen, &nine, NSRoundPlain);
    NSDecimal result;
    NSDecimalDivide(&result, &thousandTen, &repeating, NSRoundPlain);
    NSDecimal expected = mantissa(-35, 51946, 3, 15549, 55864, 57984, 55436, 45186, 10941);
    expect(NSDecimalCompare(&expected, &result) == NSOrderedSame, [NSString stringWithFormat:@"1010/(16/9) = %@", str(result)]);
    expectString(result, @"568.12500000000000000000000000000248554", @"1010/(16/9) string");

    // macOS: 111...1 (39 ones) / 9 = 12345679012345679012345679012345679012.3.
    expectOp(NSDecimalDivide, decimalString(@"111111111111111111111111111111111111111"), nine, NSRoundPlain,
             NSCalculationNoError, @"12345679012345679012345679012345679012.3", @"39 ones / 9");

    // swift-foundation crashingDivision.
    expected = mantissa(-38, 58076, 13229, 12316, 25502, 15252, 32996, 11611, 5147);
    NSDecimal first = decimalInt(1147858867), second = decimalInt(4294967295LL);
    NSDecimalDivide(&result, &first, &second, NSRoundPlain);
    expect(NSDecimalCompare(&expected, &result) == NSOrderedSame, [NSString stringWithFormat:@"1147858867/4294967295 = %@", str(result)]);

    NSDecimal tiny = decimalString(@"1e-100"), huge = decimalString(@"1e100");
    expectOp(NSDecimalDivide, tiny, huge, NSRoundPlain, NSCalculationUnderflow, @"NaN", @"1e-100/1e100");
    expectOp(NSDecimalDivide, huge, tiny, NSRoundPlain, NSCalculationOverflow, @"NaN", @"1e100/1e-100");
}

static void testAdditionAndSubtraction(void)
{
    NSDecimal one = decimalInt(1);
    NSDecimal addend = one;
    addend._exponent = -1;
    expectOp(NSDecimalAdd, one, addend, NSRoundPlain, NSCalculationNoError, @"1.1", @"1 + 0.1");
    addend._exponent = -37;
    expectOp(NSDecimalAdd, one, addend, NSRoundPlain, NSCalculationNoError, @"1.0000000000000000000000000000000000001", @"1 + 1e-37");
    addend._exponent = -39;
    expectOp(NSDecimalAdd, one, addend, NSRoundPlain, NSCalculationLossOfPrecision, @"1", @"1 + 1e-39");

    expectOp(NSDecimalSubtract, one, decimalInt(10), NSRoundPlain, NSCalculationNoError, @"-9", @"1 - 10");
    expectOp(NSDecimalAdd, decimalInt(-5), decimalInt(5), NSRoundPlain, NSCalculationNoError, @"0", @"-5 + 5");
    expectOp(NSDecimalAdd, decimalString(@"0.1"), decimalString(@"0.2"), NSRoundPlain, NSCalculationNoError, @"0.3", @"0.1 + 0.2");

    // A sum wider than 128 bits drops its last digit, rounded with the requested mode.
    NSDecimal max = mantissa(0, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff);
    NSDecimal ten = decimalInt(10), nine = decimalInt(9);
    expectString(max, @"340282366920938463463374607431768211455", @"max mantissa");
    expectOp(NSDecimalAdd, max, ten, NSRoundPlain, NSCalculationNoError, @"340282366920938463463374607431768211470", @"max + 10 plain");
    expectOp(NSDecimalAdd, max, ten, NSRoundDown, NSCalculationNoError, @"340282366920938463463374607431768211460", @"max + 10 down");
    expectOp(NSDecimalAdd, max, ten, NSRoundBankers, NSCalculationNoError, @"340282366920938463463374607431768211460", @"max + 10 bankers");
    expectOp(NSDecimalAdd, max, nine, NSRoundPlain, NSCalculationNoError, @"340282366920938463463374607431768211460", @"max + 9 plain");
    expectOp(NSDecimalAdd, max, nine, NSRoundUp, NSCalculationNoError, @"340282366920938463463374607431768211470", @"max + 9 up");

    NSDecimal top = max;
    top._exponent = 127;
    expectOp(NSDecimalAdd, top, top, NSRoundPlain, NSCalculationOverflow, @"NaN", @"max*1e127 + max*1e127");
}

static void testMultiplication(void)
{
    NSDecimal max = mantissa(0, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff);
    NSDecimal negativeMax = max;
    negativeMax._isNegative = 1;
    NSDecimal two = decimalInt(2), three = decimalInt(3);
    expectOp(NSDecimalMultiply, max, two, NSRoundPlain, NSCalculationNoError, @"680564733841876926926749214863536422910", @"max * 2");
    expectOp(NSDecimalMultiply, two, max, NSRoundPlain, NSCalculationNoError, @"680564733841876926926749214863536422910", @"2 * max");
    expectOp(NSDecimalMultiply, max, three, NSRoundPlain, NSCalculationNoError, @"1020847100762815390390123822295304634370", @"max * 3 plain");
    expectOp(NSDecimalMultiply, max, three, NSRoundDown, NSCalculationNoError, @"1020847100762815390390123822295304634360", @"max * 3 down");
    expectOp(NSDecimalMultiply, max, three, NSRoundBankers, NSCalculationNoError, @"1020847100762815390390123822295304634360", @"max * 3 bankers");
    expectOp(NSDecimalMultiply, max, three, NSRoundUp, NSCalculationNoError, @"1020847100762815390390123822295304634370", @"max * 3 up");
    expectOp(NSDecimalMultiply, negativeMax, three, NSRoundDown, NSCalculationNoError, @"-1020847100762815390390123822295304634370", @"-max * 3 down");
    expectOp(NSDecimalMultiply, negativeMax, three, NSRoundUp, NSCalculationNoError, @"-1020847100762815390390123822295304634360", @"-max * 3 up");

    // The rounded product is 2^128, which needs one more digit dropped and rounded up again.
    NSDecimal a = decimalInt(43980465111035LL);
    NSDecimal b = mantissa(0, 1, 0, 0x800, 0, 0, 0x40, 0, 0);
    expectOp(NSDecimalMultiply, a, b, NSRoundPlain, NSCalculationNoError, @"3402823669209384634633746074317682114600", @"10 * (2^128 - 1) + 5");

    // Trailing zeros make a product with a small exponent representable.
    NSDecimal millionTiny = mantissa(-128, 16960, 15, 0, 0, 0, 0, 0, 0), product;
    NSDecimal hundredThousandth = mantissa(-5, 1, 0, 0, 0, 0, 0, 0, 0);
    NSDecimal expectedProduct = mantissa(-127, 1, 0, 0, 0, 0, 0, 0, 0);
    expect(NSDecimalMultiply(&product, &millionTiny, &hundredThousandth, NSRoundPlain) == NSCalculationNoError &&
           NSDecimalCompare(&product, &expectedProduct) == NSOrderedSame, @"1000000e-128 * 1e-5 = 1e-127");

    NSDecimal bigTwo = two;
    bigTwo._exponent = 127;
    expectOp(NSDecimalMultiply, max, bigTwo, NSRoundPlain, NSCalculationOverflow, @"NaN", @"max * 2e127");
    expectOp(NSDecimalMultiply, decimalString(@"1e-100"), decimalString(@"1e-100"), NSRoundPlain, NSCalculationUnderflow, @"NaN", @"1e-100 * 1e-100");

    expectOp(NSDecimalMultiply, decimalInt(-1), decimalInt(0), NSRoundPlain, NSCalculationNoError, @"0", @"-1 * 0");
    expectOp(NSDecimalMultiply, decimalInt(-1), decimalInt(-1), NSRoundPlain, NSCalculationNoError, @"1", @"-1 * -1");
    for (int i = -2; i <= 10; i++)
    {
        for (int j = 0; j <= 5; j++)
        {
            NSString *what = [NSString stringWithFormat:@"%d op %d", i, j];
            expectOp(NSDecimalMultiply, decimalInt(i), decimalInt(j), NSRoundPlain, NSCalculationNoError, [NSString stringWithFormat:@"%d", i * j], what);
            expectOp(NSDecimalAdd, decimalInt(i), decimalInt(j), NSRoundPlain, NSCalculationNoError, [NSString stringWithFormat:@"%d", i + j], what);
            expectOp(NSDecimalSubtract, decimalInt(i), decimalInt(j), NSRoundPlain, NSCalculationNoError, [NSString stringWithFormat:@"%d", i - j], what);
        }
    }
}

static void testNaNInputs(void)
{
    NSDecimal nan = {0};
    nan._isNegative = 1;
    NSDecimal one = decimalInt(1);
    NSDecimal result;
    expect(NSDecimalAdd(&result, &nan, &one, NSRoundPlain) == NSCalculationOverflow && NSDecimalIsNotANumber(&result), @"NaN + 1");
    expect(NSDecimalSubtract(&result, &one, &nan, NSRoundPlain) == NSCalculationOverflow && NSDecimalIsNotANumber(&result), @"1 - NaN");
    expect(NSDecimalMultiply(&result, &nan, &one, NSRoundPlain) == NSCalculationOverflow && NSDecimalIsNotANumber(&result), @"NaN * 1");
    expect(NSDecimalDivide(&result, &one, &nan, NSRoundPlain) == NSCalculationOverflow && NSDecimalIsNotANumber(&result), @"1 / NaN");
    expect(NSDecimalPower(&result, &nan, 0, NSRoundPlain) == NSCalculationOverflow && NSDecimalIsNotANumber(&result), @"NaN ^ 0");
    expect(NSDecimalMultiplyByPowerOf10(&result, &nan, 4, NSRoundPlain) == NSCalculationOverflow && NSDecimalIsNotANumber(&result), @"NaN e4");
    expect(NSDecimalCompare(&nan, &one) == NSOrderedAscending, @"NaN < 1");
    expect(NSDecimalCompare(&nan, &nan) == NSOrderedSame, @"NaN == NaN");
}

static void testPowersAndCompare(void)
{
    NSDecimal a = decimalInt(1234), result;
    expect(NSDecimalMultiplyByPowerOf10(&result, &a, 1, NSRoundPlain) == NSCalculationNoError, @"1234e1 error");
    expectString(result, @"12340", @"1234e1");
    NSDecimalMultiplyByPowerOf10(&result, &a, -2, NSRoundPlain);
    expectString(result, @"12.34", @"1234e-2");
    expect(NSDecimalMultiplyByPowerOf10(&result, &a, 128, NSRoundPlain) == NSCalculationOverflow && NSDecimalIsNotANumber(&result), @"1234e128");
    NSDecimal small = decimalString(@"12.34");
    expect(NSDecimalMultiplyByPowerOf10(&result, &small, -128, NSRoundPlain) == NSCalculationUnderflow && NSDecimalIsNotANumber(&result), @"12.34e-128");

    NSDecimal eight = decimalInt(8), minusTwo = decimalInt(-2);
    expect(NSDecimalPower(&result, &a, 0, NSRoundPlain) == NSCalculationNoError, @"1234^0 error");
    expectString(result, @"1", @"1234^0");
    NSDecimalPower(&result, &eight, 2, NSRoundPlain);
    expectString(result, @"64", @"8^2");
    NSDecimalPower(&result, &minusTwo, 3, NSRoundPlain);
    expectString(result, @"-8", @"-2^3");
    NSDecimal two = decimalInt(2);
    NSDecimalPower(&result, &two, 127, NSRoundPlain);
    expectString(result, @"170141183460469231731687303715884105728", @"2^127");

    NSDecimal ten = decimalInt(10), eleven = decimalInt(11), oneHalf = decimalString(@"1.5"), oneQuarter = decimalString(@"1.25");
    expect(NSDecimalCompare(&ten, &eleven) == NSOrderedAscending, @"10 < 11");
    expect(NSDecimalCompare(&oneHalf, &oneQuarter) == NSOrderedDescending, @"1.5 > 1.25");
    NSDecimal minusTen = decimalInt(-10), minusEleven = decimalInt(-11);
    expect(NSDecimalCompare(&minusTen, &minusEleven) == NSOrderedDescending, @"-10 > -11");
    NSDecimal tenScaled = mantissa(-1, 100, 0, 0, 0, 0, 0, 0, 0);
    expect(NSDecimalCompare(&ten, &tenScaled) == NSOrderedSame, @"10 == 100e-1");
}

static void testRound(void)
{
    struct { NSString *expected; NSString *start; NSInteger scale; NSRoundingMode mode; } cases[] = {
        {@"0", @"0.5", 0, NSRoundDown}, {@"1", @"0.5", 0, NSRoundUp},
        {@"2", @"2.5", 0, NSRoundBankers}, {@"4", @"3.5", 0, NSRoundBankers},
        {@"5", @"5.2", 0, NSRoundPlain}, {@"4.5", @"4.5", 1, NSRoundDown},
        {@"5.5", @"5.5", 1, NSRoundUp}, {@"6.5", @"6.5", 1, NSRoundPlain},
        {@"7.5", @"7.5", 1, NSRoundBankers}, {@"-1", @"-0.5", 0, NSRoundDown},
        {@"-2", @"-2.5", 0, NSRoundUp}, {@"-5", @"-5.2", 0, NSRoundPlain},
        {@"-4.5", @"-4.5", 1, NSRoundDown}, {@"-5.5", @"-5.5", 1, NSRoundUp},
        {@"-6.5", @"-6.5", 1, NSRoundPlain}, {@"-7.5", @"-7.5", 1, NSRoundBankers},
        {@"-2", @"-2.5", 0, NSRoundBankers}, {@"-4", @"-3.5", 0, NSRoundBankers},
        {@"0", @"-0.4", 0, NSRoundPlain}, {@"1.23457", @"1.234565", 5, NSRoundPlain},
        {@"1.23456", @"1.234565", 5, NSRoundBankers}, {@"1.23457", @"1.2345651", 5, NSRoundBankers},
        {@"1200", @"1234", -2, NSRoundPlain}, {@"1300", @"1234", -2, NSRoundUp},
    };
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++)
    {
        NSDecimal start = decimalString(cases[i].start), result;
        NSDecimalRound(&result, &start, cases[i].scale, cases[i].mode);
        expectString(result, cases[i].expected, [NSString stringWithFormat:@"round %@ scale %ld mode %lu", cases[i].start, (long)cases[i].scale, (unsigned long)cases[i].mode]);
    }
    NSDecimal start = decimalInt(1234), result;
    NSDecimalRound(&result, &start, NSIntegerMin + 1, NSRoundPlain);
    expectString(result, @"0", @"round 1234 to a huge negative scale");

    NSDecimal third, one = decimalInt(1), three = decimalInt(3);
    NSDecimalDivide(&third, &one, &three, NSRoundPlain);
    NSDecimal rounded;
    NSDecimalRound(&rounded, &third, 2, NSRoundPlain);
    expectString(rounded, @"0.33", @"round 1/3 to 2 places");
    NSDecimalRound(&rounded, &third, NSDecimalNoScale, NSRoundPlain);
    expect(NSDecimalCompare(&rounded, &third) == NSOrderedSame, @"NoScale leaves the value unchanged");
}

static void testNormalizeCompactAndString(void)
{
    NSDecimal one = decimalInt(1), minusTen = decimalInt(-10);
    expect(NSDecimalNormalize(&one, &minusTen, NSRoundPlain) == NSCalculationNoError, @"normalize 1, -10");
    expect(one._length == 1 && minusTen._length == 1, @"normalize 1, -10 lengths");
    expectString(minusTen, @"-10", @"normalize keeps -10");

    // swift-foundation DecimalTests.normalize.
    NSDecimal a = decimalString(@"498.7509045"), b = decimalString(@"8.453441368210501065891847765109162027");
    expect(NSDecimalNormalize(&a, &b, NSRoundPlain) == NSCalculationLossOfPrecision, @"normalize with loss of precision");
    NSDecimal expectedA = mantissa(-31, 0, 21760, 45355, 11455, 62709, 14050, 62951, 0);
    NSDecimal expectedB = mantissa(-31, 56467, 17616, 59987, 21635, 5988, 63852, 1066, 0);
    expect(a._exponent == -31 && memcmp(a._mantissa, expectedA._mantissa, sizeof(a._mantissa)) == 0, [NSString stringWithFormat:@"normalized a %@", str(a)]);
    expect(b._exponent == -31 && b._length == 7 && memcmp(b._mantissa, expectedB._mantissa, sizeof(b._mantissa)) == 0, [NSString stringWithFormat:@"normalized b %@", str(b)]);

    NSDecimal f = mantissa(0, 0, 1, 0, 0, 0, 0, 0, 0);
    NSString *before = str(f);
    NSDecimalCompact(&f);
    expect(f._isCompact == 1 && [str(f) isEqualToString:before] && [before isEqualToString:@"65536"], @"compact 65536");
    NSDecimal hundred = mantissa(0, 100, 0, 0, 0, 0, 0, 0, 0);
    NSDecimalCompact(&hundred);
    expect(hundred._exponent == 2 && hundred._mantissa[0] == 1 && hundred._length == 1, @"compact 100 to 1e2");

    NSDecimal pi = mantissa(-38, 0x6623, 0x7d57, 0x16e7, 0xad0d, 0xaf52, 0x4641, 0xdfa7, 0xec58);
    expectString(pi, @"3.14159265358979323846264338327950288419", @"pi");
    expectString(mantissa(-3, 57922, 1, 0, 0, 0, 0, 0, 0), @"123.458", @"123.458");
    expectString(mantissa(-5, 123, 0, 0, 0, 0, 0, 0, 0), @"0.00123", @"0.00123");
    expectString(mantissa(1, 1, 0, 0, 0, 0, 0, 0, 0), @"10", @"1e1");
    NSDecimal comma = mantissa(-1, 15, 0, 0, 0, 0, 0, 0, 0);
    NSString *commaString = NSDecimalString(&comma, @{NSLocaleDecimalSeparator: @","});
    expect([commaString isEqualToString:@"1,5"], [NSString stringWithFormat:@"locale separator: %@", commaString]);
}

int main(void)
{
    @autoreleasepool
    {
        testDivision();
        testAdditionAndSubtraction();
        testMultiplication();
        testNaNInputs();
        testPowersAndCompare();
        testRound();
        testNormalizeCompactAndString();
        if (failures != 0)
        {
            NSLog(@"FAIL: %d NSDecimal checks failed", failures);
            return 1;
        }
        NSLog(@"PASS: NSDecimal arithmetic");
    }
    return 0;
}
