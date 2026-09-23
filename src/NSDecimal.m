//
//  NSDecimal.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//
//  The arithmetic below is a C port of swift-foundation's
//  Sources/FoundationEssentials/Decimal/Decimal+Math.swift and Decimal.swift
//  (tag swift-6.3.3-RELEASE), which implement NSDecimal on macOS:
//
//  This source file is part of the Swift.org open source project
//
//  Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
//  Licensed under Apache License v2.0 with Runtime Library Exception
//
//  See https://swift.org/LICENSE.txt for license information
//  See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//

#import <Foundation/NSDecimal.h>

#import <Foundation/NSDictionary.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSString.h>

#import <math.h>
#import <stdlib.h>
#import <string.h>

#define DECIMAL_MAX_EXPONENT 127
#define DECIMAL_MIN_EXPONENT (-128)

// Long division needs 17 digits: a 16-digit dividend plus one for normalization.
#define VLI_CAPACITY 17

// Unsigned integer as little-endian base-65536 digits without leading zero
// digits; zero has count 0.
typedef struct {
    int count;
    unsigned short digits[VLI_CAPACITY];
} VLI;

static const VLI powersOfTen[39] = {
    {1, {0x0001}},
    {1, {0x000a}},
    {1, {0x0064}},
    {1, {0x03e8}},
    {1, {0x2710}},
    {2, {0x86a0, 0x0001}},
    {2, {0x4240, 0x000f}},
    {2, {0x9680, 0x0098}},
    {2, {0xe100, 0x05f5}},
    {2, {0xca00, 0x3b9a}},
    {3, {0xe400, 0x540b, 0x0002}},
    {3, {0xe800, 0x4876, 0x0017}},
    {3, {0x1000, 0xd4a5, 0x00e8}},
    {3, {0xa000, 0x4e72, 0x0918}},
    {3, {0x4000, 0x107a, 0x5af3}},
    {4, {0x8000, 0xa4c6, 0x8d7e, 0x0003}},
    {4, {0x0000, 0x6fc1, 0x86f2, 0x0023}},
    {4, {0x0000, 0x5d8a, 0x4578, 0x0163}},
    {4, {0x0000, 0xa764, 0xb6b3, 0x0de0}},
    {4, {0x0000, 0x89e8, 0x2304, 0x8ac7}},
    {5, {0x0000, 0x6310, 0x5e2d, 0x6bc7, 0x0005}},
    {5, {0x0000, 0xdea0, 0xadc5, 0x35c9, 0x0036}},
    {5, {0x0000, 0xb240, 0xc9ba, 0x19e0, 0x021e}},
    {5, {0x0000, 0xf680, 0xe14a, 0x02c7, 0x152d}},
    {5, {0x0000, 0xa100, 0xcced, 0x1bce, 0xd3c2}},
    {6, {0x0000, 0x4a00, 0x0148, 0x1614, 0x4595, 0x0008}},
    {6, {0x0000, 0xe400, 0x0cd2, 0xdcc8, 0xb7d2, 0x0052}},
    {6, {0x0000, 0xe800, 0x803c, 0x9fd0, 0x2e3c, 0x033b}},
    {6, {0x0000, 0x1000, 0x0261, 0x3e25, 0xce5e, 0x204f}},
    {7, {0x0000, 0xa000, 0x17ca, 0x6d72, 0x0fae, 0x431e, 0x0001}},
    {7, {0x0000, 0x4000, 0xedea, 0x4674, 0x9cd0, 0x9f2c, 0x000c}},
    {7, {0x0000, 0x8000, 0x4b26, 0xc091, 0x2022, 0x37be, 0x007e}},
    {7, {0x0000, 0x0000, 0xef81, 0x85ac, 0x415b, 0x2d6d, 0x04ee}},
    {7, {0x0000, 0x0000, 0x5b0a, 0x38c1, 0x8d93, 0xc644, 0x314d}},
    {8, {0x0000, 0x0000, 0x8e64, 0x378d, 0x87c0, 0xbead, 0xed09, 0x0001}},
    {8, {0x0000, 0x0000, 0x8fe8, 0x2b87, 0x4d82, 0x72c7, 0x4261, 0x0013}},
    {8, {0x0000, 0x0000, 0x9f10, 0xb34b, 0x0715, 0x7bc9, 0x97ce, 0x00c0}},
    {8, {0x0000, 0x0000, 0x36a0, 0x00f4, 0x46d9, 0xd5da, 0xee10, 0x0785}},
    {8, {0x0000, 0x0000, 0x2240, 0x098a, 0xc47a, 0x5a86, 0x4ca8, 0x4b3b}},
};

static const int maxPowerOfTen = 38;

#pragma mark - Variable length integers

static void VLITrim(VLI *value)
{
    while (value->count > 0 && value->digits[value->count - 1] == 0)
    {
        value->count--;
    }
}

static NSComparisonResult VLICompare(const VLI *lhs, const VLI *rhs)
{
    if (lhs->count != rhs->count)
    {
        return lhs->count > rhs->count ? NSOrderedDescending : NSOrderedAscending;
    }
    for (int i = lhs->count - 1; i >= 0; i--)
    {
        if (lhs->digits[i] != rhs->digits[i])
        {
            return lhs->digits[i] > rhs->digits[i] ? NSOrderedDescending : NSOrderedAscending;
        }
    }
    return NSOrderedSame;
}

static NSCalculationError VLIAdd(VLI *result, const VLI *lhs, const VLI *rhs, int maxResultLength)
{
    VLI sum = {0};
    int minLength = MIN(lhs->count, rhs->count);
    int i = 0;
    unsigned int carry = 0;
    for (; i < minLength; i++)
    {
        unsigned int acc = (unsigned int)lhs->digits[i] + rhs->digits[i] + carry;
        carry = acc >> 16;
        sum.digits[i] = acc & 0xffff;
    }
    const VLI *longer = lhs->count > rhs->count ? lhs : rhs;
    for (; i < longer->count; i++)
    {
        unsigned int acc = (unsigned int)longer->digits[i] + carry;
        carry = acc >> 16;
        sum.digits[i] = acc & 0xffff;
    }
    if (carry != 0)
    {
        if (i >= maxResultLength)
        {
            return NSCalculationOverflow;
        }
        sum.digits[i++] = carry;
    }
    sum.count = i;
    *result = sum;
    return NSCalculationNoError;
}

static NSCalculationError VLIAddShort(VLI *result, const VLI *lhs, unsigned int amount, int maxResultLength)
{
    VLI sum = *lhs;
    unsigned int carry = amount;
    for (int i = 0; i < sum.count; i++)
    {
        unsigned int acc = (unsigned int)sum.digits[i] + carry;
        carry = acc >> 16;
        sum.digits[i] = acc & 0xffff;
    }
    if (carry != 0)
    {
        if (sum.count >= maxResultLength)
        {
            return NSCalculationOverflow;
        }
        sum.digits[sum.count++] = carry;
    }
    *result = sum;
    return NSCalculationNoError;
}

// term - subtrahend; overflow if the result would be negative.
static NSCalculationError VLISubtract(VLI *result, const VLI *term, const VLI *subtrahend)
{
    VLI difference = {0};
    unsigned int carry = 1;
    int i = 0;
    int sharedLength = MIN(term->count, subtrahend->count);
    for (; i < sharedLength; i++)
    {
        unsigned int acc = 0xffff + (unsigned int)term->digits[i] - subtrahend->digits[i] + carry;
        carry = acc >> 16;
        difference.digits[i] = acc & 0xffff;
    }
    for (; i < term->count; i++)
    {
        unsigned int acc = 0xffff + (unsigned int)term->digits[i] + carry;
        carry = acc >> 16;
        difference.digits[i] = acc & 0xffff;
    }
    for (; i < subtrahend->count; i++)
    {
        unsigned int acc = 0xffff - (unsigned int)subtrahend->digits[i] + carry;
        carry = acc >> 16;
        difference.digits[i] = acc & 0xffff;
    }
    if (carry == 0)
    {
        return NSCalculationOverflow;
    }
    difference.count = i;
    VLITrim(&difference);
    *result = difference;
    return NSCalculationNoError;
}

static NSCalculationError VLIDivideByShort(VLI *quotient, unsigned int *remainder, const VLI *dividend, unsigned int divisor)
{
    if (divisor == 0)
    {
        return NSCalculationDivideByZero;
    }
    VLI result = {0};
    unsigned int carry = 0;
    for (int i = dividend->count - 1; i >= 0; i--)
    {
        unsigned int acc = (unsigned int)dividend->digits[i] + (carry << 16);
        result.digits[i] = acc / divisor;
        carry = acc % divisor;
    }
    result.count = dividend->count;
    VLITrim(&result);
    *quotient = result;
    if (remainder != NULL)
    {
        *remainder = carry;
    }
    return NSCalculationNoError;
}

static NSCalculationError VLIMultiplyByShort(VLI *result, const VLI *lhs, unsigned int multiplicand, int maxResultLength)
{
    if (multiplicand == 0)
    {
        result->count = 0;
        return NSCalculationNoError;
    }
    if (maxResultLength < lhs->count)
    {
        return NSCalculationOverflow;
    }
    VLI product = *lhs;
    unsigned int carry = 0;
    for (int i = 0; i < product.count; i++)
    {
        unsigned int acc = (unsigned int)product.digits[i] * multiplicand + carry;
        carry = acc >> 16;
        product.digits[i] = acc & 0xffff;
    }
    if (carry != 0)
    {
        if (product.count >= maxResultLength)
        {
            return NSCalculationOverflow;
        }
        product.digits[product.count++] = carry;
    }
    *result = product;
    return NSCalculationNoError;
}

static NSCalculationError VLIMultiply(VLI *result, const VLI *lhs, const VLI *rhs, int maxResultLength)
{
    VLI product = {0};
    if (lhs->count == 0 || rhs->count == 0)
    {
        *result = product;
        return NSCalculationNoError;
    }
    int resultLength = MIN(maxResultLength, lhs->count + rhs->count);
    for (int j = 0; j < rhs->count; j++)
    {
        unsigned int carry = 0;
        for (int i = 0; i < lhs->count; i++)
        {
            if (i + j < resultLength)
            {
                unsigned int acc = carry + product.digits[i + j] + (unsigned int)rhs->digits[j] * lhs->digits[i];
                carry = acc >> 16;
                product.digits[i + j] = acc & 0xffff;
            }
            else if (carry != 0 || (rhs->digits[j] > 0 && lhs->digits[i] > 0))
            {
                return NSCalculationOverflow;
            }
        }
        if (carry != 0)
        {
            if (lhs->count + j >= resultLength)
            {
                return NSCalculationOverflow;
            }
            product.digits[lhs->count + j] = carry;
        }
    }
    product.count = resultLength;
    VLITrim(&product);
    *result = product;
    return NSCalculationNoError;
}

// Long division, Knuth TAOCP vol. 2, 4.3.1 algorithm D.
static NSCalculationError VLIDivide(VLI *result, const VLI *dividend, const VLI *divisor)
{
    if (divisor->count == 0)
    {
        return NSCalculationDivideByZero;
    }
    if (VLICompare(dividend, divisor) == NSOrderedAscending)
    {
        result->count = 0;
        return NSCalculationNoError;
    }
    if (divisor->count == 1)
    {
        return VLIDivideByShort(result, NULL, dividend, divisor->digits[0]);
    }

    // D1: normalize so that the divisor's top digit is at least 0x8000.
    unsigned int d = 0x10000 / ((unsigned int)divisor->digits[divisor->count - 1] + 1);
    VLI u, v;
    NSCalculationError error = VLIMultiplyByShort(&u, dividend, d, dividend->count + 1);
    if (error == NSCalculationNoError)
    {
        error = VLIMultiplyByShort(&v, divisor, d, divisor->count + 1);
    }
    if (error != NSCalculationNoError)
    {
        return error;
    }
    if (u.count == dividend->count)
    {
        u.digits[u.count++] = 0;
    }
    int ul = u.count;
    int vl = v.count;
    v.digits[vl] = 0;
    int quotientLength = ul - vl;
    unsigned int v1 = v.digits[vl - 1];
    unsigned int v2 = v.digits[vl - 2];

    VLI quotient = {0};
    for (int j = 0; j < quotientLength; j++)
    {
        // D3: estimate the quotient digit; it is at most one too large after the checks.
        unsigned int tmp = ((unsigned int)u.digits[ul - j - 1] << 16) + u.digits[ul - j - 2];
        unsigned int q = tmp / v1;
        unsigned int r = tmp % v1;
        if (q == 0x10000 || v2 * q > (r << 16) + u.digits[ul - j - 3])
        {
            q--;
            r += v1;
            if (r < 0x10000 && (q == 0x10000 || v2 * q > (r << 16) + u.digits[ul - j - 3]))
            {
                q--;
            }
        }

        // D4: multiply and subtract.
        unsigned int multiplyCarry = 0;
        unsigned int subtractCarry = 1;
        for (int i = 0; i <= vl; i++)
        {
            unsigned int acc = q * v.digits[i] + multiplyCarry;
            multiplyCarry = acc >> 16;
            acc &= 0xffff;
            acc = 0xffff + (unsigned int)u.digits[ul - vl + i - j - 1] - acc + subtractCarry;
            subtractCarry = acc >> 16;
            u.digits[ul - vl + i - j - 1] = acc & 0xffff;
        }

        // D5/D6: the estimate was one too large; add the divisor back.
        if (subtractCarry == 0)
        {
            q--;
            unsigned int addCarry = 0;
            for (int i = 0; i < vl; i++)
            {
                unsigned int acc = (unsigned int)v.digits[i] + u.digits[ul - vl + i - j - 1] + addCarry;
                addCarry = acc >> 16;
                u.digits[ul - vl + i - j - 1] = acc & 0xffff;
            }
        }
        quotient.digits[quotientLength - j - 1] = q;
    }
    quotient.count = quotientLength;
    VLITrim(&quotient);
    *result = quotient;
    return NSCalculationNoError;
}

static NSCalculationError VLIMultiplyByPowerOfTen(VLI *result, const VLI *lhs, int power, int maxResultLength)
{
    VLI value = *lhs;
    BOOL isNegative = power < 0;
    int remaining = abs(power);
    NSCalculationError error = NSCalculationNoError;
    while (error == NSCalculationNoError && remaining > 0)
    {
        int step = MIN(remaining, maxPowerOfTen);
        remaining -= step;
        if (isNegative)
        {
            error = VLIDivide(&value, &value, &powersOfTen[step]);
        }
        else
        {
            error = VLIMultiply(&value, &value, &powersOfTen[step], maxResultLength);
        }
    }
    if (error == NSCalculationNoError)
    {
        *result = value;
    }
    return error;
}

// The largest power of ten that surely fits in the spare digits: log10(2^16) ~= 4.81647993.
static int VLIMaxPowerOfTenMultiplier(const VLI *number, int maxResultLength)
{
    return (int)floor((double)(maxResultLength - number->count) * 4.81647993);
}

// Whether dropping digits rounds the magnitude up. remainder is the last digit dropped and sticky
// says an earlier one was nonzero, so .50001 rounds like .6. NSRoundDown and NSRoundUp go toward
// -infinity and +infinity.
static BOOL NSDecimalRoundsUp(unsigned int remainder, BOOL sticky, NSRoundingMode roundingMode, BOOL isNegative, BOOL isOdd)
{
    if (sticky && (remainder == 0 || remainder == 5))
    {
        remainder++;
    }
    if (remainder == 0)
    {
        return NO;
    }
    switch (roundingMode)
    {
        case NSRoundDown:
            return isNegative;
        case NSRoundUp:
            return !isNegative;
        case NSRoundBankers:
            return remainder > 5 || (remainder == 5 && isOdd);
        case NSRoundPlain:
        default:
            return remainder >= 5;
    }
}

// Divides by powers of ten until the value fits in the NSDecimal mantissa, rounding the dropped
// digits like NSDecimalRound (swift-foundation 6.3.3 computes but discards this rounding).
static void VLIFitMantissa(VLI *value, int *exponent, NSRoundingMode roundingMode, BOOL isNegative)
{
    *exponent = 0;
    if (value->count <= NSDecimalMaxSize)
    {
        return;
    }
    unsigned int remainder = 0;
    BOOL sticky = NO;
    while (value->count > NSDecimalMaxSize + 1)
    {
        sticky = sticky || remainder != 0;
        VLIDivideByShort(value, &remainder, value, 10000);
        *exponent += 4;
    }
    while (value->count > NSDecimalMaxSize)
    {
        sticky = sticky || remainder != 0;
        VLIDivideByShort(value, &remainder, value, 10);
        *exponent += 1;
    }
    if (NSDecimalRoundsUp(remainder, sticky, roundingMode, isNegative, value->digits[0] & 1))
    {
        VLIAddShort(value, value, 1, NSDecimalMaxSize + 1);
        if (value->count > NSDecimalMaxSize)
        {
            // Only 2^128 overflows; it ends in 6, which rounds up in the same direction again.
            VLIDivideByShort(value, NULL, value, 10);
            VLIAddShort(value, value, 1, NSDecimalMaxSize);
            *exponent += 1;
        }
    }
}

#pragma mark - NSDecimal helpers

static const NSDecimal zeroDecimal = {0};

static inline BOOL NSDecimalIsNaN(const NSDecimal *number)
{
    return number->_length == 0 && number->_isNegative != 0;
}

static inline NSDecimal NSDecimalNaN(void)
{
    NSDecimal nan = {0};
    nan._isNegative = 1;
    return nan;
}

static VLI NSDecimalMantissa(const NSDecimal *number)
{
    VLI value = {0};
    value.count = MIN((int)number->_length, NSDecimalMaxSize);
    memcpy(value.digits, number->_mantissa, value.count * sizeof(unsigned short));
    VLITrim(&value);
    return value;
}

static NSCalculationError NSDecimalSetMantissa(NSDecimal *number, const VLI *value)
{
    if (value->count > NSDecimalMaxSize)
    {
        return NSCalculationOverflow;
    }
    memset(number->_mantissa, 0, sizeof(number->_mantissa));
    memcpy(number->_mantissa, value->digits, value->count * sizeof(unsigned short));
    number->_length = value->count;
    return NSCalculationNoError;
}

static void NSDecimalDivideByShort(NSDecimal *number, unsigned int divisor, unsigned int *remainder)
{
    VLI value = NSDecimalMantissa(number);
    VLIDivideByShort(&value, remainder, &value, divisor);
    NSDecimalSetMantissa(number, &value);
}

static NSCalculationError NSDecimalMultiplyByShort(NSDecimal *number, unsigned int multiplicand)
{
    VLI value = NSDecimalMantissa(number);
    NSCalculationError error = VLIMultiplyByShort(&value, &value, multiplicand, NSDecimalMaxSize);
    if (error == NSCalculationNoError)
    {
        NSDecimalSetMantissa(number, &value);
    }
    return error;
}

static NSCalculationError NSDecimalAddShort(NSDecimal *number, unsigned int amount)
{
    VLI value = NSDecimalMantissa(number);
    NSCalculationError error = VLIAddShort(&value, &value, amount, NSDecimalMaxSize);
    if (error == NSCalculationNoError)
    {
        NSDecimalSetMantissa(number, &value);
    }
    return error;
}

static void NSDecimalCompactInPlace(NSDecimal *number)
{
    if (number->_isCompact || NSDecimalIsNaN(number) || number->_length == 0)
    {
        return;
    }
    int exponent = number->_exponent;
    unsigned int remainder = 0;
    do
    {
        NSDecimalDivideByShort(number, 10, &remainder);
        exponent++;
    } while (remainder == 0 && number->_length > 0);
    if (number->_length == 0 && remainder == 0)
    {
        *number = zeroDecimal;
        return;
    }

    // Put the last, nonzero, digit back.
    NSDecimalMultiplyByShort(number, 10);
    NSDecimalAddShort(number, remainder);
    exponent--;
    while (exponent > DECIMAL_MAX_EXPONENT)
    {
        NSDecimalMultiplyByShort(number, 10);
        exponent--;
    }
    number->_exponent = exponent;
    number->_isCompact = 1;
}

// Brings both operands to the same exponent, reporting whether digits were dropped.
static NSCalculationError NSDecimalNormalizeInPlace(NSDecimal *a, NSDecimal *b, BOOL *lossOfPrecision)
{
    *lossOfPrecision = NO;
    int diffExponent = a->_exponent - b->_exponent;
    if (diffExponent == 0)
    {
        return NSCalculationNoError;
    }

    // aa has the larger exponent: scale its mantissa up to reach bb's exponent.
    NSDecimal *aa = a;
    NSDecimal *bb = b;
    if (diffExponent < 0)
    {
        aa = b;
        bb = a;
        diffExponent = -diffExponent;
    }

    VLI aaValue = NSDecimalMantissa(aa);
    VLI scaled;
    if (VLIMultiplyByPowerOfTen(&scaled, &aaValue, diffExponent, NSDecimalMaxSize) == NSCalculationNoError)
    {
        NSDecimalSetMantissa(aa, &scaled);
        aa->_exponent = bb->_exponent;
        aa->_isCompact = 0;
        return NSCalculationNoError;
    }

    // Scale aa up as far as it goes and bb down by the rest, dropping bb's low digits.
    int maxPower = VLIMaxPowerOfTenMultiplier(&aaValue, NSDecimalMaxSize);
    VLI bbValue = NSDecimalMantissa(bb);
    NSCalculationError error = VLIMultiplyByPowerOfTen(&scaled, &bbValue, maxPower - diffExponent, NSDecimalMaxSize);
    if (error == NSCalculationNoError)
    {
        error = NSDecimalSetMantissa(bb, &scaled);
    }
    if (error != NSCalculationNoError)
    {
        return error;
    }
    bb->_exponent -= maxPower - diffExponent;
    bb->_isCompact = 0;
    if (bb->_length != 0)
    {
        error = VLIMultiplyByPowerOfTen(&scaled, &aaValue, maxPower, NSDecimalMaxSize);
        if (error == NSCalculationNoError)
        {
            error = NSDecimalSetMantissa(aa, &scaled);
        }
        if (error != NSCalculationNoError)
        {
            return error;
        }
        aa->_exponent -= maxPower;
        aa->_isCompact = 0;
    }
    else
    {
        bb->_exponent = aa->_exponent;
    }
    *lossOfPrecision = YES;
    return NSCalculationNoError;
}

static NSCalculationError NSDecimalAddChecked(NSDecimal *result, const NSDecimal *left, const NSDecimal *right, NSRoundingMode roundingMode, BOOL *lossOfPrecision)
{
    *lossOfPrecision = NO;
    if (NSDecimalIsNaN(left) || NSDecimalIsNaN(right))
    {
        return NSCalculationOverflow;
    }
    if (left->_length == 0)
    {
        *result = *right;
        return NSCalculationNoError;
    }
    if (right->_length == 0)
    {
        *result = *left;
        return NSCalculationNoError;
    }
    NSDecimal a = *left;
    NSDecimal b = *right;
    NSCalculationError error = NSDecimalNormalizeInPlace(&a, &b, lossOfPrecision);
    if (error != NSCalculationNoError)
    {
        return error;
    }
    if (a._length == 0)
    {
        *result = b;
        return NSCalculationNoError;
    }
    if (b._length == 0)
    {
        *result = a;
        return NSCalculationNoError;
    }

    NSDecimal sum = a;
    VLI aValue = NSDecimalMantissa(&a);
    VLI bValue = NSDecimalMantissa(&b);
    if (a._isNegative == b._isNegative)
    {
        VLI value;
        VLIAdd(&value, &aValue, &bValue, NSDecimalMaxSize + 1);
        int exponent;
        VLIFitMantissa(&value, &exponent, roundingMode, a._isNegative);
        if (sum._exponent + exponent > DECIMAL_MAX_EXPONENT)
        {
            return NSCalculationOverflow;
        }
        sum._exponent += exponent;
        NSDecimalSetMantissa(&sum, &value);
    }
    else
    {
        VLI value;
        switch (VLICompare(&aValue, &bValue))
        {
            case NSOrderedSame:
                *result = zeroDecimal;
                return NSCalculationNoError;
            case NSOrderedAscending:
                VLISubtract(&value, &bValue, &aValue);
                sum._isNegative = b._isNegative;
                break;
            case NSOrderedDescending:
                VLISubtract(&value, &aValue, &bValue);
                sum._isNegative = a._isNegative;
                break;
        }
        NSDecimalSetMantissa(&sum, &value);
    }
    sum._isCompact = 0;
    NSDecimalCompactInPlace(&sum);
    *result = sum;
    return NSCalculationNoError;
}

static NSCalculationError NSDecimalMultiplyChecked(NSDecimal *result, const NSDecimal *left, const NSDecimal *right, NSRoundingMode roundingMode)
{
    if (NSDecimalIsNaN(left) || NSDecimalIsNaN(right))
    {
        return NSCalculationOverflow;
    }
    if (left->_length == 0 || right->_length == 0)
    {
        *result = zeroDecimal;
        return NSCalculationNoError;
    }
    VLI lhs = NSDecimalMantissa(left);
    VLI rhs = NSDecimalMantissa(right);
    VLI product;
    NSCalculationError error = VLIMultiply(&product, &lhs, &rhs, NSDecimalMaxSize * 2);
    if (error != NSCalculationNoError)
    {
        return error;
    }
    int exponent = left->_exponent + right->_exponent;
    int fitExponent;
    VLIFitMantissa(&product, &fitExponent, roundingMode, left->_isNegative != right->_isNegative);
    exponent += fitExponent;
    if (exponent > DECIMAL_MAX_EXPONENT)
    {
        return NSCalculationOverflow;
    }
    unsigned int remainder = 0;
    while (exponent < DECIMAL_MIN_EXPONENT && remainder == 0)
    {
        VLI quotient;
        VLIDivideByShort(&quotient, &remainder, &product, 10);
        if (remainder == 0)
        {
            product = quotient;
            exponent++;
        }
    }
    if (exponent < DECIMAL_MIN_EXPONENT)
    {
        return NSCalculationUnderflow;
    }
    NSDecimal value = zeroDecimal;
    value._isNegative = left->_isNegative != right->_isNegative;
    NSDecimalSetMantissa(&value, &product);
    value._exponent = exponent;
    NSDecimalCompactInPlace(&value);
    *result = value;
    return NSCalculationNoError;
}

static NSCalculationError NSDecimalDivideChecked(NSDecimal *result, const NSDecimal *left, const NSDecimal *right, NSRoundingMode roundingMode)
{
    if (NSDecimalIsNaN(left) || NSDecimalIsNaN(right))
    {
        return NSCalculationOverflow;
    }
    if (right->_length == 0)
    {
        return NSCalculationDivideByZero;
    }
    if (left->_length == 0)
    {
        *result = zeroDecimal;
        return NSCalculationNoError;
    }

    NSDecimal a = *left;
    NSDecimal b = *right;
    // A much larger dividend exponent loses precision below; normalizing first keeps more.
    if (a._exponent - b._exponent >= 19)
    {
        BOOL ignoredLoss;
        NSCalculationError error = NSDecimalNormalizeInPlace(&a, &b, &ignoredLoss);
        if (error != NSCalculationNoError)
        {
            return error;
        }
        if (a._length == 0 || b._length == 0)
        {
            a = *left;
            b = *right;
        }
    }

    VLI dividend = NSDecimalMantissa(&a);
    VLI divisor = NSDecimalMantissa(&b);
    VLI quotient;
    NSCalculationError error = VLIMultiplyByPowerOfTen(&dividend, &dividend, maxPowerOfTen, NSDecimalMaxSize * 2);
    if (error == NSCalculationNoError)
    {
        error = VLIDivide(&quotient, &dividend, &divisor);
    }
    if (error != NSCalculationNoError)
    {
        return error;
    }
    int fitExponent;
    // Like macOS, the quotient is truncated regardless of the rounding mode.
    VLIFitMantissa(&quotient, &fitExponent, NSRoundDown, NO);
    int exponent = a._exponent - b._exponent - maxPowerOfTen + fitExponent;
    if (exponent < DECIMAL_MIN_EXPONENT)
    {
        return NSCalculationUnderflow;
    }
    if (exponent > DECIMAL_MAX_EXPONENT)
    {
        return NSCalculationOverflow;
    }
    NSDecimal value = zeroDecimal;
    NSDecimalSetMantissa(&value, &quotient);
    value._isNegative = value._length != 0 && a._isNegative != b._isNegative;
    value._exponent = exponent;
    NSDecimalCompactInPlace(&value);
    *result = value;
    return NSCalculationNoError;
}

static NSCalculationError NSDecimalFinish(NSDecimal *result, const NSDecimal *value, NSCalculationError error)
{
    *result = error == NSCalculationNoError || error == NSCalculationLossOfPrecision ? *value : NSDecimalNaN();
    return error;
}

#pragma mark - NSDecimal functions

void NSDecimalCompact(NSDecimal *decimal)
{
    NSDecimalCompactInPlace(decimal);
}

void NSDecimalCopy(NSDecimal *destination, const NSDecimal *source)
{
    destination->_exponent = source->_exponent;
    destination->_length = source->_length;
    destination->_isNegative = source->_isNegative;
    destination->_isCompact = source->_isCompact;
    // _reserved is not copied, it is omitted on purpose
    for (int i = 0; i < source->_length; i++)
    {
        destination->_mantissa[i] = source->_mantissa[i];
    }
}

NSComparisonResult NSDecimalCompare(const NSDecimal *leftOperand, const NSDecimal *rightOperand)
{
    if (NSDecimalIsNaN(leftOperand))
    {
        return NSDecimalIsNaN(rightOperand) ? NSOrderedSame : NSOrderedAscending;
    }
    if (NSDecimalIsNaN(rightOperand))
    {
        return NSOrderedDescending;
    }
    if (leftOperand->_isNegative != rightOperand->_isNegative)
    {
        return leftOperand->_isNegative ? NSOrderedAscending : NSOrderedDescending;
    }
    if (leftOperand->_length == 0)
    {
        return rightOperand->_length != 0 ? NSOrderedAscending : NSOrderedSame;
    }
    if (rightOperand->_length == 0)
    {
        return NSOrderedDescending;
    }

    NSDecimal a = *leftOperand;
    NSDecimal b = *rightOperand;
    BOOL ignoredLoss;
    NSDecimalNormalizeInPlace(&a, &b, &ignoredLoss);
    VLI aValue = NSDecimalMantissa(&a);
    VLI bValue = NSDecimalMantissa(&b);
    NSComparisonResult result = VLICompare(&aValue, &bValue);
    return a._isNegative ? -result : result;
}

void NSDecimalRound(NSDecimal *result, const NSDecimal *number, NSInteger scale, NSRoundingMode roundingMode)
{
    // Callers pass a short (NSDecimalNumberBehaviors); clamping keeps the arithmetic below in range.
    scale = MIN(MAX(scale, SHRT_MIN), SHRT_MAX);
    NSInteger digitsToDrop = scale + number->_exponent;
    if (scale == NSDecimalNoScale || digitsToDrop >= 0)
    {
        *result = *number;
        return;
    }
    digitsToDrop = -digitsToDrop;
    NSInteger exponent = -scale;
    NSDecimal rounded = *number;
    unsigned int remainder = 0;
    BOOL sticky = NO;
    while (digitsToDrop > 0 && rounded._length > 0)
    {
        sticky = sticky || remainder != 0;
        unsigned int divisor = digitsToDrop > 4 ? 10000 : 10;
        NSDecimalDivideByShort(&rounded, divisor, &remainder);
        digitsToDrop -= divisor == 10000 ? 4 : 1;
    }
    if (digitsToDrop > 0)
    {
        // Every digit is gone; the ones still to drop are zeros.
        sticky = sticky || remainder != 0;
        remainder = 0;
    }

    BOOL isNegative = number->_isNegative != 0;
    // Like macOS, leave the result untouched if the rounded value does not fit.
    if (NSDecimalRoundsUp(remainder, sticky, roundingMode, isNegative, rounded._mantissa[0] & 1) &&
        NSDecimalAddShort(&rounded, 1) != NSCalculationNoError)
    {
        return;
    }
    if ((remainder != 0 || sticky) && rounded._length == 0)
    {
        rounded._isNegative = 0;
    }
    rounded._isCompact = 0;
    while (exponent > DECIMAL_MAX_EXPONENT)
    {
        if (rounded._length == 0)
        {
            exponent = DECIMAL_MAX_EXPONENT;
            break;
        }
        if (NSDecimalMultiplyByShort(&rounded, 10) != NSCalculationNoError)
        {
            return;
        }
        exponent--;
    }
    rounded._exponent = exponent;
    NSDecimalCompactInPlace(&rounded);
    *result = rounded;
}

NSCalculationError NSDecimalNormalize(NSDecimal *number1, NSDecimal *number2, NSRoundingMode roundingMode)
{
    NSDecimal a = *number1;
    NSDecimal b = *number2;
    BOOL lossOfPrecision;
    NSCalculationError error = NSDecimalNormalizeInPlace(&a, &b, &lossOfPrecision);
    if (error != NSCalculationNoError)
    {
        return error;
    }
    *number1 = a;
    *number2 = b;
    return lossOfPrecision ? NSCalculationLossOfPrecision : NSCalculationNoError;
}

NSCalculationError NSDecimalAdd(NSDecimal *result, const NSDecimal *leftOperand, const NSDecimal *rightOperand, NSRoundingMode roundingMode)
{
    NSDecimal sum;
    BOOL lossOfPrecision;
    NSCalculationError error = NSDecimalAddChecked(&sum, leftOperand, rightOperand, roundingMode, &lossOfPrecision);
    if (error == NSCalculationNoError && lossOfPrecision)
    {
        error = NSCalculationLossOfPrecision;
    }
    return NSDecimalFinish(result, &sum, error);
}

NSCalculationError NSDecimalSubtract(NSDecimal *result, const NSDecimal *leftOperand, const NSDecimal *rightOperand, NSRoundingMode roundingMode)
{
    NSDecimal negated = *rightOperand;
    if (negated._length != 0)
    {
        negated._isNegative = !negated._isNegative;
    }
    NSDecimal difference;
    BOOL ignoredLoss;
    NSCalculationError error = NSDecimalAddChecked(&difference, leftOperand, &negated, roundingMode, &ignoredLoss);
    return NSDecimalFinish(result, &difference, error);
}

NSCalculationError NSDecimalMultiply(NSDecimal *result, const NSDecimal *leftOperand, const NSDecimal *rightOperand, NSRoundingMode roundingMode)
{
    NSDecimal product;
    NSCalculationError error = NSDecimalMultiplyChecked(&product, leftOperand, rightOperand, roundingMode);
    return NSDecimalFinish(result, &product, error);
}

NSCalculationError NSDecimalDivide(NSDecimal *result, const NSDecimal *leftOperand, const NSDecimal *rightOperand, NSRoundingMode roundingMode)
{
    NSDecimal quotient;
    NSCalculationError error = NSDecimalDivideChecked(&quotient, leftOperand, rightOperand, roundingMode);
    return NSDecimalFinish(result, &quotient, error);
}

NSCalculationError NSDecimalPower(NSDecimal *result, const NSDecimal *number, NSUInteger power, NSRoundingMode roundingMode)
{
    if (NSDecimalIsNaN(number))
    {
        *result = NSDecimalNaN();
        return NSCalculationOverflow;
    }
    NSInteger exponent = (NSInteger)power;
    NSDecimal one = zeroDecimal;
    one._length = 1;
    one._isCompact = 1;
    one._mantissa[0] = 1;
    if (exponent == 0)
    {
        *result = one;
        return NSCalculationNoError;
    }
    if (number->_length == 0)
    {
        // 0^-n is undefined.
        *result = exponent > 0 ? zeroDecimal : NSDecimalNaN();
        return NSCalculationNoError;
    }

    NSUInteger remaining = exponent < 0 ? -(NSUInteger)exponent : (NSUInteger)exponent;
    NSDecimal base = *number;
    NSDecimal accumulator = one;
    NSCalculationError error = NSCalculationNoError;
    while (error == NSCalculationNoError && remaining > 1)
    {
        if (remaining & 1)
        {
            error = NSDecimalMultiplyChecked(&accumulator, &accumulator, &base, roundingMode);
            remaining--;
        }
        if (error == NSCalculationNoError)
        {
            error = NSDecimalMultiplyChecked(&base, &base, &base, roundingMode);
            remaining /= 2;
        }
    }
    if (error == NSCalculationNoError)
    {
        error = NSDecimalMultiplyChecked(&base, &accumulator, &base, roundingMode);
    }
    if (error == NSCalculationNoError && exponent < 0)
    {
        error = NSDecimalDivideChecked(&base, &one, &base, roundingMode);
    }
    return NSDecimalFinish(result, &base, error);
}

NSCalculationError NSDecimalMultiplyByPowerOf10(NSDecimal *result, const NSDecimal *number, short power, NSRoundingMode roundingMode)
{
    if (NSDecimalIsNaN(number))
    {
        *result = NSDecimalNaN();
        return NSCalculationOverflow;
    }
    if (number->_length == 0)
    {
        *result = zeroDecimal;
        return NSCalculationNoError;
    }
    int exponent = number->_exponent + power;
    if (exponent < DECIMAL_MIN_EXPONENT)
    {
        *result = NSDecimalNaN();
        return NSCalculationUnderflow;
    }
    if (exponent > DECIMAL_MAX_EXPONENT)
    {
        *result = NSDecimalNaN();
        return NSCalculationOverflow;
    }
    *result = *number;
    result->_exponent = exponent;
    return NSCalculationNoError;
}

static NSString *NSDecimalSeparator(id locale)
{
    id separator = nil;
    if ([locale isKindOfClass:[NSLocale class]])
    {
        separator = [locale objectForKey:NSLocaleDecimalSeparator];
    }
    else if ([locale isKindOfClass:[NSDictionary class]])
    {
        separator = [locale objectForKey:NSLocaleDecimalSeparator] ?: [locale objectForKey:@"NSDecimalSeparator"];
    }
    return [separator isKindOfClass:[NSString class]] ? separator : @".";
}

NSString *NSDecimalString(const NSDecimal *dcm, id locale)
{
    if (NSDecimalIsNaN(dcm))
    {
        return @"NaN";
    }
    VLI value = NSDecimalMantissa(dcm);
    if (value.count == 0)
    {
        return @"0";
    }

    // 2^128 has 39 decimal digits.
    char digits[40];
    int digitCount = 0;
    while (value.count != 0)
    {
        unsigned int remainder;
        VLIDivideByShort(&value, &remainder, &value, 10);
        digits[digitCount++] = '0' + remainder;
    }

    NSMutableString *string = [NSMutableString stringWithString:dcm->_isNegative ? @"-" : @""];
    int exponent = dcm->_exponent;
    int integerDigits = digitCount + exponent;
    if (integerDigits <= 0)
    {
        [string appendString:@"0"];
    }
    for (int i = digitCount - 1; i >= digitCount - integerDigits && i >= 0; i--)
    {
        [string appendFormat:@"%c", digits[i]];
    }
    for (int i = 0; i < exponent; i++)
    {
        [string appendString:@"0"];
    }
    if (exponent < 0)
    {
        [string appendString:NSDecimalSeparator(locale)];
        for (int i = integerDigits; i < 0; i++)
        {
            [string appendString:@"0"];
        }
        for (int i = MIN(digitCount, -exponent) - 1; i >= 0; i--)
        {
            [string appendFormat:@"%c", digits[i]];
        }
    }
    return string;
}
