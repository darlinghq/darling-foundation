#import <Foundation/NSFormatter.h>
#import <Foundation/NSDictionary.h>
#import <CoreFoundation/CFNumberFormatter.h>

typedef NS_ENUM(NSUInteger, NSNumberFormatterStyle) {
    NSNumberFormatterNoStyle = kCFNumberFormatterNoStyle,
    NSNumberFormatterDecimalStyle = kCFNumberFormatterDecimalStyle,
    NSNumberFormatterCurrencyStyle = kCFNumberFormatterCurrencyStyle,
    NSNumberFormatterPercentStyle = kCFNumberFormatterPercentStyle,
    NSNumberFormatterScientificStyle = kCFNumberFormatterScientificStyle,
    NSNumberFormatterSpellOutStyle = kCFNumberFormatterSpellOutStyle
};

typedef NS_ENUM(NSUInteger, NSNumberFormatterBehavior) {
    NSNumberFormatterBehaviorDefault = 0,
    NSNumberFormatterBehavior10_4 = 1040,
};

typedef NS_ENUM(NSUInteger, NSNumberFormatterPadPosition) {
    NSNumberFormatterPadBeforePrefix = kCFNumberFormatterPadBeforePrefix,
    NSNumberFormatterPadAfterPrefix = kCFNumberFormatterPadAfterPrefix,
    NSNumberFormatterPadBeforeSuffix = kCFNumberFormatterPadBeforeSuffix,
    NSNumberFormatterPadAfterSuffix = kCFNumberFormatterPadAfterSuffix
};

typedef NS_ENUM(NSUInteger, NSNumberFormatterRoundingMode) {
    NSNumberFormatterRoundCeiling = kCFNumberFormatterRoundCeiling,
    NSNumberFormatterRoundFloor = kCFNumberFormatterRoundFloor,
    NSNumberFormatterRoundDown = kCFNumberFormatterRoundDown,
    NSNumberFormatterRoundUp = kCFNumberFormatterRoundUp,
    NSNumberFormatterRoundHalfEven = kCFNumberFormatterRoundHalfEven,
    NSNumberFormatterRoundHalfDown = kCFNumberFormatterRoundHalfDown,
    NSNumberFormatterRoundHalfUp = kCFNumberFormatterRoundHalfUp
};

@class NSLocale, NSError, NSMutableDictionary;

typedef struct __CFNumberFormatter* CFNumberFormatterRef;

@interface NSNumberFormatter : NSFormatter
{
    NSMutableDictionary *_attributes;
    CFNumberFormatterRef _formatter;
}

+ (NSString *)localizedStringFromNumber:(NSNumber *)num numberStyle:(NSNumberFormatterStyle)nstyle;
+ (NSNumberFormatterBehavior)defaultFormatterBehavior;
+ (void)setDefaultFormatterBehavior:(NSNumberFormatterBehavior)behavior;
- (id _Nonnull)init;
- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string range:(inout NSRange *)rangep error:(out NSError **)error;
- (NSString *)stringFromNumber:(NSNumber *)number;
- (NSNumber *)numberFromString:(NSString *)string;
@property NSNumberFormatterStyle numberStyle;
@property (retain) NSLocale *locale;
@property BOOL generatesDecimalNumbers;
@property NSNumberFormatterBehavior formatterBehavior;
@property (nonnull, copy) NSString *format;
@property (null_resettable, copy) NSString *negativeFormat;
@property (nullable, copy) NSDictionary<NSString *, id> *textAttributesForNegativeValues;
@property (null_resettable, copy) NSString *positiveFormat;
@property (nullable, copy) NSDictionary<NSString *, id> *textAttributesForPositiveValues;
@property BOOL allowsFloats;
@property (null_resettable, copy) NSString *decimalSeparator;
@property BOOL alwaysShowsDecimalSeparator;
@property (null_resettable, copy) NSString *currencyDecimalSeparator;
@property BOOL usesGroupingSeparator;
@property (null_resettable, copy) NSString *groupingSeparator;
@property (null_resettable, copy) NSString *thousandSeparator;
@property BOOL hasThousandSeparators;
@property BOOL localizesFormat;
@property (nullable, copy) NSString *zeroSymbol;
@property (nullable, copy) NSDictionary<NSString *, id> *textAttributesForZero;
@property (nonnull, copy) NSString *nilSymbol;
@property (nullable, copy) NSDictionary<NSString *, id> *textAttributesForNil;
@property (null_resettable, copy) NSString *notANumberSymbol;
@property (nullable, copy) NSDictionary<NSString *, id> *textAttributesForNotANumber;
@property (nonnull, copy) NSString *positiveInfinitySymbol;
@property (nullable, copy) NSDictionary<NSString *, id> *textAttributesForPositiveInfinity;
@property (nonnull, copy) NSString *negativeInfinitySymbol;
@property (nullable, copy) NSDictionary<NSString *, id> *textAttributesForNegativeInfinity;
@property (null_resettable, copy) NSString *positivePrefix;
@property (null_resettable, copy) NSString *positiveSuffix;
@property (null_resettable, copy) NSString *negativePrefix;
@property (null_resettable, copy) NSString *negativeSuffix;
@property (null_resettable, copy) NSString *currencyCode;
@property (null_resettable, copy) NSString *currencySymbol;
@property (null_resettable, copy) NSString *internationalCurrencySymbol;
@property (null_resettable, copy) NSString *percentSymbol;
@property (null_resettable, copy) NSString *perMillSymbol;
@property (null_resettable, copy) NSString *minusSign;
@property (null_resettable, copy) NSString *plusSign;
@property (null_resettable, copy) NSString *exponentSymbol;
@property NSUInteger groupingSize;
@property NSUInteger secondaryGroupingSize;
@property (nullable, copy) NSNumber *multiplier;
@property NSUInteger formatWidth;
@property (null_resettable, copy) NSString *paddingCharacter;
@property NSNumberFormatterPadPosition paddingPosition;
@property NSNumberFormatterRoundingMode roundingMode;
@property (null_resettable, copy) NSNumber *roundingIncrement;
@property NSUInteger minimumIntegerDigits;
@property NSUInteger maximumIntegerDigits;
@property NSUInteger minimumFractionDigits;
@property NSUInteger maximumFractionDigits;
@property (nullable, copy) NSNumber *minimum;
@property (nullable, copy) NSNumber *maximum;
@property (null_resettable, copy) NSString *currencyGroupingSeparator;
@property (getter=isLenient) BOOL lenient;
@property BOOL usesSignificantDigits;
@property NSUInteger minimumSignificantDigits;
@property NSUInteger maximumSignificantDigits;
@property (getter=isPartialStringValidationEnabled) BOOL partialStringValidationEnabled;

@end
