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

#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

// GUESS: the documentation pages for the class list the format accessors but do not state the default format;
// this is the strftime-style default of the legacy class.
static NSString * const NSCalendarDateDefaultFormat = @"%Y-%m-%d %H:%M:%S %z";

// The date elements are computed with a Gregorian NSCalendar whose time zone is the one of the date.
static NSCalendar *CalendarForTimeZone(NSTimeZone *timeZone)
{
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    [calendar setTimeZone:timeZone];
    return calendar;
}

@implementation NSCalendarDate

+ (id)calendarDate
{
    return [[[self alloc] init] autorelease];
}

// NSDate's versions cache one object for all classes, which can hand back a plain NSDate here; these return a new
// NSCalendarDate with the same instant as NSDate's.
+ (instancetype)distantFuture
{
    return [[[self alloc] initWithTimeIntervalSinceReferenceDate:[[NSDate distantFuture] timeIntervalSinceReferenceDate]] autorelease];
}

+ (instancetype)distantPast
{
    return [[[self alloc] initWithTimeIntervalSinceReferenceDate:[[NSDate distantPast] timeIntervalSinceReferenceDate]] autorelease];
}

+ (id)dateWithYear:(NSInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second timeZone:(NSTimeZone *)aTimeZone
{
    return [[[self alloc] initWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:aTimeZone] autorelease];
}

// The designated initializer of NSDate subclasses. GUESS: the pages do not say what the time zone and the format of
// a date made from an interval are; they are the default time zone and the default format.
// NSDate's -init and its other initializers all end here, so [super init] must not be called: it would come back.
- (id)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)seconds
{
    _referenceInterval = seconds;
    _timeZone = [[NSTimeZone defaultTimeZone] retain];
    _calendarFormat = [NSCalendarDateDefaultFormat copy];
    return self;
}

- (id)initWithYear:(NSInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second timeZone:(NSTimeZone *)aTimeZone
{
    // GUESS: the pages do not say what a nil time zone means; the default time zone is used, as for -init.
    NSTimeZone *zone = aTimeZone ? aTimeZone : [NSTimeZone defaultTimeZone];
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setYear:year];
    [components setMonth:month];
    [components setDay:day];
    [components setHour:hour];
    [components setMinute:minute];
    [components setSecond:second];
    NSDate *date = [CalendarForTimeZone(zone) dateFromComponents:components];
    [components release];
    if (date == nil)
    {
        [self release];
        return nil;
    }

    self = [self initWithTimeIntervalSinceReferenceDate:[date timeIntervalSinceReferenceDate]];
    if (self)
    {
        [_timeZone release];
        _timeZone = [zone retain];
    }
    return self;
}

- (void)dealloc
{
    [_timeZone release];
    [_calendarFormat release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSCalendarDate *copy = [[[self class] allocWithZone:zone] initWithTimeIntervalSinceReferenceDate:_referenceInterval];
    if (copy)
    {
        [copy->_timeZone release];
        copy->_timeZone = [_timeZone retain];
        [copy->_calendarFormat release];
        copy->_calendarFormat = [_calendarFormat copy];
    }
    return copy;
}

- (NSTimeInterval)timeIntervalSinceReferenceDate
{
    return _referenceInterval;
}

- (NSTimeZone *)timeZone
{
    return _timeZone;
}

// GUESS: the pages do not say what a nil time zone means; the default time zone is used, as for the factories.
- (void)setTimeZone:(NSTimeZone *)aTimeZone
{
    NSTimeZone *zone = aTimeZone ? aTimeZone : [NSTimeZone defaultTimeZone];
    if (zone != _timeZone)
    {
        [_timeZone release];
        _timeZone = [zone retain];
    }
}

- (NSString *)calendarFormat
{
    return _calendarFormat;
}

// The format is only stored: formatting and parsing with it are not implemented. GUESS: the pages do not say whether
// the string is copied; it is.
- (void)setCalendarFormat:(NSString *)format
{
    if (format != _calendarFormat)
    {
        [_calendarFormat release];
        _calendarFormat = [format copy];
    }
}

- (NSInteger)yearOfCommonEra
{
    return [CalendarForTimeZone(_timeZone) component:NSCalendarUnitYear fromDate:self];
}

- (NSInteger)monthOfYear
{
    return [CalendarForTimeZone(_timeZone) component:NSCalendarUnitMonth fromDate:self];
}

- (NSInteger)dayOfMonth
{
    return [CalendarForTimeZone(_timeZone) component:NSCalendarUnitDay fromDate:self];
}

- (NSInteger)hourOfDay
{
    return [CalendarForTimeZone(_timeZone) component:NSCalendarUnitHour fromDate:self];
}

- (NSInteger)minuteOfHour
{
    return [CalendarForTimeZone(_timeZone) component:NSCalendarUnitMinute fromDate:self];
}

- (NSInteger)secondOfMinute
{
    return [CalendarForTimeZone(_timeZone) component:NSCalendarUnitSecond fromDate:self];
}

// GUESS: the pages give no numbering; Sunday is 0 through Saturday 6, NSCalendar's weekday minus one.
- (NSInteger)dayOfWeek
{
    return [CalendarForTimeZone(_timeZone) component:NSCalendarUnitWeekday fromDate:self] - 1;
}

// GUESS: the pages give no numbering; 1 January is day 1.
- (NSInteger)dayOfYear
{
    return (NSInteger)[CalendarForTimeZone(_timeZone) ordinalityOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitYear forDate:self];
}

// GUESS: the pages do not define the epoch; 1 January of year 1 is day 1 (the days of all earlier years of the
// proleptic Gregorian calendar, plus the day of the year).
- (NSInteger)dayOfCommonEra
{
    NSInteger earlier = [self yearOfCommonEra] - 1;
    return earlier * 365 + earlier / 4 - earlier / 100 + earlier / 400 + [self dayOfYear];
}

// GUESS: the pages do not say how an overflowing unit is treated; NSCalendar's default is used, where it carries into
// the next larger unit. The result has the time zone and format of the receiver, as the pages declare an
// NSCalendarDate result but not these properties.
- (NSCalendarDate *)dateByAddingYears:(NSInteger)year months:(NSInteger)month days:(NSInteger)day hours:(NSInteger)hour minutes:(NSInteger)minute seconds:(NSInteger)second
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setYear:year];
    [components setMonth:month];
    [components setDay:day];
    [components setHour:hour];
    [components setMinute:minute];
    [components setSecond:second];
    NSDate *date = [CalendarForTimeZone(_timeZone) dateByAddingComponents:components toDate:self options:0];
    [components release];
    if (date == nil)
    {
        return nil;
    }

    NSCalendarDate *result = [[[[self class] alloc] initWithTimeIntervalSinceReferenceDate:[date timeIntervalSinceReferenceDate]] autorelease];
    [result setTimeZone:_timeZone];
    [result setCalendarFormat:_calendarFormat];
    return result;
}

@end
