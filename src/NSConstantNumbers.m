//
//  NSConstantNumbers.m
//  Foundation
//
//  Classes for number literals (`@42`, `@2.5f`, `@2.5`) that newer clang emits as constant
//  objects directly into binaries. The object layouts must match clang's exactly (see
//  NSConstantIntegerNumber/NSConstantFloatNumber/NSConstantDoubleNumber in
//  clang/lib/CodeGen/CGObjCMac.cpp), so the classes read the structs directly instead of
//  declaring ivars. Comparison, hashing and descriptions go through an equivalent regular
//  NSNumber so they behave like every other number.
//

#import <Foundation/NSValue.h>
#import <Foundation/NSString.h>
#import <CoreFoundation/CFNumber.h>
#import "NSObjectInternal.h"

struct __NSConstantIntegerNumberLayout {
    Class isa;
    const char *encoding;
    long long value;
};

struct __NSConstantFloatNumberLayout {
    Class isa;
    float value;
};

struct __NSConstantDoubleNumberLayout {
    Class isa;
    double value;
};

#define INTEGER_LAYOUT(obj) ((struct __NSConstantIntegerNumberLayout *)(obj))
#define FLOAT_LAYOUT(obj) ((struct __NSConstantFloatNumberLayout *)(obj))
#define DOUBLE_LAYOUT(obj) ((struct __NSConstantDoubleNumberLayout *)(obj))

// Accessors shared by all constant number classes; `VALUE` is the stored value.
#define CONSTANT_NUMBER_ACCESSORS(VALUE) \
CONSTANT_NUMBER_COMMON_ACCESSORS(VALUE) \
- (float)floatValue { return (float)(VALUE); } \
- (double)doubleValue { return (double)(VALUE); }

#define CONSTANT_NUMBER_COMMON_ACCESSORS(VALUE) \
- (char)charValue { return (char)(VALUE); } \
- (unsigned char)unsignedCharValue { return (unsigned char)(VALUE); } \
- (short)shortValue { return (short)(VALUE); } \
- (unsigned short)unsignedShortValue { return (unsigned short)(VALUE); } \
- (int)intValue { return (int)(VALUE); } \
- (unsigned int)unsignedIntValue { return (unsigned int)(VALUE); } \
- (long)longValue { return (long)(VALUE); } \
- (unsigned long)unsignedLongValue { return (unsigned long)(VALUE); } \
- (long long)longLongValue { return (long long)(VALUE); } \
- (unsigned long long)unsignedLongLongValue { return (unsigned long long)(VALUE); } \
- (NSInteger)integerValue { return (NSInteger)(VALUE); } \
- (NSUInteger)unsignedIntegerValue { return (NSUInteger)(VALUE); } \
- (BOOL)boolValue { return (VALUE) != 0; } \
- (id)copyWithZone:(NSZone *)zone { return self; } \
- (CFTypeID)_cfTypeID { return CFNumberGetTypeID(); } \
- (CFNumberType)_cfNumberType { return CFNumberGetType((CFNumberRef)[self _equivalentNumber]); } \
- (Boolean)_getValue:(void *)value forType:(CFNumberType)type { return CFNumberGetValue((CFNumberRef)[self _equivalentNumber], type, value); } \
- (NSUInteger)hash { return [[self _equivalentNumber] hash]; } \
- (BOOL)isEqual:(id)other { return self == other || (other != nil && [other isNSNumber__] && [self compare:other] == NSOrderedSame); } \
- (BOOL)isEqualToNumber:(NSNumber *)other { return self == other || (other != nil && [self compare:other] == NSOrderedSame); } \
- (NSComparisonResult)compare:(NSNumber *)other \
{ \
    /* Compare CF numbers directly: handing `self` or another constant number to CFNumberCompare */ \
    /* would dispatch back into these methods (compare:/_reverseCompare:) and recurse. */ \
    if ([other respondsToSelector:@selector(_equivalentNumber)]) \
        other = [(id)other _equivalentNumber]; \
    return (NSComparisonResult)CFNumberCompare((CFNumberRef)[self _equivalentNumber], (CFNumberRef)other, NULL); \
} \
/* CFNumberCompare(a, b) calls [b _reverseCompare:a] when b is an Objective-C number; it expects compare(a, b). */ \
- (NSComparisonResult)_reverseCompare:(NSNumber *)other { return (NSComparisonResult)-(NSInteger)[self compare:other]; } \
- (NSString *)stringValue { return [[self _equivalentNumber] stringValue]; } \
- (NSString *)description { return [[self _equivalentNumber] description]; } \
- (NSString *)descriptionWithLocale:(id)locale { return [[self _equivalentNumber] descriptionWithLocale:locale]; }

__attribute__((visibility("default")))
@interface NSConstantIntegerNumber : NSNumber
@end

@implementation NSConstantIntegerNumber

SINGLETON_RR()

CONSTANT_NUMBER_COMMON_ACCESSORS(INTEGER_LAYOUT(self)->value)

// clang stores unsigned literals (encodings C, S, I, L, Q) as their 64-bit pattern, so values
// from 2^63 up read back negative as long long; convert them as unsigned.
static BOOL integerEncodingIsUnsigned(const char *encoding)
{
    switch (encoding[0])
    {
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            return YES;
        default:
            return NO;
    }
}

- (float)floatValue
{
    long long value = INTEGER_LAYOUT(self)->value;
    return integerEncodingIsUnsigned(INTEGER_LAYOUT(self)->encoding) ? (float)(unsigned long long)value : (float)value;
}

- (double)doubleValue
{
    long long value = INTEGER_LAYOUT(self)->value;
    return integerEncodingIsUnsigned(INTEGER_LAYOUT(self)->encoding) ? (double)(unsigned long long)value : (double)value;
}

- (const char *)objCType
{
    return INTEGER_LAYOUT(self)->encoding;
}

- (NSNumber *)_equivalentNumber
{
    long long value = INTEGER_LAYOUT(self)->value;
    switch (INTEGER_LAYOUT(self)->encoding[0])
    {
        case 'B':
            return [NSNumber numberWithBool:value != 0];
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
            return [NSNumber numberWithUnsignedLongLong:(unsigned long long)value];
        default:
            return [NSNumber numberWithLongLong:value];
    }
}

- (void)getValue:(void *)buffer
{
    long long value = INTEGER_LAYOUT(self)->value;
    switch (INTEGER_LAYOUT(self)->encoding[0])
    {
        case 'c': *(char *)buffer = (char)value; break;
        case 'C': *(unsigned char *)buffer = (unsigned char)value; break;
        case 'B': *(bool *)buffer = value != 0; break;
        case 's': *(short *)buffer = (short)value; break;
        case 'S': *(unsigned short *)buffer = (unsigned short)value; break;
        case 'i': *(int *)buffer = (int)value; break;
        case 'I': *(unsigned int *)buffer = (unsigned int)value; break;
        case 'l': *(long *)buffer = (long)value; break;
        case 'L': *(unsigned long *)buffer = (unsigned long)value; break;
        case 'Q': *(unsigned long long *)buffer = (unsigned long long)value; break;
        default: *(long long *)buffer = value; break;
    }
}

@end

__attribute__((visibility("default")))
@interface NSConstantFloatNumber : NSNumber
@end

@implementation NSConstantFloatNumber

SINGLETON_RR()

CONSTANT_NUMBER_ACCESSORS(FLOAT_LAYOUT(self)->value)

- (const char *)objCType
{
    return @encode(float);
}

- (NSNumber *)_equivalentNumber
{
    return [NSNumber numberWithFloat:FLOAT_LAYOUT(self)->value];
}

- (void)getValue:(void *)buffer
{
    *(float *)buffer = FLOAT_LAYOUT(self)->value;
}

@end

__attribute__((visibility("default")))
@interface NSConstantDoubleNumber : NSNumber
@end

@implementation NSConstantDoubleNumber

SINGLETON_RR()

CONSTANT_NUMBER_ACCESSORS(DOUBLE_LAYOUT(self)->value)

- (const char *)objCType
{
    return @encode(double);
}

- (NSNumber *)_equivalentNumber
{
    return [NSNumber numberWithDouble:DOUBLE_LAYOUT(self)->value];
}

- (void)getValue:(void *)buffer
{
    *(double *)buffer = DOUBLE_LAYOUT(self)->value;
}

@end
