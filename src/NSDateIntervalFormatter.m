/* Implementation of class NSDateIntervalFormatter
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

   Adapted for Darling: GNUstep's retain/release macros expanded to plain
   Objective-C message sends, which is this project's idiom.
*/

#import <Foundation/NSCalendar.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSDateInterval.h>
#import <Foundation/NSDateIntervalFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

// Maps this class's style enum onto NSDateFormatter's. The two share their
// numeric values, but the mapping is written out so a future divergence in
// either enum is a compile error here rather than a silently wrong style.
static NSDateFormatterStyle NSDateFormatterStyleFromIntervalStyle(NSDateIntervalFormatterStyle style)
{
    switch (style)
    {
        case NSDateIntervalFormatterShortStyle:  return NSDateFormatterShortStyle;
        case NSDateIntervalFormatterMediumStyle: return NSDateFormatterMediumStyle;
        case NSDateIntervalFormatterLongStyle:   return NSDateFormatterLongStyle;
        case NSDateIntervalFormatterFullStyle:   return NSDateFormatterFullStyle;
        case NSDateIntervalFormatterNoStyle:     return NSDateFormatterNoStyle;
    }
    return NSDateFormatterNoStyle;
}

@implementation NSDateIntervalFormatter

- (void)dealloc
{
    [_locale release];
    [_calendar release];
    [_timeZone release];
    [_dateTemplate release];
    [super dealloc];
}

- (NSLocale *)locale
{
    return _locale;
}

- (void)setLocale:(NSLocale *)locale
{
    id old = _locale;
    _locale = [locale copy];
    [old release];
}

- (NSCalendar *)calendar
{
    return _calendar;
}

- (void)setCalendar:(NSCalendar *)calendar
{
    id old = _calendar;
    _calendar = [calendar copy];
    [old release];
}

- (NSTimeZone *)timeZone
{
    return _timeZone;
}

- (void)setTimeZone:(NSTimeZone *)timeZone
{
    id old = _timeZone;
    _timeZone = [timeZone copy];
    [old release];
}

- (NSString *)dateTemplate
{
    return _dateTemplate;
}

- (void)setDateTemplate:(NSString *)dateTemplate
{
    id old = _dateTemplate;
    _dateTemplate = [dateTemplate copy];
    [old release];
}

- (NSDateIntervalFormatterStyle)dateStyle
{
    return _dateStyle;
}

- (void)setDateStyle:(NSDateIntervalFormatterStyle)dateStyle
{
    _dateStyle = dateStyle;
}

- (NSDateIntervalFormatterStyle)timeStyle
{
    return _timeStyle;
}

- (void)setTimeStyle:(NSDateIntervalFormatterStyle)timeStyle
{
    _timeStyle = timeStyle;
}

- (NSString *)stringFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate
{
    NSDate *start = fromDate;
    NSDate *end = toDate;
    NSDateInterval *interval;
    NSString *result;

    if ([toDate compare:fromDate] == NSOrderedAscending)
    {
        start = toDate;
        end = fromDate;
    }

    interval = [[NSDateInterval alloc] initWithStartDate:start endDate:end];
    result = [self stringFromDateInterval:interval];
    [interval release];
    return result;
}

- (NSString *)stringFromDateInterval:(NSDateInterval *)dateInterval
{
    NSDateFormatter *formatter;
    NSString *result;

    if (dateInterval == nil)
    {
        return nil;
    }

    formatter = [[NSDateFormatter alloc] init];

    if (_locale != nil)
    {
        [formatter setLocale:_locale];
    }
    if (_calendar != nil)
    {
        [formatter setCalendar:_calendar];
    }
    if (_timeZone != nil)
    {
        [formatter setTimeZone:_timeZone];
    }

    if ([_dateTemplate length] > 0)
    {
        [formatter setDateFormat:[NSDateFormatter dateFormatFromTemplate:_dateTemplate
                                                                 options:0
                                                                  locale:_locale]];
    }
    else
    {
        [formatter setDateStyle:NSDateFormatterStyleFromIntervalStyle(_dateStyle)];
        [formatter setTimeStyle:NSDateFormatterStyleFromIntervalStyle(_timeStyle)];
    }

    result = [NSString stringWithFormat:@"%@ - %@",
                                        [formatter stringFromDate:[dateInterval startDate]],
                                        [formatter stringFromDate:[dateInterval endDate]]];
    [formatter release];
    return result;
}

- (NSString *)stringForObjectValue:(id)obj
{
    if ([obj isKindOfClass:[NSDateInterval class]])
    {
        return [self stringFromDateInterval:obj];
    }
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self != nil)
    {
        if ([coder allowsKeyedCoding])
        {
            _locale = [[coder decodeObjectForKey:@"NS.locale"] retain];
            _calendar = [[coder decodeObjectForKey:@"NS.calendar"] retain];
            _timeZone = [[coder decodeObjectForKey:@"NS.timeZone"] retain];
            _dateTemplate = [[coder decodeObjectForKey:@"NS.dateTemplate"] retain];
            _dateStyle = [coder decodeIntegerForKey:@"NS.dateStyle"];
            _timeStyle = [coder decodeIntegerForKey:@"NS.timeStyle"];
        }
        else
        {
            [coder decodeValueOfObjCType:@encode(id) at:&_locale];
            [coder decodeValueOfObjCType:@encode(id) at:&_calendar];
            [coder decodeValueOfObjCType:@encode(id) at:&_timeZone];
            [coder decodeValueOfObjCType:@encode(id) at:&_dateTemplate];
            [coder decodeValueOfObjCType:@encode(NSUInteger) at:&_dateStyle];
            [coder decodeValueOfObjCType:@encode(NSUInteger) at:&_timeStyle];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    if ([coder allowsKeyedCoding])
    {
        [coder encodeObject:_locale forKey:@"NS.locale"];
        [coder encodeObject:_calendar forKey:@"NS.calendar"];
        [coder encodeObject:_timeZone forKey:@"NS.timeZone"];
        [coder encodeObject:_dateTemplate forKey:@"NS.dateTemplate"];
        [coder encodeInteger:_dateStyle forKey:@"NS.dateStyle"];
        [coder encodeInteger:_timeStyle forKey:@"NS.timeStyle"];
    }
    else
    {
        [coder encodeValueOfObjCType:@encode(id) at:&_locale];
        [coder encodeValueOfObjCType:@encode(id) at:&_calendar];
        [coder encodeValueOfObjCType:@encode(id) at:&_timeZone];
        [coder encodeValueOfObjCType:@encode(id) at:&_dateTemplate];
        [coder encodeValueOfObjCType:@encode(NSUInteger) at:&_dateStyle];
        [coder encodeValueOfObjCType:@encode(NSUInteger) at:&_timeStyle];
    }
}

@end
