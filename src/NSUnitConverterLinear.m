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

@implementation NSUnitConverterLinear

@synthesize coefficient = _coefficient;
@synthesize constant = _constant;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoefficient:(double)coefficient
{
    return [self initWithCoefficient:coefficient constant:0.0];
}

- (instancetype)initWithCoefficient:(double)coefficient constant:(double)constant
{
    self = [super init];
    if (self != nil)
    {
        _coefficient = coefficient;
        _constant = constant;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (![coder containsValueForKey:@"NS.coefficient"])
    {
        [self release];
        [NSException raise:NSInvalidUnarchiveOperationException format:@"A unit converter has no coefficient"];
    }
    return [self initWithCoefficient:[coder decodeDoubleForKey:@"NS.coefficient"]
                            constant:[coder decodeDoubleForKey:@"NS.constant"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDouble:_coefficient forKey:@"NS.coefficient"];
    [coder encodeDouble:_constant forKey:@"NS.constant"];
}

- (double)baseUnitValueFromValue:(double)value
{
    return value * _coefficient + _constant;
}

- (double)valueFromBaseUnitValue:(double)baseUnitValue
{
    return (baseUnitValue - _constant) / _coefficient;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isMemberOfClass:[self class]])
        return NO;
    NSUnitConverterLinear *other = object;
    return other->_coefficient == _coefficient && other->_constant == _constant;
}

- (NSUInteger)hash
{
    return [[NSNumber numberWithDouble:_coefficient] hash] ^ [[NSNumber numberWithDouble:_constant] hash];
}

@end
