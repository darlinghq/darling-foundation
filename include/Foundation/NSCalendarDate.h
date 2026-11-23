#import <Foundation/NSDate.h>

@class NSString, NSTimeZone;

// NSCalendarDate is documented as deprecated (macOS 10.10) in favour of NSDate and NSCalendar. Its instance
// variables are declared here, not in the implementation, because the i386 build uses the fragile Objective-C ABI: a
// class compiled against this header gets the right layout. They are the ones the class has on macOS (names and order).
@interface NSCalendarDate : NSDate
{
@private
    NSUInteger refCount;
    NSTimeInterval _timeIntervalSinceReferenceDate;
    NSTimeZone *_timeZone;
    NSString *_formatString;
    void *_reserved;
}

+ (id)calendarDate;
+ (instancetype)distantFuture;
+ (instancetype)distantPast;
+ (id)dateWithYear:(NSInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second timeZone:(NSTimeZone *)aTimeZone;

- (id)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)seconds;
- (id)initWithYear:(NSInteger)year month:(NSUInteger)month day:(NSUInteger)day hour:(NSUInteger)hour minute:(NSUInteger)minute second:(NSUInteger)second timeZone:(NSTimeZone *)aTimeZone;

- (NSInteger)dayOfCommonEra;
- (NSInteger)dayOfMonth;
- (NSInteger)dayOfWeek;
- (NSInteger)dayOfYear;
- (NSInteger)hourOfDay;
- (NSInteger)minuteOfHour;
- (NSInteger)monthOfYear;
- (NSInteger)secondOfMinute;
- (NSInteger)yearOfCommonEra;

- (NSTimeZone *)timeZone;
- (void)setTimeZone:(NSTimeZone *)aTimeZone;
- (NSString *)calendarFormat;
- (void)setCalendarFormat:(NSString *)format;

- (NSString *)descriptionWithCalendarFormat:(NSString *)format;
- (NSString *)descriptionWithCalendarFormat:(NSString *)format locale:(id)locale;
- (NSString *)descriptionWithLocale:(id)locale;

- (NSCalendarDate *)dateByAddingYears:(NSInteger)year months:(NSInteger)month days:(NSInteger)day hours:(NSInteger)hour minutes:(NSInteger)minute seconds:(NSInteger)second;

@end
