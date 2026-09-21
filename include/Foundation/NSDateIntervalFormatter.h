/* Definition of class NSDateIntervalFormatter
   Copyright (C) 2019 Free Software Foundation, Inc.

   By: heron
   Date: Wed Oct  9 16:23:55 EDT 2019

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import <Foundation/NSFormatter.h>

@class NSCalendar, NSDate, NSDateInterval, NSLocale, NSString, NSTimeZone;

typedef NS_ENUM(NSUInteger, NSDateIntervalFormatterStyle) {
    NSDateIntervalFormatterNoStyle     = 0,
    NSDateIntervalFormatterShortStyle  = 1,
    NSDateIntervalFormatterMediumStyle = 2,
    NSDateIntervalFormatterLongStyle   = 3,
    NSDateIntervalFormatterFullStyle   = 4
};

// Fidelity note: this formats each endpoint with NSDateFormatter and joins them
// with " - ". macOS elides components the two endpoints share ("Jan 1 - 3, 2024")
// and uses an en dash. Both endpoints are always rendered truthfully; only the
// joining and the eliding differ.
@interface NSDateIntervalFormatter : NSFormatter
{
    NSLocale *_locale;
    NSCalendar *_calendar;
    NSTimeZone *_timeZone;
    NSString *_dateTemplate;
    NSDateIntervalFormatterStyle _dateStyle;
    NSDateIntervalFormatterStyle _timeStyle;
}

- (NSLocale *)locale;
- (void)setLocale:(NSLocale *)locale;
- (NSCalendar *)calendar;
- (void)setCalendar:(NSCalendar *)calendar;
- (NSTimeZone *)timeZone;
- (void)setTimeZone:(NSTimeZone *)timeZone;
- (NSString *)dateTemplate;
- (void)setDateTemplate:(NSString *)dateTemplate;
- (NSDateIntervalFormatterStyle)dateStyle;
- (void)setDateStyle:(NSDateIntervalFormatterStyle)dateStyle;
- (NSDateIntervalFormatterStyle)timeStyle;
- (void)setTimeStyle:(NSDateIntervalFormatterStyle)timeStyle;

- (NSString *)stringFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate;
- (NSString *)stringFromDateInterval:(NSDateInterval *)dateInterval;

@end
