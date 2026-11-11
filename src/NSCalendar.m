//
//  NSCalendar.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSCalendarInternal.h"
#import "NSObjectInternal.h"
#import <Foundation/NSNotification.h>

@implementation NSCalendar (NSCalendar)

- (NSInteger)component:(NSCalendarUnit)unit fromDate:(NSDate *)date
{
    NSDateComponents *components = [self components:unit fromDate:date];
    switch (unit)
    {
        case NSCalendarUnitEra: return [components era];
        case NSCalendarUnitYear: return [components year];
        case NSCalendarUnitMonth: return [components month];
        case NSCalendarUnitDay: return [components day];
        case NSCalendarUnitHour: return [components hour];
        case NSCalendarUnitMinute: return [components minute];
        case NSCalendarUnitSecond: return [components second];
        case NSCalendarUnitWeekday: return [components weekday];
        case NSCalendarUnitWeekdayOrdinal: return [components weekdayOrdinal];
        case NSCalendarUnitQuarter: return [components quarter];
        case NSCalendarUnitWeekOfMonth: return [components weekOfMonth];
        case NSCalendarUnitWeekOfYear: return [components weekOfYear];
        case NSCalendarUnitYearForWeekOfYear: return [components yearForWeekOfYear];
        case NSCalendarUnitNanosecond: return [components nanosecond];
        default: return NSUndefinedDateComponent;
    }
}

OBJC_PROTOCOL_IMPL_PUSH
+ (id)autoupdatingCurrentCalendar
{
    return [[[NSAutoCalendar alloc] init] autorelease];
}
OBJC_PROTOCOL_IMPL_POP

@end



@implementation NSAutoCalendar

- (id)init
{
    self = [super init];
    if (self)
    {
        cal = [[NSCalendar currentCalendar] retain];
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(_update:) name:(NSString *)kCFLocaleCurrentLocaleDidChangeNotification object:nil];
        [center addObserver:self selector:@selector(_update:) name:(NSString *)kCFTimeZoneSystemTimeZoneDidChangeNotification object:nil];
    }
    return self;
}

- (id)initWithCalendarIdentifier:(NSCalendarIdentifier)ident
{
    return [self init];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [cal release];
    [super dealloc];
}

- (NSCalendarIdentifier)calendarIdentifier
{
    return [cal calendarIdentifier];
}

- (void)setLocale:(NSLocale *)locale
{
    [cal setLocale:locale];
}

- (NSLocale *)locale
{
    return [cal locale];
}

- (void)setTimeZone:(NSTimeZone *)tz
{
    [cal setTimeZone:tz];
}

- (NSTimeZone *)timeZone
{
    return [cal timeZone];
}

- (void)setFirstWeekday:(NSUInteger)weekday
{
    [cal setFirstWeekday:weekday];
}

- (NSUInteger)firstWeekday
{
    return [cal firstWeekday];
}

- (void)setMinimumDaysInFirstWeek:(NSUInteger)mdw
{
    [cal setMinimumDaysInFirstWeek:mdw];
}

- (NSUInteger)minimumDaysInFirstWeek
{
    return [cal minimumDaysInFirstWeek];
}

- (NSRange)minimumRangeOfUnit:(NSCalendarUnit)unit
{
    return [cal minimumRangeOfUnit:unit];
}

- (NSRange)maximumRangeOfUnit:(NSCalendarUnit)unit
{
    return [cal maximumRangeOfUnit:unit];
}

- (NSRange)rangeOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate *)date
{
    return [cal rangeOfUnit:smaller inUnit:larger forDate:date];
}

- (NSUInteger)ordinalityOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate *)date
{
    return [cal ordinalityOfUnit:smaller inUnit:larger forDate:date];
}

- (BOOL)rangeOfUnit:(NSCalendarUnit)unit startDate:(NSDate **)datep interval:(NSTimeInterval *)tip forDate:(NSDate *)date
{
    return [cal rangeOfUnit:unit startDate:datep interval:tip forDate:date];
}

- (NSDate *)dateFromComponents:(NSDateComponents *)comps
{
    return [cal dateFromComponents:comps];
}

- (NSDateComponents *)components:(NSUInteger)unitFlags fromDate:(NSDate *)date
{
    return [cal components:unitFlags fromDate:date];
}

- (NSDate *)dateByAddingComponents:(NSDateComponents *)comps toDate:(NSDate *)date options:(NSUInteger)opts
{
    return [cal dateByAddingComponents:comps toDate:date options:opts];
}

- (NSDateComponents *)components:(NSUInteger)unitFlags fromDate:(NSDate *)startingDate toDate:(NSDate *)resultDate options:(NSUInteger)opts
{
    return [cal components:unitFlags fromDate:startingDate toDate:resultDate options:opts];
}

- (void)_update:(NSNotification *)notif
{
    [cal release];
    cal = [[NSCalendar currentCalendar] retain];
}

@end
