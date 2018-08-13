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

OBJC_PROTOCOL_IMPL_PUSH
+ (id)autoupdatingCurrentCalendar
{
    return [[[NSAutoCalendar alloc] init] autorelease];
}
OBJC_PROTOCOL_IMPL_POP

@end


const NSCalendarIdentifier NSCalendarIdentifierGregorian = @"NSCalendarIdentifierGregorian";
const NSCalendarIdentifier NSCalendarIdentifierISO8601 = @"NSCalendarIdentifierISO8601";
const NSCalendarIdentifier NSCalendarIdentifierBuddhist = @"NSCalendarIdentifierBuddhist";
const NSCalendarIdentifier NSCalendarIdentifierChinese = @"NSCalendarIdentifierChinese";
const NSCalendarIdentifier NSCalendarIdentifierCoptic = @"NSCalendarIdentifierCoptic";
const NSCalendarIdentifier NSCalendarIdentifierEthiopicAmeteAlem = @"NSCalendarIdentifierEthiopicAmeteAlem";
const NSCalendarIdentifier NSCalendarIdentifierEthiopicAmeteMihret = @"NSCalendarIdentifierEthiopicAmeteMihret";
const NSCalendarIdentifier NSCalendarIdentifierHebrew = @"NSCalendarIdentifierHebrew";
const NSCalendarIdentifier NSCalendarIdentifierIndian = @"NSCalendarIdentifierIndian";
const NSCalendarIdentifier NSCalendarIdentifierIslamic = @"NSCalendarIdentifierIslamic";
const NSCalendarIdentifier NSCalendarIdentifierIslamicCivil = @"NSCalendarIdentifierIslamicCivil";
const NSCalendarIdentifier NSCalendarIdentifierIslamicTabular = @"NSCalendarIdentifierIslamicTabular";
const NSCalendarIdentifier NSCalendarIdentifierIslamicUmmAlQura = @"NSCalendarIdentifierIslamicUmmAlQura";
const NSCalendarIdentifier NSCalendarIdentifierJapanese = @"NSCalendarIdentifierJapanese";
const NSCalendarIdentifier NSCalendarIdentifierPersian = @"NSCalendarIdentifierPersian";
const NSCalendarIdentifier NSCalendarIdentifierRepublicOfChina = @"NSCalendarIdentifierRepublicOfChina";


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
