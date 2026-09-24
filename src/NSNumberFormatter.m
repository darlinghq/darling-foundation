//
//  NSNumberFormatter.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <CoreFoundation/CFNumberFormatter.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSString.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSException.h>
#import <Foundation/NSArray.h>

// Splits a number pattern at the semicolons outside '...' quotes.
static NSArray *patternSegments(NSString *pattern)
{
    NSMutableArray *segments = [NSMutableArray array];
    NSUInteger start = 0;
    BOOL quoted = NO;
    for (NSUInteger i = 0; i < [pattern length]; i++)
    {
        unichar c = [pattern characterAtIndex:i];
        if (c == '\'')
        {
            quoted = !quoted;
        }
        else if (c == ';' && !quoted)
        {
            [segments addObject:[pattern substringWithRange:NSMakeRange(start, i - start)]];
            start = i + 1;
        }
    }
    [segments addObject:[pattern substringFromIndex:start]];
    return segments;
}

// The text of a pattern without digit placeholders ("'none'", "-"), with ICU quoting
// removed; nil when the pattern has digits and must be formatted.
static NSString *literalPattern(NSString *pattern)
{
    NSMutableString *text = [NSMutableString string];
    BOOL quoted = NO;
    for (NSUInteger i = 0; i < [pattern length]; i++)
    {
        unichar c = [pattern characterAtIndex:i];
        if (c == '\'')
        {
            if (i + 1 < [pattern length] && [pattern characterAtIndex:i + 1] == '\'')
            {
                [text appendString:@"'"];
                i++;
            }
            else
            {
                quoted = !quoted;
            }
            continue;
        }
        if (!quoted && ((c >= '0' && c <= '9') || c == '#' || c == '@'))
        {
            return nil;
        }
        [text appendFormat:@"%C", c];
    }
    return text;
}

@implementation NSNumberFormatter

+ (NSString *)localizedStringFromNumber:(NSNumber *)num numberStyle:(NSNumberFormatterStyle)nstyle
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:nstyle];
    NSString *str = [formatter stringFromNumber:num];
    [formatter release];
    return str;
}

static NSNumberFormatterBehavior defaultBehavior = NSNumberFormatterBehaviorDefault;

+ (NSNumberFormatterBehavior)defaultFormatterBehavior
{
    return defaultBehavior;
}

+ (void)setDefaultFormatterBehavior:(NSNumberFormatterBehavior)behavior
{
    defaultBehavior = behavior;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _attributes = [[NSMutableDictionary alloc] init];
        [self setAllowsFloats:YES];
        [self setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [self setNilSymbol:@""];
        [self setNegativeInfinitySymbol:[NSString stringWithUTF8String:"-∞"]];
        [self setPositiveInfinitySymbol:[NSString stringWithUTF8String:"+∞"]];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter->_attributes release];
    formatter->_attributes = [_attributes copy];
    return formatter;
}

- (void)dealloc
{
    [self _clearFormatter];
    [_attributes release];
    [super dealloc];
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)errorStr
{
    NSError *error = nil;
    NSRange r;
    BOOL success = [self getObjectValue:obj forString:string range:&r error:&error];
    if (errorStr != NULL)
    {
        *errorStr = [error localizedDescription];
    }
    return success;
}

- (NSString *)stringFromNumber:(NSNumber *)number
{
    if (number == nil) {
        return nil;
    }
    [self _regenerateFormatter];
    return [(NSString *)CFNumberFormatterCreateStringWithNumber(kCFAllocatorDefault, _formatter, (CFNumberRef)number) autorelease];
}

- (NSNumber *)numberFromString:(NSString *)string
{
    if (string == nil) {
        return nil;
    }
    [self _regenerateFormatter];
    return [(NSNumber *)CFNumberFormatterCreateNumberFromString(kCFAllocatorDefault, _formatter, (CFStringRef)string, NULL, [_attributes[@"parseIntegersOnly"] boolValue] ? kCFNumberFormatterParseIntegersOnly : 0) autorelease];
}

- (NSNumberFormatterStyle)numberStyle
{
    [self _regenerateFormatter];
    return (NSNumberFormatterStyle)CFNumberFormatterGetStyle(_formatter);
}

- (void)setNumberStyle:(NSNumberFormatterStyle)style
{
    _attributes[@"style"] = @(style);
    [_attributes removeObjectsForKeys:@[@"positiveFormat", @"zeroFormat", @"negativeFormat"]];
    [self _reset];
}

- (NSLocale *)locale
{
    [self _regenerateFormatter];
    return (NSLocale *)CFNumberFormatterGetLocale(_formatter);
}

- (void)setLocale:(NSLocale *)locale
{
    if (locale == nil)
    {
        locale = [NSLocale currentLocale];
    }
    _attributes[@"locale"] = locale;
    [self _reset];
}

- (BOOL)generatesDecimalNumbers
{
    return [_attributes[@"generatesDecimalNumbers"] boolValue];
}

- (void)setGeneratesDecimalNumbers:(BOOL)b
{
    _attributes[@"generatesDecimalNumbers"] = @(b);
}

- (NSNumberFormatterBehavior)formatterBehavior
{
    return [_attributes[@"formatterBehavior"] intValue];
}

- (void)setFormatterBehavior:(NSNumberFormatterBehavior)behavior
{
    _attributes[@"formatterBehavior"] = @(behavior);
}

- (void)_setAttribute:(NSString *)key toPattern:(NSString *)pattern
{
    if ([pattern length] > 0)
    {
        _attributes[key] = [[pattern copy] autorelease];
    }
    else
    {
        [_attributes removeObjectForKey:key];
    }
    [self _clearFormatter];
}

- (NSString *)format
{
    NSString *zero = _attributes[@"zeroFormat"];
    if (zero != nil)
    {
        return [NSString stringWithFormat:@"%@;%@;%@", [self positiveFormat], zero, [self negativeFormat]];
    }
    return [NSString stringWithFormat:@"%@;%@", [self positiveFormat], [self negativeFormat]];
}

// "positive", "positive;negative" or "positive;zero;negative"
- (void)setFormat:(NSString *)format
{
    NSArray *segments = patternSegments(format ?: @"");
    NSUInteger count = [segments count];
    if (count > 3)
    {
        [NSException raise:NSInvalidArgumentException format:@"-[NSNumberFormatter setFormat:]: more than three patterns in \"%@\"", format];
    }
    [self _setAttribute:@"positiveFormat" toPattern:segments[0]];
    [self _setAttribute:@"zeroFormat" toPattern:count == 3 ? segments[1] : nil];
    [self _setAttribute:@"negativeFormat" toPattern:count > 1 ? segments[count - 1] : nil];
}

- (NSString *)negativeFormat
{
    NSString *format = _attributes[@"negativeFormat"];
    if (format != nil)
    {
        return format;
    }
    // Without a negative pattern, negatives get the minus sign before the positive pattern.
    NSString *positive = [self positiveFormat];
    return positive != nil ? [@"-" stringByAppendingString:positive] : nil;
}

- (void)setNegativeFormat:(NSString *)format
{
    [self _setAttribute:@"negativeFormat" toPattern:format];
}

- (NSDictionary *)textAttributesForNegativeValues
{
    return _attributes[@"textAttributesForNegativeValues"];
}

- (void)setTextAttributesForNegativeValues:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForNegativeValues"] = newAttributes;
}

- (NSString *)positiveFormat
{
    NSString *format = _attributes[@"positiveFormat"];
    if (format != nil)
    {
        return format;
    }
    [self _regenerateFormatter];
    if (_formatter == NULL)
    {
        return nil;
    }
    return patternSegments((NSString *)CFNumberFormatterGetFormat(_formatter))[0];
}

- (void)setPositiveFormat:(NSString *)format
{
    [self _setAttribute:@"positiveFormat" toPattern:format];
}

- (NSDictionary *)textAttributesForPositiveValues
{
    return _attributes[@"textAttributesForPositiveValues"];
}

- (void)setTextAttributesForPositiveValues:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForPositiveValues"] = newAttributes;
}

- (BOOL)allowsFloats
{
    return [_attributes[@"allowsFloats"] boolValue];
}

- (void)setAllowsFloats:(BOOL)flag
{
    _attributes[@"allowsFloats"] = @(flag);
}


#define GET_BOOL(prop) ({ \
    if (_formatter == NULL) { \
        [self _reset]; \
    } \
    [[(NSNumber *)CFNumberFormatterCopyProperty(_formatter, (prop)) autorelease] boolValue]; \
});

#define SET_BOOL(prop, val) \
_attributes[(id)(prop)] = @(val); \
if (_formatter != NULL) { \
    CFNumberFormatterSetProperty(_formatter, (prop), (CFTypeRef)@(val)); \
}

#define GET_UNSIGNEDINTEGER(prop) ({ \
    if (_formatter == NULL) { \
        [self _reset]; \
    } \
    [[(NSNumber *)CFNumberFormatterCopyProperty(_formatter, (prop)) autorelease] unsignedIntegerValue]; \
})

#define SET_UNSIGNEDINTEGER(prop, val) \
_attributes[(id)(prop)] = @(val); \
if (_formatter != NULL) { \
    CFNumberFormatterSetProperty(_formatter, (prop), (CFTypeRef)@(val)); \
}

#define GET_ID(prop) ({ \
    if (_formatter == NULL) { \
        [self _reset]; \
    } \
    [(id)CFNumberFormatterCopyProperty(_formatter, (prop)) autorelease]; \
})

#define SET_ID(prop, val) \
_attributes[(id)(prop)] = (val); \
if (_formatter != NULL) { \
    CFNumberFormatterSetProperty(_formatter, (prop), (CFTypeRef)val); \
}

- (NSString *)decimalSeparator
{
    return GET_ID(kCFNumberFormatterDecimalSeparator);
}

- (void)setDecimalSeparator:(NSString *)string
{
    SET_ID(kCFNumberFormatterDecimalSeparator, string);
}

- (BOOL)alwaysShowsDecimalSeparator
{
    return GET_BOOL(kCFNumberFormatterAlwaysShowDecimalSeparator);
}

- (void)setAlwaysShowsDecimalSeparator:(BOOL)b
{
    SET_BOOL(kCFNumberFormatterAlwaysShowDecimalSeparator, b);
}

- (NSString *)currencyDecimalSeparator
{
    return GET_ID(kCFNumberFormatterCurrencyDecimalSeparator);
}

- (void)setCurrencyDecimalSeparator:(NSString *)string
{
    SET_ID(kCFNumberFormatterCurrencyDecimalSeparator, string);
}

- (BOOL)usesGroupingSeparator
{
    return GET_BOOL(kCFNumberFormatterUseGroupingSeparator);
}

- (void)setUsesGroupingSeparator:(BOOL)b
{
    SET_BOOL(kCFNumberFormatterUseGroupingSeparator, b);
}

- (NSString *)groupingSeparator
{
    return GET_ID(kCFNumberFormatterGroupingSeparator);
}

- (void)setGroupingSeparator:(NSString *)string
{
    SET_ID(kCFNumberFormatterGroupingSeparator, string);
}

// Read back what was set: the formatter's own zero symbol may come from a zero pattern.
- (NSString *)zeroSymbol
{
    return _attributes[(id)kCFNumberFormatterZeroSymbol];
}

// Rebuilds the formatter so that clearing the symbol brings back a zero pattern.
- (void)setZeroSymbol:(NSString *)string
{
    if (string != nil)
    {
        _attributes[(id)kCFNumberFormatterZeroSymbol] = [[string copy] autorelease];
    }
    else
    {
        [_attributes removeObjectForKey:(id)kCFNumberFormatterZeroSymbol];
    }
    [self _clearFormatter];
}

- (NSDictionary *)textAttributesForZero
{
    return _attributes[@"textAttributesForZero"];
}

- (void)setTextAttributesForZero:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForZero"] = newAttributes;
}

- (NSString *)nilSymbol
{
    return _attributes[@"nilSymbol"];
}

- (void)setNilSymbol:(NSString *)string
{
    _attributes[@"nilSymbol"] = string;
}

- (NSDictionary *)textAttributesForNil
{
    return _attributes[@"textAttributesForNil"];
}

- (void)setTextAttributesForNil:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForNil"] = newAttributes;
}

- (NSString *)notANumberSymbol
{
    return GET_ID(kCFNumberFormatterNaNSymbol);
}

- (void)setNotANumberSymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterNaNSymbol, string);
}

- (NSDictionary *)textAttributesForNotANumber
{
    return _attributes[@"textAttributesForNotANumber"]; 
}

- (void)setTextAttributesForNotANumber:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForNotANumber"] = newAttributes;
}

- (NSString *)positiveInfinitySymbol
{
    return _attributes[@"positiveInfinitySymbol"];
}

- (void)setPositiveInfinitySymbol:(NSString *)string
{
    _attributes[@"positiveInfinitySymbol"] = string;
}

- (NSDictionary *)textAttributesForPositiveInfinity
{
    return _attributes[@"textAttributesForPositiveInfinity"];
}

- (void)setTextAttributesForPositiveInfinity:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForPositiveInfinity"] = newAttributes;
}


- (NSString *)negativeInfinitySymbol
{
    return _attributes[@"negativeInfinitySymbol"];
}

- (void)setNegativeInfinitySymbol:(NSString *)string
{
    _attributes[@"negativeInfinitySymbol"] = string;
}

- (NSDictionary *)textAttributesForNegativeInfinity
{
    return _attributes[@"textAttributesForNegativeInfinity"];
}

- (void)setTextAttributesForNegativeInfinity:(NSDictionary *)newAttributes
{
    _attributes[@"textAttributesForNegativeInfinity"] = newAttributes;
}

- (NSString *)positivePrefix
{
    return GET_ID(kCFNumberFormatterPositivePrefix);
}

- (void)setPositivePrefix:(NSString *)string
{
    SET_ID(kCFNumberFormatterPositivePrefix, string);
}

- (NSString *)positiveSuffix
{
    return GET_ID(kCFNumberFormatterPositiveSuffix);
}

- (void)setPositiveSuffix:(NSString *)string
{
    SET_ID(kCFNumberFormatterPositiveSuffix, string);
}

- (NSString *)negativePrefix
{
    return GET_ID(kCFNumberFormatterNegativePrefix);
}

- (void)setNegativePrefix:(NSString *)string
{
    SET_ID(kCFNumberFormatterNegativePrefix, string);
}

- (NSString *)negativeSuffix
{
    return GET_ID(kCFNumberFormatterNegativeSuffix);
}

- (void)setNegativeSuffix:(NSString *)string
{
    SET_ID(kCFNumberFormatterNegativeSuffix, string);
}

- (NSString *)currencyCode
{
    return GET_ID(kCFNumberFormatterCurrencyCode);
}

- (void)setCurrencyCode:(NSString *)string
{
    SET_ID(kCFNumberFormatterCurrencyCode, string);
}

- (NSString *)currencySymbol
{
    return GET_ID(kCFNumberFormatterCurrencySymbol);
}

- (void)setCurrencySymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterCurrencySymbol, string);
}

- (NSString *)internationalCurrencySymbol
{
    return GET_ID(kCFNumberFormatterInternationalCurrencySymbol);
}

- (void)setInternationalCurrencySymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterInternationalCurrencySymbol, string);
}

- (NSString *)percentSymbol
{
    return GET_ID(kCFNumberFormatterPercentSymbol);
}

- (void)setPercentSymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterPercentSymbol, string);
}

- (NSString *)perMillSymbol
{
    return GET_ID(kCFNumberFormatterPerMillSymbol);
}

- (void)setPerMillSymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterPerMillSymbol, string);
}

- (NSString *)minusSign
{
    return GET_ID(kCFNumberFormatterMinusSign);
}

- (void)setMinusSign:(NSString *)string
{
    SET_ID(kCFNumberFormatterMinusSign, string);
}

- (NSString *)plusSign
{
    return GET_ID(kCFNumberFormatterPlusSign);
}

- (void)setPlusSign:(NSString *)string
{
    SET_ID(kCFNumberFormatterPlusSign, string);
}

- (NSString *)exponentSymbol
{
    return GET_ID(kCFNumberFormatterExponentSymbol);
}

- (void)setExponentSymbol:(NSString *)string
{
    SET_ID(kCFNumberFormatterExponentSymbol, string);
}

- (NSUInteger)groupingSize
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterGroupingSize);
}

- (void)setGroupingSize:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterGroupingSize, number);
}

- (NSUInteger)secondaryGroupingSize
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterSecondaryGroupingSize);
}

- (void)setSecondaryGroupingSize:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterSecondaryGroupingSize, number);
}

- (NSNumber *)multiplier
{
    return GET_ID(kCFNumberFormatterMultiplier);
}

- (void)setMultiplier:(NSNumber *)number
{
    SET_ID(kCFNumberFormatterMultiplier, number);
}

- (NSUInteger)formatWidth
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterFormatWidth);
}

- (void)setFormatWidth:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterFormatWidth, number);
}

- (NSString *)paddingCharacter
{
    return GET_ID(kCFNumberFormatterPaddingCharacter);
}

- (void)setPaddingCharacter:(NSString *)string
{
    SET_ID(kCFNumberFormatterPaddingCharacter, string);
}

- (NSNumberFormatterPadPosition)paddingPosition
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterPaddingPosition);
}

- (void)setPaddingPosition:(NSNumberFormatterPadPosition)position
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterPaddingPosition, position);
}

- (NSNumberFormatterRoundingMode)roundingMode
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterRoundingMode);
}

- (void)setRoundingMode:(NSNumberFormatterRoundingMode)mode
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterRoundingMode, mode);
}

- (NSNumber *)roundingIncrement
{
    return GET_ID(kCFNumberFormatterRoundingIncrement);
}

- (void)setRoundingIncrement:(NSNumber *)number
{
    SET_ID(kCFNumberFormatterRoundingIncrement, number);
}

- (NSUInteger)minimumIntegerDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMinIntegerDigits);
}

- (void)setMinimumIntegerDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMinIntegerDigits, number);
}

- (NSUInteger)maximumIntegerDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMaxIntegerDigits);
}

- (void)setMaximumIntegerDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMaxIntegerDigits, number);
}

- (NSUInteger)minimumFractionDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMinFractionDigits);
}

- (void)setMinimumFractionDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMinFractionDigits, number);
}

- (NSUInteger)maximumFractionDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMaxFractionDigits);
}

- (void)setMaximumFractionDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMaxFractionDigits, number);
}

- (NSString *)currencyGroupingSeparator
{
    return GET_ID(kCFNumberFormatterCurrencyGroupingSeparator);
}

- (void)setCurrencyGroupingSeparator:(NSString *)string
{
    SET_ID(kCFNumberFormatterCurrencyGroupingSeparator, string);
}

- (BOOL)isLenient
{
    return GET_BOOL(kCFNumberFormatterIsLenient);
}

- (void)setLenient:(BOOL)b
{
    SET_BOOL(kCFNumberFormatterIsLenient, b);
}

- (BOOL)usesSignificantDigits
{
    return GET_BOOL(kCFNumberFormatterUseSignificantDigits);
}

- (void)setUsesSignificantDigits:(BOOL)b
{
    SET_BOOL(kCFNumberFormatterUseSignificantDigits, b);
}

- (NSUInteger)minimumSignificantDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMinSignificantDigits);
}

- (void)setMinimumSignificantDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMinSignificantDigits, number);
}

- (NSUInteger)maximumSignificantDigits
{
    return GET_UNSIGNEDINTEGER(kCFNumberFormatterMaxSignificantDigits);
}

- (void)setMaximumSignificantDigits:(NSUInteger)number
{
    SET_UNSIGNEDINTEGER(kCFNumberFormatterMaxSignificantDigits, number);
}

- (void)_reset
{
    [self _clearFormatter];
    [self _regenerateFormatter];
}

- (void)_regenerateFormatter
{
    if (_formatter != NULL)
    {
        return;
    }
    // NOTE: _attributes stores both the creation/parameters AND properties, so a simple iterator wont work
    _formatter = CFNumberFormatterCreate(kCFAllocatorDefault, (CFLocaleRef)_attributes[@"locale"] ?: (CFLocaleRef)[NSLocale currentLocale], [_attributes[@"style"] intValue]);

    if (_formatter == nil)
    {
        DEBUG_LOG("Number Formatter creation failed.  Are ICU tables built in?");
        return;
    }

    NSString *positive = _attributes[@"positiveFormat"];
    NSString *negative = _attributes[@"negativeFormat"];
    if (positive != nil || negative != nil)
    {
        positive = positive ?: patternSegments((NSString *)CFNumberFormatterGetFormat(_formatter))[0];
        NSString *pattern = negative != nil ? [NSString stringWithFormat:@"%@;%@", positive, negative] : positive;
        CFNumberFormatterSetFormat(_formatter, (CFStringRef)pattern);
    }
    NSString *zero = _attributes[@"zeroFormat"];
    if (zero != nil && _attributes[(id)kCFNumberFormatterZeroSymbol] == nil)
    {
        NSString *symbol = literalPattern(zero);
        if (symbol == nil)
        {
            CFNumberFormatterRef zeroFormatter = CFNumberFormatterCreate(kCFAllocatorDefault, CFNumberFormatterGetLocale(_formatter), kCFNumberFormatterNoStyle);
            CFNumberFormatterSetFormat(zeroFormatter, (CFStringRef)zero);
            symbol = [(NSString *)CFNumberFormatterCreateStringWithNumber(kCFAllocatorDefault, zeroFormatter, (CFNumberRef)@0) autorelease];
            CFRelease(zeroFormatter);
        }
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterZeroSymbol, (CFStringRef)symbol);
    }
    if (_attributes[(id)kCFNumberFormatterCurrencyCode])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterCurrencyCode, (CFTypeRef)_attributes[(id)kCFNumberFormatterCurrencyCode]);
    }
    if (_attributes[(id)kCFNumberFormatterDecimalSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterDecimalSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterDecimalSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterCurrencyDecimalSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterCurrencyDecimalSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterCurrencyDecimalSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterAlwaysShowDecimalSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterAlwaysShowDecimalSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterAlwaysShowDecimalSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterGroupingSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterGroupingSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterGroupingSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterUseGroupingSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterUseGroupingSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterUseGroupingSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterPercentSymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPercentSymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterPercentSymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterZeroSymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterZeroSymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterZeroSymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterNaNSymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterNaNSymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterNaNSymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterInfinitySymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterInfinitySymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterInfinitySymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterMinusSign])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMinusSign, (CFTypeRef)_attributes[(id)kCFNumberFormatterMinusSign]);
    }
    if (_attributes[(id)kCFNumberFormatterPlusSign])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPlusSign, (CFTypeRef)_attributes[(id)kCFNumberFormatterPlusSign]);
    }
    if (_attributes[(id)kCFNumberFormatterCurrencySymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterCurrencySymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterCurrencySymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterExponentSymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterExponentSymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterExponentSymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterMinIntegerDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMinIntegerDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMinIntegerDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterMaxIntegerDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMaxIntegerDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMaxIntegerDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterMinFractionDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMinFractionDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMinFractionDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterMaxFractionDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMaxFractionDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMaxFractionDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterGroupingSize])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterGroupingSize, (CFTypeRef)_attributes[(id)kCFNumberFormatterGroupingSize]);
    }
    if (_attributes[(id)kCFNumberFormatterSecondaryGroupingSize])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterSecondaryGroupingSize, (CFTypeRef)_attributes[(id)kCFNumberFormatterSecondaryGroupingSize]);
    }
    if (_attributes[(id)kCFNumberFormatterRoundingMode])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterRoundingMode, (CFTypeRef)_attributes[(id)kCFNumberFormatterRoundingMode]);
    }
    if (_attributes[(id)kCFNumberFormatterRoundingIncrement])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterRoundingIncrement, (CFTypeRef)_attributes[(id)kCFNumberFormatterRoundingIncrement]);
    }
    if (_attributes[(id)kCFNumberFormatterFormatWidth])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterFormatWidth, (CFTypeRef)_attributes[(id)kCFNumberFormatterFormatWidth]);
    }
    if (_attributes[(id)kCFNumberFormatterPaddingPosition])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPaddingPosition, (CFTypeRef)_attributes[(id)kCFNumberFormatterPaddingPosition]);
    }
    if (_attributes[(id)kCFNumberFormatterPaddingCharacter])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPaddingCharacter, (CFTypeRef)_attributes[(id)kCFNumberFormatterPaddingCharacter]);
    }
    if (_attributes[(id)kCFNumberFormatterDefaultFormat])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterDefaultFormat, (CFTypeRef)_attributes[(id)kCFNumberFormatterDefaultFormat]);
    }
    if (_attributes[(id)kCFNumberFormatterMultiplier])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMultiplier, (CFTypeRef)_attributes[(id)kCFNumberFormatterMultiplier]);
    }
    if (_attributes[(id)kCFNumberFormatterPositivePrefix])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPositivePrefix, (CFTypeRef)_attributes[(id)kCFNumberFormatterPositivePrefix]);
    }
    if (_attributes[(id)kCFNumberFormatterPositiveSuffix])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPositiveSuffix, (CFTypeRef)_attributes[(id)kCFNumberFormatterPositiveSuffix]);
    }
    if (_attributes[(id)kCFNumberFormatterNegativePrefix])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterNegativePrefix, (CFTypeRef)_attributes[(id)kCFNumberFormatterNegativePrefix]);
    }
    if (_attributes[(id)kCFNumberFormatterNegativeSuffix])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterNegativeSuffix, (CFTypeRef)_attributes[(id)kCFNumberFormatterNegativeSuffix]);
    }
    if (_attributes[(id)kCFNumberFormatterPerMillSymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterPerMillSymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterPerMillSymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterInternationalCurrencySymbol])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterInternationalCurrencySymbol, (CFTypeRef)_attributes[(id)kCFNumberFormatterInternationalCurrencySymbol]);
    }
    if (_attributes[(id)kCFNumberFormatterCurrencyGroupingSeparator])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterCurrencyGroupingSeparator, (CFTypeRef)_attributes[(id)kCFNumberFormatterCurrencyGroupingSeparator]);
    }
    if (_attributes[(id)kCFNumberFormatterIsLenient])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterIsLenient, (CFTypeRef)_attributes[(id)kCFNumberFormatterIsLenient]);
    }
    if (_attributes[(id)kCFNumberFormatterUseSignificantDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterUseSignificantDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterUseSignificantDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterMinSignificantDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMinSignificantDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMinSignificantDigits]);
    }
    if (_attributes[(id)kCFNumberFormatterMaxSignificantDigits])
    {
        CFNumberFormatterSetProperty(_formatter, kCFNumberFormatterMaxSignificantDigits, (CFTypeRef)_attributes[(id)kCFNumberFormatterMaxSignificantDigits]);
    }
}

- (void)_clearFormatter
{
    if (_formatter != NULL)
    {
        CFRelease(_formatter);
        _formatter = NULL;
    }
}


@end
