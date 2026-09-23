/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

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

#import <Foundation/NSFormatter.h>

@class NSNumberFormatter;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSEnergyFormatterUnit) {
    NSEnergyFormatterUnitJoule = 11,
    NSEnergyFormatterUnitKilojoule = 14,
    NSEnergyFormatterUnitCalorie = (7 << 8) + 1,
    NSEnergyFormatterUnitKilocalorie = (7 << 8) + 2,
};

@interface NSEnergyFormatter : NSFormatter
{
    NSNumberFormatter *_numberFormatter;
    NSFormattingUnitStyle _unitStyle;
    BOOL _isForFoodEnergy;
}

@property (null_resettable, copy) NSNumberFormatter *numberFormatter;
@property NSFormattingUnitStyle unitStyle;
@property (getter=isForFoodEnergyUse) BOOL forFoodEnergyUse;

- (NSString *)stringFromValue:(double)value unit:(NSEnergyFormatterUnit)unit;
- (NSString *)stringFromJoules:(double)numberInJoules;
- (NSString *)unitStringFromValue:(double)value unit:(NSEnergyFormatterUnit)unit;
- (NSString *)unitStringFromJoules:(double)numberInJoules usedUnit:(nullable NSEnergyFormatterUnit *)unitp;
- (BOOL)getObjectValue:(out id _Nullable * _Nullable)obj forString:(NSString *)string errorDescription:(out NSString * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
