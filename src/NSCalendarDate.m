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
#import <Foundation/NSCoder.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>

#import "NSExternals.h"

// The default of the calendar format that the class page documents.
static NSString * const NSCalendarDateDefaultFormat = @"%Y-%m-%d %H:%M:%S %z";

// Keys of the keyed archive, as macOS writes them (observed on macOS 10.14.4 and 26.7.3: the interval under "NS.time",
// the zone under "NS.timezone" and the format under "NS.format").
static NSString * const NSCalendarDateTimeKey = @"NS.time";
static NSString * const NSCalendarDateTimeZoneKey = @"NS.timezone";
static NSString * const NSCalendarDateFormatKey = @"NS.format";

// The calendar is the proleptic Gregorian one (observed on macOS: year 1500 and year 1 have no Julian shift and the
// year before 1 is 0), so the elements are computed here and not through NSCalendar, whose Gregorian calendar switches
// to the Julian rules before 1582. Days are counted from 0000-01-01.

static NSInteger FloorDivide(NSInteger a, NSInteger b)
{
    NSInteger q = a / b;
    return (a % b != 0 && ((a < 0) != (b < 0))) ? q - 1 : q;
}

// Days from 0000-01-01 to January 1 of the year: 365 per year plus a day for each leap year in 0 ... year - 1.
static NSInteger DaysToYear(NSInteger year)
{
    return 365 * year + FloorDivide(year + 3, 4) - FloorDivide(year + 99, 100) + FloorDivide(year + 399, 400);
}

static BOOL IsLeapYear(NSInteger year)
{
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}

static NSInteger DaysInMonth(NSInteger year, NSInteger month)
{
    static const NSInteger lengths[] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
    return month == 2 && IsLeapYear(year) ? 29 : lengths[month - 1];
}

static NSInteger DaysBeforeMonth(NSInteger year, NSInteger month)
{
    NSInteger days = 0;
    for (NSInteger m = 1; m < month; m++)
    {
        days += DaysInMonth(year, m);
    }
    return days;
}

// The days from 0000-01-01 of a date whose month and day may be out of range: they carry into the larger unit.
static NSInteger DaysFromYMD(NSInteger year, NSInteger month, NSInteger day)
{
    year += FloorDivide(month - 1, 12);
    month = month - 1 - 12 * FloorDivide(month - 1, 12) + 1;
    return DaysToYear(year) + DaysBeforeMonth(year, month) + day - 1;
}

typedef struct
{
    NSInteger year, month, day, hour, minute, second, dayOfWeek, dayOfYear, days;
    NSInteger milliseconds;
} CalendarElements;

// The seconds between 0000-01-01 00:00:00 and the reference date, 2001-01-01 00:00:00.
static NSTimeInterval ReferenceSeconds(void)
{
    return (NSTimeInterval)DaysToYear(2001) * 86400.0;
}

static CalendarElements ElementsOfLocalSeconds(NSTimeInterval localSinceReference)
{
    NSTimeInterval total = localSinceReference + ReferenceSeconds();
    NSTimeInterval wholeDays = floor(total / 86400.0);
    NSTimeInterval inDay = total - wholeDays * 86400.0;
    CalendarElements e;
    e.days = (NSInteger)wholeDays;
    NSInteger secondOfDay = (NSInteger)floor(inDay);
    e.milliseconds = (NSInteger)((inDay - secondOfDay) * 1000.0);
    e.hour = secondOfDay / 3600;
    e.minute = (secondOfDay / 60) % 60;
    e.second = secondOfDay % 60;
    e.dayOfWeek = ((e.days + 6) % 7 + 7) % 7;
    NSInteger year = FloorDivide(e.days * 400, 146097);
    while (DaysToYear(year) > e.days)
    {
        year--;
    }
    while (DaysToYear(year + 1) <= e.days)
    {
        year++;
    }
    e.year = year;
    e.dayOfYear = e.days - DaysToYear(year) + 1;
    NSInteger month = 1;
    NSInteger left = e.dayOfYear;
    while (month < 12 && left > DaysInMonth(year, month))
    {
        left -= DaysInMonth(year, month);
        month++;
    }
    e.month = month;
    e.day = left;
    return e;
}

// The date of local wall-clock time (seconds since the reference date, counted in the zone's local time). The offset
// of the zone is taken at the instant found with the first guess, so that the wall-clock time before and after a
// change of the offset resolves to a single instant.
static NSTimeInterval InstantOfLocalSeconds(NSTimeInterval local, NSTimeZone *zone)
{
    NSTimeInterval guess = local - [zone secondsFromGMTForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:local]];
    return local - [zone secondsFromGMTForDate:[NSDate dateWithTimeIntervalSinceReferenceDate:guess]];
}

static NSTimeInterval LocalSecondsOf(NSInteger year, NSInteger month, NSInteger day, NSInteger hour, NSInteger minute, NSInteger second)
{
    return (NSTimeInterval)(DaysFromYMD(year, month, day)) * 86400.0 - ReferenceSeconds() + hour * 3600.0 + minute * 60.0 + second;
}

static NSString *PaddedNumber(NSInteger value, NSInteger defaultWidth, NSString *widthSpec)
{
    NSInteger width = defaultWidth;
    char pad = '0';
    if ([widthSpec length] > 0)
    {
        width = [widthSpec integerValue];
        // An explicit width pads with spaces, or with zeros when the width starts with one; the number then has no
        // default padding (observed on macOS 10.14.4; macOS 26.7.3 ignores the width).
        pad = [widthSpec characterAtIndex:0] == '0' ? '0' : ' ';
    }
    NSString *digits = [NSString stringWithFormat:@"%ld", (long)(value < 0 ? -value : value)];
    NSMutableString *result = [NSMutableString string];
    if (value < 0)
    {
        [result appendString:@"-"];
    }
    for (NSInteger i = [digits length] + (value < 0 ? 1 : 0); i < width; i++)
    {
        [result appendFormat:@"%c", pad];
    }
    [result appendString:digits];
    return result;
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

// The designated initializer of NSDate subclasses. The time zone and the format of a date made from an interval are
// the default time zone and the default format (observed on macOS 10.14.4 and 26.7.3).
// NSDate's -init and its other initializers all end here, so [super init] must not be called: it would come back.
- (id)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)seconds
{
    _timeIntervalSinceReferenceDate = seconds;
    _timeZone = [[NSTimeZone defaultTimeZone] retain];
    _formatString = [NSCalendarDateDefaultFormat copy];
    return self;
}

// A nil time zone is the default time zone; units out of range carry into the next larger one (observed on macOS).
- (id)initWithYear:(NSInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second timeZone:(NSTimeZone *)aTimeZone
{
    NSTimeZone *zone = aTimeZone ? aTimeZone : [NSTimeZone defaultTimeZone];
    NSTimeInterval local = LocalSecondsOf(year, month, day, hour, minute, second);
    self = [self initWithTimeIntervalSinceReferenceDate:InstantOfLocalSeconds(local, zone)];
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
    [_formatString release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSCalendarDate *copy = [[[self class] allocWithZone:zone] initWithTimeIntervalSinceReferenceDate:_timeIntervalSinceReferenceDate];
    if (copy)
    {
        [copy->_timeZone release];
        copy->_timeZone = [_timeZone retain];
        [copy->_formatString release];
        copy->_formatString = [_formatString copy];
    }
    return copy;
}

- (Class)classForCoder
{
    return [NSCalendarDate class];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSTimeInterval interval = 0;
    NSTimeZone *zone = nil;
    NSString *format = nil;
    if ([coder allowsKeyedCoding])
    {
        interval = [coder decodeDoubleForKey:NSCalendarDateTimeKey];
        zone = [coder decodeObjectOfClass:[NSTimeZone class] forKey:NSCalendarDateTimeZoneKey];
        format = [coder decodeObjectOfClass:[NSString class] forKey:NSCalendarDateFormatKey];
    }
    else
    {
        [coder decodeValueOfObjCType:@encode(NSTimeInterval) at:&interval];
        zone = [coder decodeObject];
        format = [coder decodeObject];
    }
    self = [self initWithTimeIntervalSinceReferenceDate:interval];
    if (self)
    {
        if (zone != nil)
        {
            [self setTimeZone:zone];
        }
        if (format != nil)
        {
            [self setCalendarFormat:format];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding])
    {
        [coder encodeDouble:_timeIntervalSinceReferenceDate forKey:NSCalendarDateTimeKey];
        [coder encodeObject:_timeZone forKey:NSCalendarDateTimeZoneKey];
        [coder encodeObject:_formatString forKey:NSCalendarDateFormatKey];
    }
    else
    {
        [coder encodeValueOfObjCType:@encode(NSTimeInterval) at:&_timeIntervalSinceReferenceDate];
        [coder encodeObject:_timeZone];
        [coder encodeObject:_formatString];
    }
}

- (NSTimeInterval)timeIntervalSinceReferenceDate
{
    return _timeIntervalSinceReferenceDate;
}

// The result is a new date with the default time zone and format, as on macOS (observed), not a plain NSDate.
- (id)dateByAddingTimeInterval:(NSTimeInterval)seconds
{
    return [[[[self class] alloc] initWithTimeIntervalSinceReferenceDate:_timeIntervalSinceReferenceDate + seconds] autorelease];
}

- (NSTimeZone *)timeZone
{
    return _timeZone;
}

// A nil time zone is the default time zone (observed).
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
    return _formatString;
}

// A nil format is the default format (observed).
- (void)setCalendarFormat:(NSString *)format
{
    NSString *newFormat = format ? format : NSCalendarDateDefaultFormat;
    if (newFormat != _formatString)
    {
        [_formatString release];
        _formatString = [newFormat copy];
    }
}

- (CalendarElements)elements
{
    NSTimeInterval offset = [_timeZone secondsFromGMTForDate:self];
    return ElementsOfLocalSeconds(_timeIntervalSinceReferenceDate + offset);
}

- (NSInteger)yearOfCommonEra
{
    return [self elements].year;
}

- (NSInteger)monthOfYear
{
    return [self elements].month;
}

- (NSInteger)dayOfMonth
{
    return [self elements].day;
}

- (NSInteger)hourOfDay
{
    return [self elements].hour;
}

- (NSInteger)minuteOfHour
{
    return [self elements].minute;
}

- (NSInteger)secondOfMinute
{
    return [self elements].second;
}

// Sunday is 0 through Saturday 6 (observed).
- (NSInteger)dayOfWeek
{
    return [self elements].dayOfWeek;
}

// 1 January is day 1 (observed).
- (NSInteger)dayOfYear
{
    return [self elements].dayOfYear;
}

// 1 January of year 1 is day 1 (observed).
- (NSInteger)dayOfCommonEra
{
    return [self elements].days - DaysToYear(1) + 1;
}

// The units are added to the date's elements in the zone of the date. Years and months carry the day of the month
// into the shorter month (31 January plus one month is 29 February in 2024); days keep the time of day; hours, minutes
// and seconds are elapsed time. The result has the time zone and format of the receiver. Observed on macOS 10.14.4
// and 26.7.3 (probe cal2.m of batch11b).
- (NSCalendarDate *)dateByAddingYears:(NSInteger)year months:(NSInteger)month days:(NSInteger)day hours:(NSInteger)hour minutes:(NSInteger)minute seconds:(NSInteger)second
{
    CalendarElements e = [self elements];
    NSInteger totalMonths = e.year * 12 + (e.month - 1) + year * 12 + month;
    NSInteger newYear = FloorDivide(totalMonths, 12);
    NSInteger newMonth = totalMonths - newYear * 12 + 1;
    NSInteger newDay = e.day;
    if (newDay > DaysInMonth(newYear, newMonth))
    {
        newDay = DaysInMonth(newYear, newMonth);
    }
    NSTimeInterval local = LocalSecondsOf(newYear, newMonth, newDay + day, e.hour, e.minute, e.second);
    NSTimeInterval instant = InstantOfLocalSeconds(local, _timeZone) + hour * 3600.0 + minute * 60.0 + second;
    NSCalendarDate *result = [[[[self class] alloc] initWithTimeIntervalSinceReferenceDate:instant + (_timeIntervalSinceReferenceDate - floor(_timeIntervalSinceReferenceDate))] autorelease];
    [result setTimeZone:_timeZone];
    [result setCalendarFormat:_formatString];
    return result;
}

// The specifiers of the calendar format, as macOS 10.14.4 and 26.7.3 give them (the english names and layout whatever
// the locale): %% %A %a %B %b %c %d %e %F (milliseconds, 3 digits) %H %I %i (12-hour clock with 0 instead of 12) %j %M %m %p %S %w
// %X %x %Y %y %Z (the time zone name) %z. A digit string before a specifier gives a width (see PaddedNumber), an unknown
// specifier gives "?" and the character after it is kept, a lone "%" at the end gives nothing.
- (NSString *)descriptionWithCalendarFormat:(NSString *)format
{
    static NSString * const days[] = {@"Sunday", @"Monday", @"Tuesday", @"Wednesday", @"Thursday", @"Friday", @"Saturday"};
    static NSString * const months[] = {@"January", @"February", @"March", @"April", @"May", @"June", @"July", @"August",
                                        @"September", @"October", @"November", @"December"};
    if (format == nil)
    {
        return @"";
    }
    CalendarElements e = [self elements];
    NSString *zoneName = [_timeZone name];
    NSInteger offset = (NSInteger)[_timeZone secondsFromGMTForDate:self];
    NSInteger hour12 = e.hour % 12 == 0 ? 12 : e.hour % 12;
    NSMutableString *out = [NSMutableString string];
    NSUInteger length = [format length];
    for (NSUInteger i = 0; i < length; i++)
    {
        unichar c = [format characterAtIndex:i];
        if (c != '%')
        {
            [out appendFormat:@"%C", c];
            continue;
        }
        NSUInteger widthStart = i + 1;
        NSUInteger j = widthStart;
        while (j < length && [format characterAtIndex:j] >= '0' && [format characterAtIndex:j] <= '9')
        {
            j++;
        }
        if (j >= length)
        {
            break;
        }
        NSString *width = [format substringWithRange:NSMakeRange(widthStart, j - widthStart)];
        unichar spec = [format characterAtIndex:j];
        i = j;
        switch (spec)
        {
            case '%': [out appendString:@"%"]; break;
            case 'A': [out appendString:days[e.dayOfWeek]]; break;
            case 'a': [out appendString:[days[e.dayOfWeek] substringToIndex:3]]; break;
            case 'B': [out appendString:months[e.month - 1]]; break;
            case 'b': [out appendString:[months[e.month - 1] substringToIndex:3]]; break;
            case 'c': [out appendFormat:@"%@ %@ %@ %@ %@ %@", [days[e.dayOfWeek] substringToIndex:3], [months[e.month - 1] substringToIndex:3],
                                        PaddedNumber(e.day, 2, nil), [NSString stringWithFormat:@"%@:%@:%@", PaddedNumber(e.hour, 2, nil), PaddedNumber(e.minute, 2, nil), PaddedNumber(e.second, 2, nil)],
                                        zoneName, PaddedNumber(e.year, 0, nil)]; break;
            case 'd': [out appendString:PaddedNumber(e.day, 2, width)]; break;
            case 'e': [out appendString:PaddedNumber(e.day, 0, width)]; break;
            case 'F': [out appendString:PaddedNumber(e.milliseconds, 3, width)]; break;
            case 'H': [out appendString:PaddedNumber(e.hour, 2, width)]; break;
            case 'I': [out appendString:PaddedNumber(hour12, 2, width)]; break;
            case 'i': [out appendString:PaddedNumber(e.hour % 12, 2, width)]; break;
            case 'j': [out appendString:PaddedNumber(e.dayOfYear, 3, width)]; break;
            case 'M': [out appendString:PaddedNumber(e.minute, 2, width)]; break;
            case 'm': [out appendString:PaddedNumber(e.month, 2, width)]; break;
            case 'p': [out appendString:e.hour < 12 ? @"AM" : @"PM"]; break;
            case 'S': [out appendString:PaddedNumber(e.second, 2, width)]; break;
            case 'w': [out appendString:PaddedNumber(e.dayOfWeek, 0, width)]; break;
            case 'X': [out appendFormat:@"%@:%@:%@ %@", PaddedNumber(e.hour, 2, nil), PaddedNumber(e.minute, 2, nil), PaddedNumber(e.second, 2, nil), zoneName]; break;
            case 'x': [out appendFormat:@"%@ %@ %@ %@", [days[e.dayOfWeek] substringToIndex:3], [months[e.month - 1] substringToIndex:3], PaddedNumber(e.day, 2, nil), PaddedNumber(e.year, 0, nil)]; break;
            case 'Y': [out appendString:PaddedNumber(e.year, 0, width)]; break;
            case 'y': [out appendString:PaddedNumber(((e.year % 100) + 100) % 100, 2, width)]; break;
            case 'Z': [out appendString:zoneName]; break;
            case 'z': [out appendFormat:@"%c%@%@", offset < 0 ? '-' : '+', PaddedNumber(labs(offset) / 3600, 2, nil), PaddedNumber((labs(offset) / 60) % 60, 2, nil)]; break;
            default: [out appendString:@"?"]; break;
        }
    }
    return out;
}

// The locale does not change the result (observed).
- (NSString *)descriptionWithCalendarFormat:(NSString *)format locale:(id)locale
{
    return [self descriptionWithCalendarFormat:format];
}

- (NSString *)descriptionWithLocale:(id)locale
{
    return [self descriptionWithCalendarFormat:_formatString];
}

- (NSString *)description
{
    return [self descriptionWithCalendarFormat:_formatString];
}

@end
