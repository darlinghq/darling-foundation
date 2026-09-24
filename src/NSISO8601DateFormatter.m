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

#import <Foundation/NSISO8601DateFormatter.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimeZone.h>
#import <CoreFoundation/CFDateFormatter.h>

static NSString *const ISO8601FormatOptionsKey = @"NS.formatOptions";
static NSString *const ISO8601TimeZoneKey = @"NS.timeZone";

static CFDateFormatterRef createFormatter(NSTimeZone *timeZone, NSISO8601DateFormatOptions options)
{
    CFDateFormatterRef formatter = CFDateFormatterCreateISO8601Formatter(kCFAllocatorDefault, (CFISO8601DateFormatOptions)options);
    if (formatter == NULL)
    {
        [NSException raise:NSInternalInconsistencyException format:@"could not create an ISO 8601 date formatter"];
    }
    CFDateFormatterSetProperty(formatter, kCFDateFormatterTimeZone, (CFTimeZoneRef)timeZone);
    return formatter;
}

static NSString *stringFromDate(CFDateFormatterRef formatter, NSDate *date)
{
    return [(NSString *)CFDateFormatterCreateStringWithDate(kCFAllocatorDefault, formatter, (CFDateRef)date) autorelease];
}

@implementation NSISO8601DateFormatter

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (NSString *)stringFromDate:(NSDate *)date timeZone:(NSTimeZone *)timeZone formatOptions:(NSISO8601DateFormatOptions)formatOptions
{
    CFDateFormatterRef formatter = createFormatter(timeZone, formatOptions);
    NSString *string = stringFromDate(formatter, date);
    CFRelease(formatter);
    return string;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _timeZone = [[NSTimeZone timeZoneWithName:@"GMT"] retain];
        _formatOptions = NSISO8601DateFormatWithInternetDateTime;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"NSISO8601DateFormatter requires a keyed coder"];
        return nil;
    }

    self = [self init];
    if (self)
    {
        _formatOptions = [coder decodeIntegerForKey:ISO8601FormatOptionsKey];
        if ([coder containsValueForKey:ISO8601TimeZoneKey])
        {
            NSTimeZone *timeZone = [coder decodeObjectOfClass:[NSTimeZone class] forKey:ISO8601TimeZoneKey];
            if (timeZone == nil)
            {
                [self release];
                return nil;
            }
            [self setTimeZone:timeZone];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
    {
        [NSException raise:NSInvalidArgumentException format:@"NSISO8601DateFormatter requires a keyed coder"];
    }
    @synchronized(self)
    {
        [coder encodeInteger:_formatOptions forKey:ISO8601FormatOptionsKey];
        [coder encodeObject:_timeZone forKey:ISO8601TimeZoneKey];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    NSISO8601DateFormatter *copy = [[[self class] allocWithZone:zone] init];
    @synchronized(self)
    {
        [copy setTimeZone:_timeZone];
        [copy setFormatOptions:_formatOptions];
    }
    return copy;
}

- (void)dealloc
{
    if (_formatter != NULL)
    {
        CFRelease(_formatter);
    }
    [_timeZone release];
    [super dealloc];
}

- (NSTimeZone *)timeZone
{
    @synchronized(self)
    {
        return [[_timeZone retain] autorelease];
    }
}

- (void)setTimeZone:(NSTimeZone *)timeZone
{
    // NSTimeZone is immutable, and Darling's __NSTimeZone does not implement -copyWithZone: yet.
    NSTimeZone *newTimeZone = [(timeZone ?: [NSTimeZone timeZoneWithName:@"GMT"]) retain];
    @synchronized(self)
    {
        [_timeZone release];
        _timeZone = newTimeZone;
        [self _invalidateFormatter];
    }
}

- (NSISO8601DateFormatOptions)formatOptions
{
    @synchronized(self)
    {
        return _formatOptions;
    }
}

- (void)setFormatOptions:(NSISO8601DateFormatOptions)formatOptions
{
    @synchronized(self)
    {
        _formatOptions = formatOptions;
        [self _invalidateFormatter];
    }
}

// Callers hold the @synchronized(self) lock.
- (void)_invalidateFormatter
{
    if (_formatter != NULL)
    {
        CFRelease(_formatter);
        _formatter = NULL;
    }
}

- (CFDateFormatterRef)_currentFormatter
{
    if (_formatter == NULL)
    {
        _formatter = createFormatter(_timeZone, _formatOptions);
    }
    return _formatter;
}

- (NSString *)stringFromDate:(NSDate *)date
{
    @synchronized(self)
    {
        return stringFromDate([self _currentFormatter], date);
    }
}

- (NSDate *)dateFromString:(NSString *)string
{
    @synchronized(self)
    {
        return [(NSDate *)CFDateFormatterCreateDateFromString(kCFAllocatorDefault, [self _currentFormatter], (CFStringRef)string, NULL) autorelease];
    }
}

- (NSString *)stringForObjectValue:(id)obj
{
    if (![obj isKindOfClass:[NSDate class]])
    {
        return nil;
    }
    return [self stringFromDate:obj];
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error
{
    NSDate *date = [self dateFromString:string];
    if (date == nil)
    {
        if (error != NULL)
        {
            *error = [NSString stringWithFormat:@"The value “%@” is invalid.", string];
        }
        return NO;
    }
    if (obj != NULL)
    {
        *obj = date;
    }
    return YES;
}

@end
