//
//  NSConstantNumber.m
//  Foundation
//
//  The number literals clang emits when it knows their value at compile time.
//  For a macOS 11 or newer runtime clang turns a literal such as `@42` into a
//  statically allocated struct with the class, the @encode string and the value,
//  binding the class to NSConstantIntegerNumber (or NSConstantDoubleNumber /
//  NSConstantFloatNumber for floating point). Applications built that way fail
//  to launch under Darling because these classes did not exist:
//
//      dyld: Symbol not found: _OBJC_CLASS_$_NSConstantIntegerNumber
//
//  The layouts below are the ones clang emits (CGObjCMac.cpp,
//  GenerateConstantNSNumber):
//
//      struct { Class isa; const char *encoding; long long value; }
//      struct { Class isa; double value; }
//      struct { Class isa; float value; }
//
//  The instances are in the calling image's read-only data and live for the
//  lifetime of the process, so retain/release are no-ops and copying returns the
//  same object. Everything else goes through the ordinary NSNumber accessors so
//  a constant number compares equal to the equivalent created number.

#import <Foundation/NSNumber.h>
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>
#import <Foundation/NSObjCRuntime.h>
#import <string.h>

@interface NSConstantIntegerNumber : NSNumber {
    const char *_encoding;
    long long _value;
}
@end

@interface NSConstantDoubleNumber : NSNumber {
    double _value;
}
@end

@interface NSConstantFloatNumber : NSNumber {
    float _value;
}
@end

static NSUInteger encodingSize(const char *encoding)
{
    switch (encoding ? encoding[0] : '\0')
    {
        case 'c':
        case 'C':
        case 'B':
            return 1;
        case 's':
        case 'S':
            return 2;
        case 'i':
        case 'I':
        case 'f':
            return 4;
        case 'l':
        case 'L':
        case 'q':
        case 'Q':
        case 'd':
            return 8;
        default:
            return 8;
    }
}

static BOOL encodingIsUnsigned(const char *encoding)
{
    switch (encoding ? encoding[0] : '\0')
    {
        case 'C':
        case 'S':
        case 'I':
        case 'L':
        case 'Q':
        case 'B':
            return YES;
        default:
            return NO;
    }
}

@implementation NSConstantIntegerNumber

- (NSNumber *)boxedValue { return encodingIsUnsigned(_encoding) ? [NSNumber numberWithUnsignedLongLong:(unsigned long long)_value] : [NSNumber numberWithLongLong:_value]; }
- (NSComparisonResult)compare:(NSNumber *)other
{
    if (other == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"Cannot compare NSNumber with nil"];
    }
    if (other == self)
    {
        return NSOrderedSame;
    }
    if (encodingIsUnsigned(_encoding))
    {
        const char *otherEncoding = [other objCType];
        char otherCode = otherEncoding ? otherEncoding[0] : '\0';
        if (otherCode == 'f' || otherCode == 'd')
        {
            double lhs = (double)(unsigned long long)_value;
            double rhs = [other doubleValue];
            if (lhs < rhs) return NSOrderedAscending;
            if (lhs > rhs) return NSOrderedDescending;
            return NSOrderedSame;
        }
        if (!encodingIsUnsigned(otherEncoding) && [other longLongValue] < 0)
        {
            return NSOrderedDescending;
        }
        unsigned long long lhs = (unsigned long long)_value;
        unsigned long long rhs = [other unsignedLongLongValue];
        if (lhs < rhs) return NSOrderedAscending;
        if (lhs > rhs) return NSOrderedDescending;
        return NSOrderedSame;
    }
    return [[self boxedValue] compare:other];
}
- (NSUInteger)hash { return [[self boxedValue] hash]; }

/* CFNumberCompare on the other side of a comparison expects a CFNumber; these
 * objects are ordinary NSNumber subclasses, so compare through the accessors. */
- (NSComparisonResult)_reverseCompare:(id)other
{
    NSComparisonResult result = [self compare:other];
    if (result == NSOrderedAscending) return NSOrderedDescending;
    if (result == NSOrderedDescending) return NSOrderedAscending;
    return NSOrderedSame;
}

- (const char *)objCType
{
    return _encoding;
}

- (void)getValue:(void *)value
{
    switch (encodingSize(_encoding))
    {
        case 1: *(char *)value = (char)_value; break;
        case 2: *(short *)value = (short)_value; break;
        case 4: *(int *)value = (int)_value; break;
        default: *(long long *)value = _value; break;
    }
}

- (char)charValue { return (char)_value; }
- (unsigned char)unsignedCharValue { return (unsigned char)_value; }
- (short)shortValue { return (short)_value; }
- (unsigned short)unsignedShortValue { return (unsigned short)_value; }
- (int)intValue { return (int)_value; }
- (unsigned int)unsignedIntValue { return (unsigned int)_value; }
- (long)longValue { return (long)_value; }
- (unsigned long)unsignedLongValue { return (unsigned long)_value; }
- (long long)longLongValue { return _value; }
- (unsigned long long)unsignedLongLongValue { return (unsigned long long)_value; }
- (float)floatValue { return (float)[self doubleValue]; }
- (double)doubleValue { return encodingIsUnsigned(_encoding) ? (double)(unsigned long long)_value : (double)_value; }
- (BOOL)boolValue { return _value != 0; }
- (NSInteger)integerValue { return (NSInteger)_value; }
- (NSUInteger)unsignedIntegerValue { return (NSUInteger)_value; }

- (NSString *)stringValue
{
    if (encodingIsUnsigned(_encoding))
        return [NSString stringWithFormat:@"%llu", (unsigned long long)_value];
    return [NSString stringWithFormat:@"%lld", _value];
}

- (NSString *)description
{
    return [self stringValue];
}

- (NSString *)descriptionWithLocale:(id)locale
{
    return [self description];
}

- (id)copyWithZone:(NSZone *)zone { return self; }
- (id)retain { return self; }
- (oneway void)release { }
- (id)autorelease { return self; }
- (NSUInteger)retainCount { return NSUIntegerMax; }
- (void)dealloc { }

@end

@implementation NSConstantDoubleNumber

- (NSNumber *)boxedValue { return [NSNumber numberWithDouble:_value]; }
- (NSComparisonResult)compare:(NSNumber *)other
{
    return [[self boxedValue] compare:other];
}
- (NSUInteger)hash { return [[self boxedValue] hash]; }

/* CFNumberCompare on the other side of a comparison expects a CFNumber; these
 * objects are ordinary NSNumber subclasses, so compare through the accessors. */
- (NSComparisonResult)_reverseCompare:(id)other
{
    NSComparisonResult result = [self compare:other];
    if (result == NSOrderedAscending) return NSOrderedDescending;
    if (result == NSOrderedDescending) return NSOrderedAscending;
    return NSOrderedSame;
}

- (const char *)objCType { return @encode(double); }
- (void)getValue:(void *)value { *(double *)value = _value; }
- (char)charValue { return (char)_value; }
- (unsigned char)unsignedCharValue { return (unsigned char)_value; }
- (short)shortValue { return (short)_value; }
- (unsigned short)unsignedShortValue { return (unsigned short)_value; }
- (int)intValue { return (int)_value; }
- (unsigned int)unsignedIntValue { return (unsigned int)_value; }
- (long)longValue { return (long)_value; }
- (unsigned long)unsignedLongValue { return (unsigned long)_value; }
- (long long)longLongValue { return (long long)_value; }
- (unsigned long long)unsignedLongLongValue { return (unsigned long long)_value; }
- (float)floatValue { return (float)_value; }
- (double)doubleValue { return _value; }
- (BOOL)boolValue { return _value != 0.0; }
- (NSInteger)integerValue { return (NSInteger)_value; }
- (NSUInteger)unsignedIntegerValue { return (NSUInteger)_value; }

- (NSString *)stringValue
{
    return [[self boxedValue] stringValue];
}

- (NSString *)description
{
    return [self stringValue];
}

- (NSString *)descriptionWithLocale:(id)locale
{
    return [self description];
}

- (id)copyWithZone:(NSZone *)zone { return self; }
- (id)retain { return self; }
- (oneway void)release { }
- (id)autorelease { return self; }
- (NSUInteger)retainCount { return NSUIntegerMax; }
- (void)dealloc { }

@end

@implementation NSConstantFloatNumber

- (NSNumber *)boxedValue { return [NSNumber numberWithFloat:_value]; }
- (NSComparisonResult)compare:(NSNumber *)other
{
    return [[self boxedValue] compare:other];
}
- (NSUInteger)hash { return [[self boxedValue] hash]; }

/* CFNumberCompare on the other side of a comparison expects a CFNumber; these
 * objects are ordinary NSNumber subclasses, so compare through the accessors. */
- (NSComparisonResult)_reverseCompare:(id)other
{
    NSComparisonResult result = [self compare:other];
    if (result == NSOrderedAscending) return NSOrderedDescending;
    if (result == NSOrderedDescending) return NSOrderedAscending;
    return NSOrderedSame;
}

- (const char *)objCType { return @encode(float); }
- (void)getValue:(void *)value { *(float *)value = _value; }
- (char)charValue { return (char)_value; }
- (unsigned char)unsignedCharValue { return (unsigned char)_value; }
- (short)shortValue { return (short)_value; }
- (unsigned short)unsignedShortValue { return (unsigned short)_value; }
- (int)intValue { return (int)_value; }
- (unsigned int)unsignedIntValue { return (unsigned int)_value; }
- (long)longValue { return (long)_value; }
- (unsigned long)unsignedLongValue { return (unsigned long)_value; }
- (long long)longLongValue { return (long long)_value; }
- (unsigned long long)unsignedLongLongValue { return (unsigned long long)_value; }
- (float)floatValue { return _value; }
- (double)doubleValue { return (double)_value; }
- (BOOL)boolValue { return _value != 0.0f; }
- (NSInteger)integerValue { return (NSInteger)_value; }
- (NSUInteger)unsignedIntegerValue { return (NSUInteger)_value; }

- (NSString *)stringValue
{
    return [[self boxedValue] stringValue];
}

- (NSString *)description
{
    return [self stringValue];
}

- (NSString *)descriptionWithLocale:(id)locale
{
    return [self description];
}

- (id)copyWithZone:(NSZone *)zone { return self; }
- (id)retain { return self; }
- (oneway void)release { }
- (id)autorelease { return self; }
- (NSUInteger)retainCount { return NSUIntegerMax; }
- (void)dealloc { }

@end
