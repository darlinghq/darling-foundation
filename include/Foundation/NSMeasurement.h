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

#import <Foundation/NSObject.h>
#import <Foundation/NSUnit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMeasurement<__covariant UnitType : NSUnit *> : NSObject <NSCopying, NSSecureCoding>
{
    UnitType _unit;
    double _doubleValue;
}

@property (readonly, copy) UnitType unit;
@property (readonly) double doubleValue;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDoubleValue:(double)doubleValue unit:(UnitType)unit NS_DESIGNATED_INITIALIZER;

// YES if the unit is of the same dimension as the measurement's.
- (BOOL)canBeConvertedToUnit:(NSUnit *)unit;
// Raises NSInvalidArgumentException if the unit cannot be converted to.
- (NSMeasurement *)measurementByConvertingToUnit:(NSUnit *)unit;

// With the same unit the result has it; otherwise both are converted to the base unit of the
// dimension. Raises NSInvalidArgumentException for units of different dimensions.
- (NSMeasurement<UnitType> *)measurementByAddingMeasurement:(NSMeasurement<UnitType> *)measurement;
- (NSMeasurement<UnitType> *)measurementBySubtractingMeasurement:(NSMeasurement<UnitType> *)measurement;

@end

NS_ASSUME_NONNULL_END
