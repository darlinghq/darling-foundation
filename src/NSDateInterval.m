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

#import <Foundation/NSDateInterval.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>

@implementation NSDateInterval

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    return [self initWithStartDate:[NSDate date] duration:0];
}

- (instancetype)initWithStartDate:(NSDate *)startDate duration:(NSTimeInterval)duration
{
    if (startDate == nil)
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"-[NSDateInterval initWithStartDate:duration:]: nil start date"];
        return nil;
    }
    if (!(duration >= 0))
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"-[NSDateInterval initWithStartDate:duration:]: negative duration %f", duration];
        return nil;
    }

    self = [super init];
    if (self != nil)
    {
        _startDate = [startDate copy];
        // + 0.0 turns -0.0 into 0.0, so equal intervals hash equally.
        _duration = duration + 0.0;
    }
    return self;
}

- (instancetype)initWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
    if (startDate == nil || endDate == nil)
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"-[NSDateInterval initWithStartDate:endDate:]: nil date"];
        return nil;
    }
    return [self initWithStartDate:startDate duration:[endDate timeIntervalSinceDate:startDate]];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSDate *startDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"NS.startDate"];
    NSDate *endDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"NS.endDate"];
    if (startDate == nil || endDate == nil || [endDate compare:startDate] == NSOrderedAscending)
    {
        [self release];
        return nil;
    }
    return [self initWithStartDate:startDate endDate:endDate];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_startDate forKey:@"NS.startDate"];
    [coder encodeObject:[self endDate] forKey:@"NS.endDate"];
}

- (void)dealloc
{
    [_startDate release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (NSDate *)startDate
{
    return _startDate;
}

- (NSDate *)endDate
{
    return [_startDate dateByAddingTimeInterval:_duration];
}

- (NSTimeInterval)duration
{
    return _duration;
}

- (NSComparisonResult)compare:(NSDateInterval *)dateInterval
{
    NSComparisonResult result = [_startDate compare:[dateInterval startDate]];
    if (result != NSOrderedSame)
    {
        return result;
    }
    if (_duration < [dateInterval duration])
    {
        return NSOrderedAscending;
    }
    if (_duration > [dateInterval duration])
    {
        return NSOrderedDescending;
    }
    return NSOrderedSame;
}

- (BOOL)isEqualToDateInterval:(NSDateInterval *)dateInterval
{
    return dateInterval != nil && [_startDate isEqualToDate:[dateInterval startDate]] && _duration == [dateInterval duration];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
    {
        return YES;
    }
    return [object isKindOfClass:[NSDateInterval class]] && [self isEqualToDateInterval:object];
}

- (NSUInteger)hash
{
    // Hash the bits: casting an infinite duration to an integer is undefined.
    union { double d; uint64_t u; } bits = { _duration };
    return [_startDate hash] ^ (NSUInteger)(bits.u ^ (bits.u >> 32));
}

- (BOOL)intersectsDateInterval:(NSDateInterval *)dateInterval
{
    return [self intersectionWithDateInterval:dateInterval] != nil;
}

- (NSDateInterval *)intersectionWithDateInterval:(NSDateInterval *)dateInterval
{
    NSDate *start = [_startDate laterDate:[dateInterval startDate]];
    NSDate *end = [[self endDate] earlierDate:[dateInterval endDate]];
    if ([start compare:end] == NSOrderedDescending)
    {
        return nil;
    }
    return [[[NSDateInterval alloc] initWithStartDate:start endDate:end] autorelease];
}

- (BOOL)containsDate:(NSDate *)date
{
    return [_startDate compare:date] != NSOrderedDescending && [[self endDate] compare:date] != NSOrderedAscending;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ to %@", _startDate, [self endDate]];
}

@end
