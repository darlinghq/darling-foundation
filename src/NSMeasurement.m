/*
 This file is part of Darling.

 Copyright (C) 2026 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/NSMeasurement.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSValue.h>

// Whether the units are of the same dimension: the units of the same NSDimension subclass, or of
// subclasses that share a base unit. Other units are only convertible to themselves.
static BOOL unitsAreConvertible(NSUnit *from, NSUnit *to)
{
    if ([from isEqual:to])
        return YES;
    if (![from isKindOfClass:[NSDimension class]] || ![to isKindOfClass:[NSDimension class]])
        return NO;

    Class fromClass = [from class], toClass = [to class];
    if (fromClass == toClass)
        return YES;
    if (fromClass == [NSDimension class] || toClass == [NSDimension class])
        return NO;
    return [[fromClass baseUnit] isEqual:[toClass baseUnit]];
}

@implementation NSMeasurement

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithDoubleValue:(double)doubleValue unit:(NSUnit *)unit
{
    self = [super init];
    if (self != nil)
    {
        _doubleValue = doubleValue;
        _unit = [unit copy];
    }
    return self;
}

- (void)dealloc
{
    [_unit release];
    [super dealloc];
}

- (NSUnit *)unit
{
    return _unit;
}

- (double)doubleValue
{
    return _doubleValue;
}

- (BOOL)canBeConvertedToUnit:(NSUnit *)unit
{
    return unit != nil && unitsAreConvertible(_unit, unit);
}

- (NSMeasurement *)measurementByConvertingToUnit:(NSUnit *)unit
{
    if (![self canBeConvertedToUnit:unit])
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"A measurement in %@ cannot be converted to %@", [_unit symbol], [unit symbol]];
    }
    if ([_unit isEqual:unit])
        return [[[[self class] alloc] initWithDoubleValue:_doubleValue unit:unit] autorelease];

    NSDimension *from = (NSDimension *) _unit;
    NSDimension *to = (NSDimension *) unit;
    double base = [[from converter] baseUnitValueFromValue:_doubleValue];
    return [[[[self class] alloc] initWithDoubleValue:[[to converter] valueFromBaseUnitValue:base] unit:unit] autorelease];
}

// The measurement in the unit of the receiver if the units are equal, otherwise in the base unit
// of their dimension.
- (NSMeasurement *)combinedWithMeasurement:(NSMeasurement *)other subtracting:(BOOL)subtracting
{
    if (![self canBeConvertedToUnit:[other unit]])
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"Measurements in %@ and %@ cannot be combined", [_unit symbol], [[other unit] symbol]];
    }

    NSUnit *unit = _unit;
    double left = _doubleValue, right = [other doubleValue];
    if (![_unit isEqual:[other unit]])
    {
        NSDimension *dimension = (NSDimension *) _unit;
        unit = [[dimension class] baseUnit];
        left = [[dimension converter] baseUnitValueFromValue:left];
        right = [[(NSDimension *) [other unit] converter] baseUnitValueFromValue:right];
    }
    return [[[[self class] alloc] initWithDoubleValue:subtracting ? left - right : left + right unit:unit] autorelease];
}

- (NSMeasurement *)measurementByAddingMeasurement:(NSMeasurement *)measurement
{
    return [self combinedWithMeasurement:measurement subtracting:NO];
}

- (NSMeasurement *)measurementBySubtractingMeasurement:(NSMeasurement *)measurement
{
    return [self combinedWithMeasurement:measurement subtracting:YES];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSUnit *unit = [coder decodeObjectOfClass:[NSUnit class] forKey:@"NS.unit"];
    if (unit == nil || ![coder containsValueForKey:@"NS.value"])
    {
        [self release];
        [NSException raise:NSInvalidUnarchiveOperationException format:@"A measurement has no value or no unit"];
    }
    return [self initWithDoubleValue:[coder decodeDoubleForKey:@"NS.value"] unit:unit];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_doubleValue forKey:@"NS.value"];
    [coder encodeObject:_unit forKey:@"NS.unit"];
}

// Equal if the unit is the same and so is the value, or if the units are of one dimension and the
// values are equal in the base unit.
- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSMeasurement class]])
        return NO;

    NSMeasurement *other = object;
    if ([_unit isEqual:other->_unit])
        return _doubleValue == other->_doubleValue;
    if (![self canBeConvertedToUnit:other->_unit])
        return NO;
    return [[(NSDimension *) _unit converter] baseUnitValueFromValue:_doubleValue]
        == [[(NSDimension *) other->_unit converter] baseUnitValueFromValue:other->_doubleValue];
}

- (NSUInteger)hash
{
    if ([_unit isKindOfClass:[NSDimension class]] && [(NSDimension *) _unit converter] != nil)
    {
        double base = [[(NSDimension *) _unit converter] baseUnitValueFromValue:_doubleValue];
        // -0.0 is equal to 0.0
        return [[NSNumber numberWithDouble:base == 0.0 ? 0.0 : base] hash];
    }
    return [[NSNumber numberWithDouble:_doubleValue == 0.0 ? 0.0 : _doubleValue] hash] ^ [_unit hash];
}

@end
