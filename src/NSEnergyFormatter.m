// Objective-C port of swift-corelibs-foundation's Sources/Foundation/EnergyFormatter.swift.
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See http://swift.org/LICENSE.txt for license information

#import <Foundation/NSCoder.h>
#import <Foundation/NSEnergyFormatter.h>
#import <Foundation/NSSet.h>
#import "NSUnitFormatterInternal.h"
#include <dispatch/dispatch.h>

typedef struct {
    NSEnergyFormatterUnit unit;
    double joules;
    NSString *symbol;
    NSString *singular;
    NSString *plural;
} NSEnergyFormatterUnitInfo;

static const NSEnergyFormatterUnitInfo NSEnergyFormatterUnits[] = {
    { NSEnergyFormatterUnitJoule, 1.0, @"J", @"joule", @"joules" },
    { NSEnergyFormatterUnitKilojoule, 1000.0, @"kJ", @"kilojoule", @"kilojoules" },
    { NSEnergyFormatterUnitCalorie, 4.184, @"cal", @"calorie", @"calories" },
    { NSEnergyFormatterUnitKilocalorie, 4184.0, @"kcal", @"kilocalorie", @"kilocalories" },
};

static const NSEnergyFormatterUnitInfo *NSEnergyFormatterUnitInfoFor(NSEnergyFormatterUnit unit)
{
    for (size_t i = 0; i < sizeof(NSEnergyFormatterUnits) / sizeof(NSEnergyFormatterUnits[0]); i++)
    {
        if (NSEnergyFormatterUnits[i].unit == unit)
        {
            return &NSEnergyFormatterUnits[i];
        }
    }
    [NSException raise:NSInvalidArgumentException format:@"Invalid NSEnergyFormatterUnit %ld", (long)unit];
    return NULL;
}

@implementation NSEnergyFormatter

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

- (BOOL)isForFoodEnergyUse
{
    return _isForFoodEnergy;
}

- (void)setForFoodEnergyUse:(BOOL)forFoodEnergyUse
{
    _isForFoodEnergy = forFoodEnergyUse;
}

- (BOOL)_usesCalories
{
    static NSSet *regions;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regions = [[NSSet alloc] initWithObjects:@"en_US", @"en_US_POSIX", @"haw_US", @"es_US", @"chr_US",
                                                 @"en_GB", @"kw_GB", @"cy_GB", @"gv_GB", nil];
    });
    return [regions containsObject:[[_numberFormatter locale] localeIdentifier]];
}

- (NSEnergyFormatterUnit)_unitFromJoules:(double)joules
{
    if ([self _usesCalories])
    {
        return (joules > 0.0 && joules <= 4184.0) ? NSEnergyFormatterUnitCalorie : NSEnergyFormatterUnitKilocalorie;
    }
    return (joules > 0.0 && joules <= 1000.0) ? NSEnergyFormatterUnitJoule : NSEnergyFormatterUnitKilojoule;
}

- (NSString *)stringFromValue:(double)value unit:(NSEnergyFormatterUnit)unit
{
    return _NSUnitFormatterJoin(_numberFormatter, _unitStyle, value, [self unitStringFromValue:value unit:unit]);
}

- (NSString *)stringFromJoules:(double)numberInJoules
{
    NSEnergyFormatterUnit unit = [self _unitFromJoules:numberInJoules];
    return [self stringFromValue:numberInJoules / NSEnergyFormatterUnitInfoFor(unit)->joules unit:unit];
}

- (NSString *)unitStringFromValue:(double)value unit:(NSEnergyFormatterUnit)unit
{
    const NSEnergyFormatterUnitInfo *info = NSEnergyFormatterUnitInfoFor(unit);
    if (_isForFoodEnergy && unit == NSEnergyFormatterUnitKilocalorie)
    {
        switch (_unitStyle)
        {
            case NSFormattingUnitStyleShort:
                return @"C";
            case NSFormattingUnitStyleMedium:
                return @"Cal";
            default:
                return @"Calories";
        }
    }
    switch (_unitStyle)
    {
        case NSFormattingUnitStyleShort:
        case NSFormattingUnitStyleMedium:
            return info->symbol;
        default:
            return value == 1.0 ? info->singular : info->plural;
    }
}

- (NSString *)unitStringFromJoules:(double)numberInJoules usedUnit:(NSEnergyFormatterUnit *)unitp
{
    NSEnergyFormatterUnit unit = [self _unitFromJoules:numberInJoules];
    if (unitp != NULL)
    {
        *unitp = unit;
    }
    return [self unitStringFromValue:numberInJoules / NSEnergyFormatterUnitInfoFor(unit)->joules unit:unit];
}

- (NSString *)stringForObjectValue:(id)obj
{
    if ([obj isKindOfClass:[NSNumber class]])
    {
        return [self stringFromJoules:[obj doubleValue]];
    }
    return nil;
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error
{
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSEnergyFormatter *copy = [[[self class] allocWithZone:zone] init];
    [copy setNumberFormatter:_numberFormatter];
    copy->_unitStyle = _unitStyle;
    copy->_isForFoodEnergy = _isForFoodEnergy;
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
            _isForFoodEnergy = [coder decodeBoolForKey:@"NS.forFoodEnergyUse"];
        }
        else
        {
            numberFormatter = [coder decodeObject];
            [coder decodeValueOfObjCType:@encode(NSInteger) at:&_unitStyle];
            [coder decodeValueOfObjCType:@encode(BOOL) at:&_isForFoodEnergy];
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
        [coder encodeBool:_isForFoodEnergy forKey:@"NS.forFoodEnergyUse"];
    }
    else
    {
        [coder encodeObject:_numberFormatter];
        [coder encodeValueOfObjCType:@encode(NSInteger) at:&_unitStyle];
        [coder encodeValueOfObjCType:@encode(BOOL) at:&_isForFoodEnergy];
    }
}

@end
