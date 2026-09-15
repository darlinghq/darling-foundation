/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel
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

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDateInterval : NSObject <NSCopying, NSSecureCoding>
{
    NSDate *_startDate;
    NSTimeInterval _duration;
}

@property (readonly, copy) NSDate *startDate;
@property (readonly, copy) NSDate *endDate;
@property (readonly) NSTimeInterval duration;

- (instancetype)init;
- (instancetype)initWithStartDate:(NSDate *)startDate duration:(NSTimeInterval)duration;
- (instancetype)initWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate;
- (nullable instancetype)initWithCoder:(NSCoder *)coder;

- (NSComparisonResult)compare:(NSDateInterval *)dateInterval;
- (BOOL)isEqualToDateInterval:(NSDateInterval *)dateInterval;
- (BOOL)intersectsDateInterval:(NSDateInterval *)dateInterval;
- (nullable NSDateInterval *)intersectionWithDateInterval:(NSDateInterval *)dateInterval;
- (BOOL)containsDate:(NSDate *)date;

@end

NS_ASSUME_NONNULL_END
