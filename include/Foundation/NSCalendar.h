#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSDate.h>
#import <CoreFoundation/CFCalendar.h>

@class NSDateComponents, NSLocale, NSTimeZone, NSString;

typedef NS_OPTIONS(NSUInteger, NSCalendarUnit) {
    NSCalendarUnitEra               = kCFCalendarUnitEra,
    NSCalendarUnitYear              = kCFCalendarUnitYear,
    NSCalendarUnitMonth             = kCFCalendarUnitMonth,
    NSCalendarUnitDay               = kCFCalendarUnitDay,
    NSCalendarUnitHour              = kCFCalendarUnitHour,
    NSCalendarUnitMinute            = kCFCalendarUnitMinute,
    NSCalendarUnitSecond            = kCFCalendarUnitSecond,
    NSCalendarUnitWeekday           = kCFCalendarUnitWeekday,
    NSCalendarUnitWeekdayOrdinal    = kCFCalendarUnitWeekdayOrdinal,
    NSCalendarUnitQuarter           = kCFCalendarUnitQuarter,
    NSCalendarUnitWeekOfMonth       = kCFCalendarUnitWeekOfMonth,
    NSCalendarUnitWeekOfYear        = kCFCalendarUnitWeekOfYear,
    NSCalendarUnitYearForWeekOfYear = kCFCalendarUnitYearForWeekOfYear,
    NSCalendarUnitNanosecond        = (1 << 15),
    NSCalendarUnitCalendar          = (1 << 20),
    NSCalendarUnitTimeZone          = (1 << 21),

    NSEraCalendarUnit               = NSCalendarUnitEra,
    NSYearCalendarUnit              = NSCalendarUnitYear,
    NSMonthCalendarUnit             = NSCalendarUnitMonth,
    NSDayCalendarUnit               = NSCalendarUnitDay,
    NSHourCalendarUnit              = NSCalendarUnitHour,
    NSMinuteCalendarUnit            = NSCalendarUnitMinute,
    NSSecondCalendarUnit            = NSCalendarUnitSecond,
    NSWeekCalendarUnit              = kCFCalendarUnitWeek,
    NSWeekdayCalendarUnit           = NSCalendarUnitWeekday,
    NSWeekdayOrdinalCalendarUnit    = NSCalendarUnitWeekdayOrdinal,
    NSQuarterCalendarUnit           = NSCalendarUnitQuarter,
    NSWeekOfMonthCalendarUnit       = NSCalendarUnitWeekOfMonth,
    NSWeekOfYearCalendarUnit        = NSCalendarUnitWeekOfYear,
    NSYearForWeekOfYearCalendarUnit = NSCalendarUnitYearForWeekOfYear,
    NSCalendarCalendarUnit          = NSCalendarUnitCalendar,
    NSTimeZoneCalendarUnit          = NSCalendarUnitTimeZone,
};

enum {
    NSWrapCalendarComponents = kCFCalendarComponentsWrap,
};

enum {
    NSUndefinedDateComponent = NSIntegerMax
};

typedef NSString *NSCalendarIdentifier;

FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierGregorian;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierISO8601;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierBuddhist;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierChinese;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierCoptic;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierEthiopicAmeteAlem;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierEthiopicAmeteMihret;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierHebrew;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierIndian;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierIslamic;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierIslamicCivil;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierIslamicTabular;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierIslamicUmmAlQura;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierJapanese;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierPersian;
FOUNDATION_EXPORT const NSCalendarIdentifier NSCalendarIdentifierRepublicOfChina;

@interface NSCalendar : NSObject <NSCopying, NSSecureCoding>

+ (id)currentCalendar;
+ (id)autoupdatingCurrentCalendar;

- (id)initWithCalendarIdentifier:(NSCalendarIdentifier)ident;
- (NSCalendarIdentifier)calendarIdentifier;
- (void)setLocale:(NSLocale *)locale;
- (NSLocale *)locale;
- (void)setTimeZone:(NSTimeZone *)tz;
- (NSTimeZone *)timeZone;
- (void)setFirstWeekday:(NSUInteger)weekday;
- (NSUInteger)firstWeekday;
- (void)setMinimumDaysInFirstWeek:(NSUInteger)mdw;
- (NSUInteger)minimumDaysInFirstWeek;
- (NSRange)minimumRangeOfUnit:(NSCalendarUnit)unit;
- (NSRange)maximumRangeOfUnit:(NSCalendarUnit)unit;
- (NSRange)rangeOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate *)date;
- (NSUInteger)ordinalityOfUnit:(NSCalendarUnit)smaller inUnit:(NSCalendarUnit)larger forDate:(NSDate *)date;
- (BOOL)rangeOfUnit:(NSCalendarUnit)unit startDate:(NSDate **)datep interval:(NSTimeInterval *)tip forDate:(NSDate *)date;
- (NSDate *)dateFromComponents:(NSDateComponents *)comps;
- (NSDateComponents *)components:(NSUInteger)unitFlags fromDate:(NSDate *)date;
- (NSDate *)dateByAddingComponents:(NSDateComponents *)comps toDate:(NSDate *)date options:(NSUInteger)opts;
- (NSDateComponents *)components:(NSUInteger)unitFlags fromDate:(NSDate *)startingDate toDate:(NSDate *)resultDate options:(NSUInteger)opts;

@end

@interface NSDateComponents : NSObject <NSCopying, NSSecureCoding>

- (NSCalendar *)calendar;
- (NSTimeZone *)timeZone;
- (NSInteger)era;
- (NSInteger)year;
- (NSInteger)month;
- (NSInteger)day;
- (NSInteger)hour;
- (NSInteger)minute;
- (NSInteger)second;
- (NSInteger)week;
- (NSInteger)weekday;
- (NSInteger)weekdayOrdinal;
- (NSInteger)quarter;
- (NSInteger)weekOfMonth;
- (NSInteger)weekOfYear;
- (NSInteger)yearForWeekOfYear;
- (BOOL)isLeapMonth;
- (void)setCalendar:(NSCalendar *)cal;
- (void)setTimeZone:(NSTimeZone *)tz;
- (void)setEra:(NSInteger)era;
- (void)setYear:(NSInteger)year;
- (void)setMonth:(NSInteger)month;
- (void)setDay:(NSInteger)day;
- (void)setHour:(NSInteger)hour;
- (void)setMinute:(NSInteger)min;
- (void)setSecond:(NSInteger)sec;
- (void)setWeek:(NSInteger)week;
- (void)setWeekday:(NSInteger)weekday;
- (void)setWeekdayOrdinal:(NSInteger)ordinal;
- (void)setQuarter:(NSInteger)quarter;
- (void)setWeekOfMonth:(NSInteger)week;
- (void)setWeekOfYear:(NSInteger)week;
- (void)setYearForWeekOfYear:(NSInteger)year;
- (void)setLeapMonth:(BOOL)leapMonth;
- (NSDate *)date;

@end
