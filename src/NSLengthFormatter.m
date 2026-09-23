// Objective-C port of swift-corelibs-foundation's Sources/Foundation/LengthFormatter.swift.
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See http://swift.org/LICENSE.txt for license information

#import <Foundation/NSCoder.h>
#import <Foundation/NSLengthFormatter.h>
#include <math.h>
#import "NSUnitFormatterInternal.h"

typedef struct {
    NSLengthFormatterUnit unit;
    double meters;
    NSString *shortSymbol;
    NSString *mediumSymbol;
    NSString *singular;
    NSString *plural;
} NSLengthFormatterUnitInfo;

static const NSLengthFormatterUnitInfo NSLengthFormatterUnits[] = {
    { NSLengthFormatterUnitMillimeter, 0.001, @"mm", @"mm", @"millimeter", @"millimeters" },
    { NSLengthFormatterUnitCentimeter, 0.01, @"cm", @"cm", @"centimeter", @"centimeters" },
    { NSLengthFormatterUnitMeter, 1.0, @"m", @"m", @"meter", @"meters" },
    { NSLengthFormatterUnitKilometer, 1000.0, @"km", @"km", @"kilometer", @"kilometers" },
    { NSLengthFormatterUnitInch, 0.0254, @"″", @"in", @"inch", @"inches" },
    { NSLengthFormatterUnitFoot, 0.3048, @"′", @"ft", @"foot", @"feet" },
    { NSLengthFormatterUnitYard, 0.9144, @"yd", @"yd", @"yard", @"yards" },
    { NSLengthFormatterUnitMile, 1609.344, @"mi", @"mi", @"mile", @"miles" },
};

static const NSLengthFormatterUnitInfo *NSLengthFormatterUnitInfoFor(NSLengthFormatterUnit unit)
{
    for (size_t i = 0; i < sizeof(NSLengthFormatterUnits) / sizeof(NSLengthFormatterUnits[0]); i++)
    {
        if (NSLengthFormatterUnits[i].unit == unit)
        {
            return &NSLengthFormatterUnits[i];
        }
    }
    [NSException raise:NSInvalidArgumentException format:@"Invalid NSLengthFormatterUnit %ld", (long)unit];
    return NULL;
}

@implementation NSLengthFormatter

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

- (BOOL)isForPersonHeightUse
{
    return _isForPersonHeight;
}

- (void)setForPersonHeightUse:(BOOL)forPersonHeightUse
{
    _isForPersonHeight = forPersonHeightUse;
}

- (NSLengthFormatterUnit)_unitFromMeters:(double)meters
{
    if (_NSUnitFormatterUsesMetricSystem(_numberFormatter))
    {
        if (_isForPersonHeight)
        {
            return NSLengthFormatterUnitCentimeter;
        }
        if (meters > 1000.0 || meters < 0.0)
        {
            return NSLengthFormatterUnitKilometer;
        }
        if (meters > 1.0)
        {
            return NSLengthFormatterUnitMeter;
        }
        return meters > 0.01 ? NSLengthFormatterUnitCentimeter : NSLengthFormatterUnitMillimeter;
    }

    if (_isForPersonHeight)
    {
        return NSLengthFormatterUnitFoot;
    }
    double feet = meters / NSLengthFormatterUnitInfoFor(NSLengthFormatterUnitFoot)->meters;
    if (feet < 0.0 || feet > 5280.0)
    {
        return NSLengthFormatterUnitMile;
    }
    if (feet > 3.0 || feet == 0.0)
    {
        return NSLengthFormatterUnitYard;
    }
    return feet >= 1.0 ? NSLengthFormatterUnitFoot : NSLengthFormatterUnitInch;
}

- (NSString *)stringFromValue:(double)value unit:(NSLengthFormatterUnit)unit
{
    return _NSUnitFormatterJoin(_numberFormatter, _unitStyle, value, [self unitStringFromValue:value unit:unit]);
}

- (NSString *)stringFromMeters:(double)numberInMeters
{
    NSLengthFormatterUnit unit = [self _unitFromMeters:numberInMeters];
    double value = numberInMeters / NSLengthFormatterUnitInfoFor(unit)->meters;

    if (unit == NSLengthFormatterUnitFoot && _isForPersonHeight)
    {
        double feet = trunc(value);
        double inches = fabs(fmod(value, 1.0)) * 12.0;
        return [NSString stringWithFormat:@"%@, %@",
                                          [self stringFromValue:feet unit:NSLengthFormatterUnitFoot],
                                          [self stringFromValue:inches unit:NSLengthFormatterUnitInch]];
    }
    return [self stringFromValue:value unit:unit];
}

- (NSString *)unitStringFromValue:(double)value unit:(NSLengthFormatterUnit)unit
{
    const NSLengthFormatterUnitInfo *info = NSLengthFormatterUnitInfoFor(unit);
    switch (_unitStyle)
    {
        case NSFormattingUnitStyleShort:
            return info->shortSymbol;
        case NSFormattingUnitStyleMedium:
            return info->mediumSymbol;
        default:
            return value == 1.0 ? info->singular : info->plural;
    }
}

- (NSString *)unitStringFromMeters:(double)numberInMeters usedUnit:(NSLengthFormatterUnit *)unitp
{
    NSLengthFormatterUnit unit = [self _unitFromMeters:numberInMeters];
    if (unitp != NULL)
    {
        *unitp = unit;
    }
    return [self unitStringFromValue:numberInMeters / NSLengthFormatterUnitInfoFor(unit)->meters unit:unit];
}

- (NSString *)stringForObjectValue:(id)obj
{
    if ([obj isKindOfClass:[NSNumber class]])
    {
        return [self stringFromMeters:[obj doubleValue]];
    }
    return nil;
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error
{
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSLengthFormatter *copy = [[[self class] allocWithZone:zone] init];
    [copy setNumberFormatter:_numberFormatter];
    copy->_unitStyle = _unitStyle;
    copy->_isForPersonHeight = _isForPersonHeight;
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
            _isForPersonHeight = [coder decodeBoolForKey:@"NS.forPersonHeightUse"];
        }
        else
        {
            numberFormatter = [coder decodeObject];
            [coder decodeValueOfObjCType:@encode(NSInteger) at:&_unitStyle];
            [coder decodeValueOfObjCType:@encode(BOOL) at:&_isForPersonHeight];
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
        [coder encodeBool:_isForPersonHeight forKey:@"NS.forPersonHeightUse"];
    }
    else
    {
        [coder encodeObject:_numberFormatter];
        [coder encodeValueOfObjCType:@encode(NSInteger) at:&_unitStyle];
        [coder encodeValueOfObjCType:@encode(BOOL) at:&_isForPersonHeight];
    }
}

@end
