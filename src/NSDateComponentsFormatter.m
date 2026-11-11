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

#import <Foundation/NSDateComponentsFormatter.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSException.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSString.h>
#include <dispatch/dispatch.h>
#include <limits.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <unicode/uameasureformat.h>
#include <unicode/udata.h>
#include <unicode/uloc.h>
#include <unicode/ulistformatter.h>
#include <unicode/unum.h>
#include <unicode/ures.h>

// Darling's NSDateComponents marks unset fields with INT_MAX; Apple's use NSUndefinedDateComponent.
static BOOL NSDCFIsUnset(NSInteger value)
{
    return value == INT_MAX || value == NSUndefinedDateComponent;
}

enum {
    NSDCFYear, NSDCFMonth, NSDCFWeek, NSDCFDay, NSDCFHour, NSDCFMinute, NSDCFSecond, NSDCFUnitCount
};

static const NSCalendarUnit NSDCFCalendarUnits[NSDCFUnitCount] = {
    NSCalendarUnitYear, NSCalendarUnitMonth, NSCalendarUnitWeekOfMonth, NSCalendarUnitDay,
    NSCalendarUnitHour, NSCalendarUnitMinute, NSCalendarUnitSecond,
};

static const UAMeasureUnit NSDCFMeasureUnits[NSDCFUnitCount] = {
    UAMEASUNIT_DURATION_YEAR, UAMEASUNIT_DURATION_MONTH, UAMEASUNIT_DURATION_WEEK, UAMEASUNIT_DURATION_DAY,
    UAMEASUNIT_DURATION_HOUR, UAMEASUNIT_DURATION_MINUTE, UAMEASUNIT_DURATION_SECOND,
};

static const NSCalendarUnit NSDCFSupportedUnits = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth |
    NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;

static NSInteger NSDCFComponentValue(NSDateComponents *components, int index)
{
    switch (index)
    {
        case NSDCFYear: return [components year];
        case NSDCFMonth: return [components month];
        case NSDCFWeek: return [components weekOfMonth];
        case NSDCFDay: return [components day];
        case NSDCFHour: return [components hour];
        case NSDCFMinute: return [components minute];
        default: return [components second];
    }
}

static void NSDCFSetComponentValue(NSDateComponents *components, int index, NSInteger value)
{
    switch (index)
    {
        case NSDCFYear: [components setYear:value]; break;
        case NSDCFMonth: [components setMonth:value]; break;
        case NSDCFWeek: [components setWeekOfMonth:value]; break;
        case NSDCFDay: [components setDay:value]; break;
        case NSDCFHour: [components setHour:value]; break;
        case NSDCFMinute: [components setMinute:value]; break;
        default: [components setSecond:value]; break;
    }
}

typedef int32_t (^NSDCFICUWriter)(UChar *buffer, int32_t capacity, UErrorCode *status);

static NSString *NSDCFStringFromICU(NSDCFICUWriter write)
{
    UChar stackBuffer[128];
    UErrorCode status = U_ZERO_ERROR;
    int32_t length = write(stackBuffer, sizeof(stackBuffer) / sizeof(stackBuffer[0]), &status);
    if (status != U_BUFFER_OVERFLOW_ERROR)
    {
        return U_SUCCESS(status) ? [NSString stringWithCharacters:stackBuffer length:length] : nil;
    }
    UChar *heapBuffer = malloc(sizeof(UChar) * (length + 1));
    if (heapBuffer == NULL)
    {
        return nil;
    }
    status = U_ZERO_ERROR;
    length = write(heapBuffer, length + 1, &status);
    NSString *result = U_SUCCESS(status) ? [NSString stringWithCharacters:heapBuffer length:length] : nil;
    free(heapBuffer);
    return result;
}

static NSString *NSDCFJoinUnits(NSArray *parts, const char *locale, UListFormatterWidth width)
{
    if ([parts count] == 1)
    {
        return [parts objectAtIndex:0];
    }
    UErrorCode status = U_ZERO_ERROR;
    UListFormatter *list = ulistfmt_openForType(locale, ULISTFMT_TYPE_UNITS, width, &status);
    if (U_FAILURE(status))
    {
        return nil;
    }
    int32_t count = (int32_t)[parts count];
    NSString *joined = [parts componentsJoinedByString:@""];
    UChar *characters = malloc(sizeof(UChar) * ([joined length] + 1));
    const UChar **strings = malloc(sizeof(UChar *) * count);
    int32_t *lengths = malloc(sizeof(int32_t) * count);
    NSString *result = nil;
    if (characters != NULL && strings != NULL && lengths != NULL)
    {
        [joined getCharacters:characters range:NSMakeRange(0, [joined length])];
        int32_t offset = 0;
        for (int32_t i = 0; i < count; i++)
        {
            strings[i] = characters + offset;
            lengths[i] = (int32_t)[[parts objectAtIndex:i] length];
            offset += lengths[i];
        }
        result = NSDCFStringFromICU(^int32_t(UChar *buffer, int32_t capacity, UErrorCode *error) {
            return ulistfmt_format(list, strings, lengths, count, buffer, capacity, error);
        });
    }
    free(characters);
    free(strings);
    free(lengths);
    ulistfmt_close(list);
    return result;
}

static NSString *NSDCFFormatMeasure(UAMeasureFormat *format, double value, int index)
{
    return NSDCFStringFromICU(^int32_t(UChar *buffer, int32_t capacity, UErrorCode *error) {
        return uameasfmt_format(format, value, NSDCFMeasureUnits[index], buffer, capacity, error);
    });
}

// The CLDR "durationUnits" pattern (e.g. "h:mm:ss") for hours-minutes, minutes-seconds or all three,
// looked up in the locale and then its parents, as a table can lack some of the three keys.
static NSString *NSDCFPositionalPattern(const char *locale, const char *key)
{
    char current[ULOC_FULLNAME_CAPACITY];
    strlcpy(current, locale, sizeof(current));
    for (;;)
    {
        UErrorCode status = U_ZERO_ERROR;
        UResourceBundle *units = ures_open(U_ICUDATA_NAME U_TREE_SEPARATOR_STRING "unit", current, &status);
        UResourceBundle *durations = ures_getByKey(units, "durationUnits", NULL, &status);
        int32_t length = 0;
        const UChar *pattern = ures_getStringByKey(durations, key, &length, &status);
        NSString *result = U_SUCCESS(status) ? [NSString stringWithCharacters:pattern length:length] : nil;
        ures_close(durations);
        ures_close(units);
        if (result != nil || current[0] == '\0')
        {
            return result;
        }
        char parent[ULOC_FULLNAME_CAPACITY];
        status = U_ZERO_ERROR;
        uloc_getParent(current, parent, sizeof(parent), &status);
        if (U_FAILURE(status))
        {
            return nil;
        }
        strlcpy(current, parent, sizeof(current));
    }
}

static NSString *NSDCFFormatNumber(UNumberFormat *format, double value, int32_t minimumDigits)
{
    unum_setAttribute(format, UNUM_MIN_INTEGER_DIGITS, minimumDigits);
    return NSDCFStringFromICU(^int32_t(UChar *buffer, int32_t capacity, UErrorCode *error) {
        return unum_formatDouble(format, value, buffer, capacity, NULL, error);
    });
}

// Fills the pattern the way ICU's MeasureFormat does for its numeric width; padAll gives every field
// two digits instead of the pattern's own (doubled letters).
static NSString *NSDCFFormatPositional(const char *locale, const double *values, BOOL hasHour, BOOL hasSecond,
                                       BOOL padAll)
{
    const char *key = hasHour && !hasSecond ? "hm" : (!hasHour ? "ms" : "hms");
    NSString *pattern = NSDCFPositionalPattern(locale, key);
    if (pattern == nil)
    {
        return nil;
    }
    UErrorCode status = U_ZERO_ERROR;
    UNumberFormat *number = unum_open(UNUM_DECIMAL, NULL, 0, locale, NULL, &status);
    if (U_FAILURE(status))
    {
        return nil;
    }
    unum_setAttribute(number, UNUM_GROUPING_USED, 0);

    NSMutableString *result = [NSMutableString string];
    NSUInteger length = [pattern length];
    BOOL quoted = NO;
    for (NSUInteger i = 0; i < length; i++)
    {
        unichar c = [pattern characterAtIndex:i];
        if (c == '\'')
        {
            if (i + 1 < length && [pattern characterAtIndex:i + 1] == '\'')
            {
                [result appendString:@"'"];
                i++;
            }
            else
            {
                quoted = !quoted;
            }
            continue;
        }
        double value;
        if (!quoted && (c == 'h' || c == 'H'))
        {
            value = values[NSDCFHour];
        }
        else if (!quoted && c == 'm')
        {
            value = values[NSDCFMinute];
        }
        else if (!quoted && c == 's')
        {
            value = values[NSDCFSecond];
        }
        else
        {
            [result appendFormat:@"%C", c];
            continue;
        }
        int32_t run = 1;
        while (i + 1 < length && [pattern characterAtIndex:i + 1] == c)
        {
            run++;
            i++;
        }
        int32_t digits = padAll ? 2 : run;
        NSString *field = NSDCFFormatNumber(number, value, digits);
        if (field == nil)
        {
            result = nil;
            break;
        }
        [result appendString:field];
    }
    unum_close(number);
    return result;
}

@implementation NSDateComponentsFormatter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
        _zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDefault;
        _calendar = [[NSCalendar autoupdatingCurrentCalendar] retain];
        _formattingContext = NSFormattingContextUnknown;
    }
    return self;
}

- (void)dealloc
{
    [_calendar release];
    [_referenceDate release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSDateComponentsFormatter *copy = [[[self class] allocWithZone:zone] init];
    [copy->_calendar release];
    copy->_calendar = [_calendar copy];
    copy->_referenceDate = [_referenceDate copy];
    copy->_unitsStyle = _unitsStyle;
    copy->_allowedUnits = _allowedUnits;
    copy->_zeroFormattingBehavior = _zeroFormattingBehavior;
    copy->_allowsFractionalUnits = _allowsFractionalUnits;
    copy->_maximumUnitCount = _maximumUnitCount;
    copy->_collapsesLargestUnit = _collapsesLargestUnit;
    copy->_includesApproximationPhrase = _includesApproximationPhrase;
    copy->_includesTimeRemainingPhrase = _includesTimeRemainingPhrase;
    copy->_formattingContext = _formattingContext;
    return copy;
}

+ (NSString *)localizedStringFromDateComponents:(NSDateComponents *)components unitsStyle:(NSDateComponentsFormatterUnitsStyle)unitsStyle
{
    NSDateComponentsFormatter *formatter = [[self alloc] init];
    [formatter setUnitsStyle:unitsStyle];
    NSString *result = [formatter stringFromDateComponents:components];
    [formatter release];
    return result;
}

- (NSString *)stringForObjectValue:(id)obj
{
    if ([obj isKindOfClass:[NSDateComponents class]])
    {
        return [self stringFromDateComponents:obj];
    }
    return nil;
}

- (NSString *)stringFromDateComponents:(NSDateComponents *)components
{
    NSCalendarUnit units = _allowedUnits;
    NSDateComponents *duration = [[[NSDateComponents alloc] init] autorelease];
    for (int i = 0; i < NSDCFUnitCount; i++)
    {
        NSInteger value = NSDCFComponentValue(components, i);
        if (!NSDCFIsUnset(value))
        {
            NSDCFSetComponentValue(duration, i, value);
            if (_allowedUnits == 0)
            {
                units |= NSDCFCalendarUnits[i];
            }
        }
    }
    if (units == 0)
    {
        return nil;
    }
    NSCalendar *calendar = [components calendar] ?: [self _formattingCalendar];
    NSDate *start = _referenceDate ?: [NSDate date];
    NSDate *end = [calendar dateByAddingComponents:duration toDate:start options:0];
    if (end == nil)
    {
        return nil;
    }
    return [self _stringFromDate:start toDate:end units:units calendar:calendar];
}

- (NSString *)stringFromDate:(NSDate *)startDate toDate:(NSDate *)endDate
{
    return [self _stringFromDate:startDate toDate:endDate units:[self _intervalUnits] calendar:[self _formattingCalendar]];
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)ti
{
    if (!isfinite(ti))
    {
        return nil;
    }
    NSDate *start = _referenceDate ?: [NSDate date];
    return [self stringFromDate:start toDate:[start dateByAddingTimeInterval:ti]];
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error
{
    return NO;
}

- (NSCalendarUnit)allowedUnits
{
    return _allowedUnits;
}

- (void)setAllowedUnits:(NSCalendarUnit)allowedUnits
{
    if ((allowedUnits & ~NSDCFSupportedUnits) != 0)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"NSDateComponentsFormatter: allowed units must be years, months, weeks (NSCalendarUnitWeekOfMonth), days, hours, minutes or seconds"];
    }
    _allowedUnits = allowedUnits;
}

- (NSCalendarUnit)_intervalUnits
{
    return _allowedUnits != 0 ? _allowedUnits : NSDCFSupportedUnits;
}

// A nil calendar means the Gregorian calendar with the en_US_POSIX locale.
- (NSCalendar *)_formattingCalendar
{
    if (_calendar != nil)
    {
        return _calendar;
    }
    // The CF identifier: Darling's NSCalendarIdentifierGregorian does not match it yet (darling#979).
    NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:(NSString *)kCFGregorianCalendar] autorelease];
    [calendar setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    return calendar;
}

- (BOOL)_readComponentsFrom:(NSDate *)start to:(NSDate *)end units:(NSCalendarUnit)units calendar:(NSCalendar *)calendar
                       into:(double *)values
{
    NSDateComponents *difference = [calendar components:units fromDate:start toDate:end options:0];
    if (difference == nil)
    {
        return NO;
    }
    for (int i = 0; i < NSDCFUnitCount; i++)
    {
        values[i] = (units & NSDCFCalendarUnits[i]) != 0 ? NSDCFComponentValue(difference, i) : 0;
    }
    return YES;
}

- (NSString *)_stringFromDate:(NSDate *)start toDate:(NSDate *)end units:(NSCalendarUnit)units calendar:(NSCalendar *)calendar
{
    if (_includesApproximationPhrase || _includesTimeRemainingPhrase)
    {
        // Darling's ICU (CLDR 36) has no localized "About ..." or "... remaining" phrases.
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"NSDateComponentsFormatter: includesApproximationPhrase and includesTimeRemainingPhrase are not implemented");
        });
        return nil;
    }
    if (start == nil || end == nil)
    {
        return nil;
    }
    BOOL negative = [end compare:start] == NSOrderedAscending;
    if (negative)
    {
        NSDate *swap = start;
        start = end;
        end = swap;
    }

    BOOL allowed[NSDCFUnitCount];
    int smallest = -1;
    for (int i = 0; i < NSDCFUnitCount; i++)
    {
        allowed[i] = (units & NSDCFCalendarUnits[i]) != 0;
        if (allowed[i])
        {
            smallest = i;
        }
    }

    double values[NSDCFUnitCount];
    if (![self _readComponentsFrom:start to:end units:units calendar:calendar into:values])
    {
        return nil;
    }

    int first = -1;
    for (int i = 0; i < NSDCFUnitCount && first < 0; i++)
    {
        if (values[i] != 0)
        {
            first = i;
        }
    }

    // "1m 3s" becomes "63s": a largest unit of exactly one is re-expressed in the next allowed unit.
    if (_collapsesLargestUnit && first >= 0 && first < smallest && values[first] == 1)
    {
        units &= ~NSDCFCalendarUnits[first];
        allowed[first] = NO;
        if (![self _readComponentsFrom:start to:end units:units calendar:calendar into:values])
        {
            return nil;
        }
        first = -1;
        for (int i = 0; i < NSDCFUnitCount && first < 0; i++)
        {
            if (values[i] != 0)
            {
                first = i;
            }
        }
    }

    int lastKept = smallest;
    if (_maximumUnitCount > 0 && first >= 0)
    {
        NSInteger slots = 0;
        for (int i = first; i < NSDCFUnitCount; i++)
        {
            if (!allowed[i])
            {
                continue;
            }
            if (++slots > _maximumUnitCount)
            {
                values[i] = 0;
            }
            else
            {
                lastKept = i;
            }
        }
    }

    if (_allowsFractionalUnits)
    {
        NSDateComponents *whole = [[[NSDateComponents alloc] init] autorelease];
        for (int i = 0; i < NSDCFUnitCount; i++)
        {
            NSDCFSetComponentValue(whole, i, (NSInteger)values[i]);
        }
        NSDate *reached = [calendar dateByAddingComponents:whole toDate:start options:0];
        NSDateComponents *one = [[[NSDateComponents alloc] init] autorelease];
        NSDCFSetComponentValue(one, lastKept, 1);
        NSDate *next = reached != nil ? [calendar dateByAddingComponents:one toDate:reached options:0] : nil;
        if (next == nil)
        {
            return nil;
        }
        NSTimeInterval remainder = [end timeIntervalSinceDate:reached];
        NSTimeInterval unitLength = [next timeIntervalSinceDate:reached];
        if (remainder > 0 && unitLength > 0)
        {
            values[lastKept] += remainder / unitLength;
        }
    }

    BOOL positional = _unitsStyle == NSDateComponentsFormatterUnitsStylePositional;
    NSDateComponentsFormatterZeroFormattingBehavior zeros = _zeroFormattingBehavior;
    if ((zeros & NSDateComponentsFormatterZeroFormattingBehaviorDefault) != 0)
    {
        zeros |= positional ? NSDateComponentsFormatterZeroFormattingBehaviorDropLeading
                            : NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
    }

    int firstNonZero = -1, lastNonZero = -1;
    for (int i = 0; i < NSDCFUnitCount; i++)
    {
        if (allowed[i] && values[i] != 0)
        {
            if (firstNonZero < 0)
            {
                firstNonZero = i;
            }
            lastNonZero = i;
        }
    }

    BOOL shown[NSDCFUnitCount];
    int shownCount = 0;
    for (int i = 0; i < NSDCFUnitCount; i++)
    {
        if (!allowed[i])
        {
            shown[i] = NO;
            continue;
        }
        if (values[i] != 0)
        {
            shown[i] = YES;
        }
        else if (firstNonZero < 0 || i < firstNonZero)
        {
            shown[i] = (zeros & NSDateComponentsFormatterZeroFormattingBehaviorDropLeading) == 0;
        }
        else if (i > lastNonZero)
        {
            shown[i] = (zeros & NSDateComponentsFormatterZeroFormattingBehaviorDropTrailing) == 0;
        }
        else
        {
            shown[i] = (zeros & NSDateComponentsFormatterZeroFormattingBehaviorDropMiddle) == 0;
        }
        shownCount += shown[i];
    }

    // Keep the smallest unit ("0s"); a positional clock keeps two of its units ("0:05").
    if (shownCount == 0)
    {
        shown[smallest] = YES;
        shownCount = 1;
    }
    for (int i = smallest; positional && i >= NSDCFHour && shownCount < 2; i--)
    {
        if (allowed[i] && !shown[i] && (firstNonZero < 0 || i < firstNonZero))
        {
            shown[i] = YES;
            shownCount++;
        }
    }

    for (int i = 0; negative && firstNonZero >= 0 && i < NSDCFUnitCount; i++)
    {
        if (shown[i])
        {
            values[i] = -values[i];
            break;
        }
    }

    NSString *localeIdentifier = [[calendar locale] localeIdentifier];
    if ([localeIdentifier length] == 0)
    {
        localeIdentifier = [[NSLocale currentLocale] localeIdentifier];
    }
    const char *localeID = [localeIdentifier UTF8String];

    if (positional)
    {
        return [self _positionalStringWithValues:values shown:shown locale:localeID];
    }
    return [self _unitsStringWithValues:values shown:shown locale:localeID];
}

- (NSString *)_positionalStringWithValues:(const double *)values shown:(const BOOL *)shown locale:(const char *)locale
{
    BOOL hasHour = shown[NSDCFHour], hasMinute = shown[NSDCFMinute], hasSecond = shown[NSDCFSecond];
    if (hasHour && hasSecond && !hasMinute)
    {
        [NSException raise:NSInvalidArgumentException
                    format:@"NSDateComponentsFormatter: dropping minutes between hours and seconds is ambiguous in the positional style"];
    }
    BOOL numeric = hasHour + hasMinute + hasSecond >= 2;
    BOOL padAll = (_zeroFormattingBehavior & NSDateComponentsFormatterZeroFormattingBehaviorPad) != 0;

    // Units a clock face cannot show (and a lone hour, minute or second) fall back to abbreviated units.
    UErrorCode status = U_ZERO_ERROR;
    UAMeasureFormat *narrow = uameasfmt_open(locale, UAMEASFMT_WIDTH_NARROW, NULL, &status);
    if (U_FAILURE(status))
    {
        return nil;
    }
    NSMutableArray *parts = [NSMutableArray array];
    for (int i = 0; i < NSDCFUnitCount; i++)
    {
        if (!shown[i] || (numeric && i >= NSDCFHour))
        {
            continue;
        }
        NSString *part = NSDCFFormatMeasure(narrow, values[i], i);
        if (part == nil)
        {
            uameasfmt_close(narrow);
            return nil;
        }
        [parts addObject:part];
    }
    uameasfmt_close(narrow);
    if (numeric)
    {
        NSString *clock = NSDCFFormatPositional(locale, values, hasHour, hasSecond, padAll);
        if (clock == nil)
        {
            return nil;
        }
        [parts addObject:clock];
    }
    return NSDCFJoinUnits(parts, locale, ULISTFMT_WIDTH_NARROW);
}

- (NSString *)_unitsStringWithValues:(const double *)values shown:(const BOOL *)shown locale:(const char *)locale
{
    UAMeasureFormatWidth width;
    switch (_unitsStyle)
    {
        case NSDateComponentsFormatterUnitsStyleAbbreviated: width = UAMEASFMT_WIDTH_NARROW; break;
        case NSDateComponentsFormatterUnitsStyleShort: width = UAMEASFMT_WIDTH_SHORT; break;
        case NSDateComponentsFormatterUnitsStyleBrief: width = UAMEASFMT_WIDTH_SHORTER; break;
        case NSDateComponentsFormatterUnitsStyleFull:
        case NSDateComponentsFormatterUnitsStyleSpellOut: width = UAMEASFMT_WIDTH_WIDE; break;
        default:
            [NSException raise:NSInvalidArgumentException format:@"Invalid NSDateComponentsFormatterUnitsStyle %ld", (long)_unitsStyle];
            return nil;
    }

    UErrorCode status = U_ZERO_ERROR;
    BOOL spellOut = _unitsStyle == NSDateComponentsFormatterUnitsStyleSpellOut;
    UNumberFormat *numberFormat = spellOut ? unum_open(UNUM_SPELLOUT, NULL, 0, locale, NULL, &status) : NULL;
    // Adopts numberFormat, also when it fails; after a failed unum_open it opens nothing.
    UAMeasureFormat *format = uameasfmt_open(locale, width, numberFormat, &status);
    if (U_FAILURE(status))
    {
        return nil;
    }

    NSString *result;
    if (spellOut)
    {
        // uameasfmt_formatMultiple spells out only the last value.
        NSMutableArray *parts = [NSMutableArray array];
        BOOL failed = NO;
        for (int i = 0; i < NSDCFUnitCount && !failed; i++)
        {
            if (shown[i])
            {
                NSString *part = NSDCFFormatMeasure(format, values[i], i);
                failed = part == nil;
                if (!failed)
                {
                    [parts addObject:part];
                }
            }
        }
        result = failed ? nil : NSDCFJoinUnits(parts, locale, ULISTFMT_WIDTH_WIDE);
    }
    else
    {
        UAMeasure measures[NSDCFUnitCount];
        int32_t count = 0;
        for (int i = 0; i < NSDCFUnitCount; i++)
        {
            if (shown[i])
            {
                measures[count].value = values[i];
                measures[count].unit = NSDCFMeasureUnits[i];
                count++;
            }
        }
        const UAMeasure *list = measures;
        result = NSDCFStringFromICU(^int32_t(UChar *buffer, int32_t capacity, UErrorCode *error) {
            return uameasfmt_formatMultiple(format, list, count, buffer, capacity, error);
        });
    }
    uameasfmt_close(format);
    return result;
}

@end
