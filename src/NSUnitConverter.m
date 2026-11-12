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

#import <Foundation/NSUnit.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSValue.h>
#import "NSUnitInternal.h"

@implementation NSUnitConverter

// QUIRK: the abstract converter does not raise from either conversion method; it leaves the
// value as it is. Not documented. Evidence: black-box observation on macOS 26.7.3 (tier 2),
// MC26.15 (the calls do not raise; the returned value was not recorded, the identity is our
// choice). Test: test_quirk_abstract_converter_does_not_raise in tests/nsunit-nsmeasurement.m
- (double)baseUnitValueFromValue:(double)value
{
    return value;
}

- (double)valueFromBaseUnitValue:(double)baseUnitValue
{
    return baseUnitValue;
}

@end

// For the units that are the reciprocal of a base unit's value, like distance per volume against
// volume per distance: baseValue = coefficient / value.
@implementation NSUnitConverterReciprocal

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoefficient:(double)coefficient
{
    self = [super init];
    if (self != nil)
        _coefficient = coefficient;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil)
    {
        if (![coder containsValueForKey:@"NS.coefficient"])
        {
            [self release];
            [NSException raise:NSInvalidUnarchiveOperationException format:@"A unit converter has no coefficient"];
        }
        _coefficient = [coder decodeDoubleForKey:@"NS.coefficient"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_coefficient forKey:@"NS.coefficient"];
}

- (double)baseUnitValueFromValue:(double)value
{
    return _coefficient / value;
}

- (double)valueFromBaseUnitValue:(double)baseUnitValue
{
    return _coefficient / baseUnitValue;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    return [object isMemberOfClass:[self class]] && ((NSUnitConverterReciprocal *) object)->_coefficient == _coefficient;
}

- (NSUInteger)hash
{
    return [[NSNumber numberWithDouble:_coefficient] hash];
}

@end
