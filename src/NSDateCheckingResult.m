//
//  NSDateCheckingResult.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSDateCheckingResult.h"
#import <Foundation/NSDate.h>
#import <Foundation/NSTimeZone.h>

#import "NSTextCheckingResultCoding.h"
#import <Foundation/NSCoder.h>

@implementation NSDateCheckingResult

- (id)initWithRange:(NSRange)range date:(NSDate *)date
{
    return [self initWithRange:range date:date timeZone:nil duration:0.0 referenceDate:nil underlyingResult:NULL timeIsSignificant:YES timeIsApproximate:NO];
}

- (id)initWithRange:(NSRange)range date:(NSDate *)date timeZone:(NSTimeZone *)timeZone duration:(NSTimeInterval)duration
{
    return [self initWithRange:range date:date timeZone:timeZone duration:duration referenceDate:nil underlyingResult:NULL timeIsSignificant:YES timeIsApproximate:NO];
}

- (id)initWithRange:(NSRange)range date:(NSDate *)date timeZone:(NSTimeZone *)timeZone duration:(NSTimeInterval)duration referenceDate:(NSDate *)referenceDate
{
    return [self initWithRange:range date:date timeZone:timeZone duration:duration referenceDate:referenceDate underlyingResult:NULL timeIsSignificant:YES timeIsApproximate:NO];
}

- (id)initWithRange:(NSRange)range date:(NSDate *)date timeZone:(NSTimeZone *)timeZone duration:(NSTimeInterval)duration referenceDate:(NSDate *)referenceDate underlyingResult:(void *)underlyingResult
{
    return [self initWithRange:range date:date timeZone:timeZone duration:duration referenceDate:referenceDate underlyingResult:underlyingResult timeIsSignificant:YES timeIsApproximate:NO];
}

- (id)initWithRange:(NSRange)range date:(NSDate *)date timeZone:(NSTimeZone *)timeZone duration:(NSTimeInterval)duration referenceDate:(NSDate *)referenceDate underlyingResult:(void *)underlyingResult timeIsSignificant:(BOOL)timeIsSignificant timeIsApproximate:(BOOL)timeIsApproximate
{
    self = [super init];
    if (self)
    {
        _range = range;
        _date = [date retain];
        _timeZone = [timeZone retain];
        _duration = duration;
        _referenceDate = [referenceDate retain];
        _underlyingResult = underlyingResult;
        _timeIsSignificant = timeIsSignificant;
        _timeIsApproximate = timeIsApproximate;
    }
    return self;
}

- (void)dealloc
{
    [_date release];
    [_timeZone release];
    [_referenceDate release];
    [super dealloc];
}

- (NSDate *)date
{
    return _date;
}

- (NSTimeZone *)timeZone
{
    return _timeZone;
}

- (NSTimeInterval)duration
{
    return _duration;
}

- (NSDate *)referenceDate
{
    return _referenceDate;
}

- (BOOL)timeIsSignificant
{
    return _timeIsSignificant;
}

- (BOOL)timeIsApproximate
{
    return _timeIsApproximate;
}

- (void *)underlyingResult
{
    return _underlyingResult;
}

- (NSRange)range
{
    return _range;
}

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypeDate;
}

/*
- (NSString *)description
{

}
*/


- (void)encodeWithCoder:(NSCoder *)coder
{
    NSTextCheckingResultEncodeRange(coder, _range);
    [coder encodeObject:_date forKey:@"NSDate"];
    [coder encodeDouble:_duration forKey:@"NSDuration"];
    [coder encodeObject:_referenceDate forKey:@"NSReferenceDate"];
    [coder encodeObject:_timeZone forKey:@"NSTimeZone"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSRange range;
    NSDate *date = [coder decodeObjectOfClass:[NSDate class] forKey:@"NSDate"];
    NSDate *referenceDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"NSReferenceDate"];
    NSTimeZone *timeZone = [coder decodeObjectOfClass:[NSTimeZone class] forKey:@"NSTimeZone"];
    NSTimeInterval duration = [coder decodeDoubleForKey:@"NSDuration"];
    if (!NSTextCheckingResultDecodeRange(coder, &range) || date == nil)
    {
        [self release];
        return nil;
    }
    return [self initWithRange:range date:date timeZone:timeZone duration:duration referenceDate:referenceDate];
}

@end
