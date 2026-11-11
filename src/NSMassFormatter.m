// Objective-C port of swift-corelibs-foundation's Sources/Foundation/MassFormatter.swift.
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See http://swift.org/LICENSE.txt for license information

#import <Foundation/NSCoder.h>
#import <Foundation/NSMassFormatter.h>
#include <math.h>
#import "NSUnitFormatterInternal.h"

static const double NSMassFormatterPoundsPerStone = 14.0;

typedef struct {
    NSMassFormatterUnit unit;
    double kilograms;
    NSString *symbol;
    NSString *singular;
    NSString *plural;
} NSMassFormatterUnitInfo;

static const NSMassFormatterUnitInfo NSMassFormatterUnits[] = {
    { NSMassFormatterUnitGram, 0.001, @"g", @"gram", @"grams" },
    { NSMassFormatterUnitKilogram, 1.0, @"kg", @"kilogram", @"kilograms" },
    { NSMassFormatterUnitOunce, 0.028349523125, @"oz", @"ounce", @"ounces" },
    { NSMassFormatterUnitPound, 0.45359237, @"lb", @"pound", @"pounds" },
    { NSMassFormatterUnitStone, 6.35029318, @"st", @"stone", @"stones" },
};

static const NSMassFormatterUnitInfo *NSMassFormatterUnitInfoFor(NSMassFormatterUnit unit)
{
    for (size_t i = 0; i < sizeof(NSMassFormatterUnits) / sizeof(NSMassFormatterUnits[0]); i++)
    {
        if (NSMassFormatterUnits[i].unit == unit)
        {
            return &NSMassFormatterUnits[i];
        }
    }
    [NSException raise:NSInvalidArgumentException format:@"Invalid NSMassFormatterUnit %ld", (long)unit];
    return NULL;
}

@implementation NSMassFormatter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _numberFormatter = _NSUnitFormatterNewNumberFormatter();
        _unitStyle = NSFormattingUnitStyleMedium;
    }
    return self;
}

- (void)dealloc
{
    [_numberFormatter release];
    [super dealloc];
}

- (NSNumberFormatter *)numberFormatter
{
    return _numberFormatter;
}

- (void)setNumberFormatter:(NSNumberFormatter *)numberFormatter
{
    NSNumberFormatter *old = _numberFormatter;
    _numberFormatter = numberFormatter != nil ? [numberFormatter copy] : _NSUnitFormatterNewNumberFormatter();
    [old release];
}

- (NSFormattingUnitStyle)unitStyle
{
    return _unitStyle;
}

- (void)setUnitStyle:(NSFormattingUnitStyle)unitStyle
{
    _unitStyle = unitStyle;
}

- (BOOL)isForPersonMassUse
{
    return _isForPersonMass;
}

- (void)setForPersonMassUse:(BOOL)forPersonMassUse
{
    _isForPersonMass = forPersonMassUse;
}

- (NSMassFormatterUnit)_unitFromKilograms:(double)kilograms
{
    if (_NSUnitFormatterUsesMetricSystem(_numberFormatter))
    {
        return (kilograms > 1.0 || kilograms <= 0.0) ? NSMassFormatterUnitKilogram : NSMassFormatterUnitGram;
    }
    double pounds = kilograms / NSMassFormatterUnitInfoFor(NSMassFormatterUnitPound)->kilograms;
    return (pounds >= 1.0 || pounds <= 0.0) ? NSMassFormatterUnitPound : NSMassFormatterUnitOunce;
}

// Stones are singular in the abstract but plural next to a number, and a short pound next to a
// number is "#" rather than "lb".
- (NSString *)_unitStringAdjacentToValue:(double)value unit:(NSMassFormatterUnit)unit
{
    if (unit == NSMassFormatterUnitPound && _unitStyle == NSFormattingUnitStyleShort)
    {
        return @"#";
    }
    if (unit == NSMassFormatterUnitStone && _unitStyle == NSFormattingUnitStyleLong)
    {
        const NSMassFormatterUnitInfo *info = NSMassFormatterUnitInfoFor(unit);
        return value == 1.0 ? info->singular : info->plural;
    }
    return [self unitStringFromValue:value unit:unit];
}

- (NSString *)_singlePartStringFromValue:(double)value unit:(NSMassFormatterUnit)unit
{
    return _NSUnitFormatterJoin(_numberFormatter, _unitStyle, value, [self _unitStringAdjacentToValue:value unit:unit]);
}

- (NSString *)stringFromValue:(double)value unit:(NSMassFormatterUnit)unit
{
    if (unit != NSMassFormatterUnitStone)
    {
        return [self _singlePartStringFromValue:value unit:unit];
    }

    double stones = trunc(value);
    NSString *stoneString = [self _singlePartStringFromValue:stones unit:unit];
    double pounds = fabs(fmod(value, 1.0)) * NSMassFormatterPoundsPerStone;
    if (pounds == 0.0)
    {
        return stoneString;
    }
    return [NSString stringWithFormat:@"%@%@%@", stoneString,
                                      _unitStyle == NSFormattingUnitStyleShort ? @" " : @", ",
                                      [self stringFromValue:pounds unit:NSMassFormatterUnitPound]];
}

- (NSString *)stringFromKilograms:(double)numberInKilograms
{
    NSMassFormatterUnit unit = [self _unitFromKilograms:numberInKilograms];
    return [self stringFromValue:numberInKilograms / NSMassFormatterUnitInfoFor(unit)->kilograms unit:unit];
}

- (NSString *)unitStringFromValue:(double)value unit:(NSMassFormatterUnit)unit
{
    const NSMassFormatterUnitInfo *info = NSMassFormatterUnitInfoFor(unit);
    switch (_unitStyle)
    {
        case NSFormattingUnitStyleShort:
        case NSFormattingUnitStyleMedium:
            return info->symbol;
        default:
            return (unit == NSMassFormatterUnitStone || value == 1.0) ? info->singular : info->plural;
    }
}

- (NSString *)unitStringFromKilograms:(double)numberInKilograms usedUnit:(NSMassFormatterUnit *)unitp
{
    NSMassFormatterUnit unit = [self _unitFromKilograms:numberInKilograms];
    if (unitp != NULL)
    {
        *unitp = unit;
    }
    return [self unitStringFromValue:numberInKilograms / NSMassFormatterUnitInfoFor(unit)->kilograms unit:unit];
}

- (NSString *)stringForObjectValue:(id)obj
{
    if ([obj isKindOfClass:[NSNumber class]])
    {
        return [self stringFromKilograms:[obj doubleValue]];
    }
    return nil;
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error
{
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSMassFormatter *copy = [[[self class] allocWithZone:zone] init];
    [copy setNumberFormatter:_numberFormatter];
    copy->_unitStyle = _unitStyle;
    copy->_isForPersonMass = _isForPersonMass;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self != nil)
    {
        NSNumberFormatter *numberFormatter = nil;
        if ([coder allowsKeyedCoding])
        {
            numberFormatter = [coder decodeObjectForKey:@"NS.numberFormatter"];
            _unitStyle = [coder decodeIntegerForKey:@"NS.unitStyle"];
            _isForPersonMass = [coder decodeBoolForKey:@"NS.forPersonMassUse"];
        }
        else
        {
            numberFormatter = [coder decodeObject];
            [coder decodeValueOfObjCType:@encode(NSInteger) at:&_unitStyle];
            [coder decodeValueOfObjCType:@encode(BOOL) at:&_isForPersonMass];
        }
        [self setNumberFormatter:numberFormatter];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    if ([coder allowsKeyedCoding])
    {
        [coder encodeObject:_numberFormatter forKey:@"NS.numberFormatter"];
        [coder encodeInteger:_unitStyle forKey:@"NS.unitStyle"];
        [coder encodeBool:_isForPersonMass forKey:@"NS.forPersonMassUse"];
    }
    else
    {
        [coder encodeObject:_numberFormatter];
        [coder encodeValueOfObjCType:@encode(NSInteger) at:&_unitStyle];
        [coder encodeValueOfObjCType:@encode(BOOL) at:&_isForPersonMass];
    }
}

@end
