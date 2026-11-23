#import <Foundation/NSDate.h>

@class NSString, NSTimeZone;

// NSCalendarDate is documented as deprecated (macOS 10.10) in favour of NSDate and NSCalendar. Its instance variables are
// declared here, not in the implementation, because the i386 build uses the fragile Objective-C ABI: a class compiled
// against this header gets the right layout. A subclass compiled against the platform's own header takes its ivar offsets
// from the platform's instance size, which the documentation does not give, so on i386 its ivars may overlap ours.
@interface NSCalendarDate : NSDate
{
@private
    // The one instance variable that the class page lists; nothing here uses it.
    NSUInteger refCount;
    NSTimeInterval _referenceInterval;
    NSTimeZone *_timeZone;
    NSString *_calendarFormat;
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

- (NSCalendarDate *)dateByAddingYears:(NSInteger)year months:(NSInteger)month days:(NSInteger)day hours:(NSInteger)hour minutes:(NSInteger)minute seconds:(NSInteger)second;

@end
