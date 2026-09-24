/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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
#import <CoreFoundation/CFDateFormatter.h>

@class NSDate, NSTimeZone;

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSISO8601DateFormatOptions) {
    NSISO8601DateFormatWithYear = kCFISO8601DateFormatWithYear,
    NSISO8601DateFormatWithMonth = kCFISO8601DateFormatWithMonth,
    NSISO8601DateFormatWithWeekOfYear = kCFISO8601DateFormatWithWeekOfYear,
    NSISO8601DateFormatWithDay = kCFISO8601DateFormatWithDay,
    NSISO8601DateFormatWithTime = kCFISO8601DateFormatWithTime,
    NSISO8601DateFormatWithTimeZone = kCFISO8601DateFormatWithTimeZone,
    NSISO8601DateFormatWithSpaceBetweenDateAndTime = kCFISO8601DateFormatWithSpaceBetweenDateAndTime,
    NSISO8601DateFormatWithDashSeparatorInDate = kCFISO8601DateFormatWithDashSeparatorInDate,
    NSISO8601DateFormatWithColonSeparatorInTime = kCFISO8601DateFormatWithColonSeparatorInTime,
    NSISO8601DateFormatWithColonSeparatorInTimeZone = kCFISO8601DateFormatWithColonSeparatorInTimeZone,
    NSISO8601DateFormatWithFractionalSeconds API_AVAILABLE(macos(10.13), ios(11.0), watchos(4.0), tvos(11.0)) = kCFISO8601DateFormatWithFractionalSeconds,
    NSISO8601DateFormatWithFullDate = kCFISO8601DateFormatWithFullDate,
    NSISO8601DateFormatWithFullTime = kCFISO8601DateFormatWithFullTime,
    NSISO8601DateFormatWithInternetDateTime = kCFISO8601DateFormatWithInternetDateTime,
};

@interface NSISO8601DateFormatter : NSFormatter <NSSecureCoding> {
@private
    struct __CFDateFormatter *_formatter;
    NSTimeZone *_timeZone;
    NSISO8601DateFormatOptions _formatOptions;
}

@property (null_resettable, copy) NSTimeZone *timeZone;
@property NSISO8601DateFormatOptions formatOptions;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (NSString *)stringFromDate:(NSDate *)date;
- (nullable NSDate *)dateFromString:(NSString *)string;
+ (NSString *)stringFromDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone formatOptions:(NSISO8601DateFormatOptions)formatOptions;

@end

NS_ASSUME_NONNULL_END
