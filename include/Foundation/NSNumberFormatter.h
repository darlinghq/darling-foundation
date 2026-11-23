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
@property (copy) NSString *format;
@property (copy) NSString *negativeFormat;
@property (copy) NSDictionary<NSString *, id> *textAttributesForNegativeValues;
@property (copy) NSString *positiveFormat;
@property (copy) NSDictionary<NSString *, id> *textAttributesForPositiveValues;
@property BOOL allowsFloats;
@property (copy) NSString *decimalSeparator;
@property BOOL alwaysShowsDecimalSeparator;
@property (copy) NSString *currencyDecimalSeparator;
@property BOOL usesGroupingSeparator;
@property (copy) NSString *groupingSeparator;
@property (copy) NSString *thousandSeparator;
@property BOOL hasThousandSeparators;
@property BOOL localizesFormat;
@property (copy) NSString *zeroSymbol;
@property (copy) NSDictionary<NSString *, id> *textAttributesForZero;
@property (copy) NSString *nilSymbol;
@property (copy) NSDictionary<NSString *, id> *textAttributesForNil;
@property (copy) NSString *notANumberSymbol;
@property (copy) NSDictionary<NSString *, id> *textAttributesForNotANumber;
@property (copy) NSString *positiveInfinitySymbol;
@property (copy) NSDictionary<NSString *, id> *textAttributesForPositiveInfinity;
@property (copy) NSString *negativeInfinitySymbol;
@property (copy) NSDictionary<NSString *, id> *textAttributesForNegativeInfinity;
@property (copy) NSString *positivePrefix;
@property (copy) NSString *positiveSuffix;
@property (copy) NSString *negativePrefix;
@property (copy) NSString *negativeSuffix;
@property (copy) NSString *currencyCode;
@property (copy) NSString *currencySymbol;
@property (copy) NSString *internationalCurrencySymbol;
@property (copy) NSString *percentSymbol;
@property (copy) NSString *perMillSymbol;
@property (copy) NSString *minusSign;
@property (copy) NSString *plusSign;
@property (copy) NSString *exponentSymbol;
@property NSUInteger groupingSize;
@property NSUInteger secondaryGroupingSize;
@property (copy) NSNumber *multiplier;
@property NSUInteger formatWidth;
@property (copy) NSString *paddingCharacter;
@property NSNumberFormatterPadPosition paddingPosition;
@property NSNumberFormatterRoundingMode roundingMode;
@property (copy) NSNumber *roundingIncrement;
@property NSUInteger minimumIntegerDigits;
@property NSUInteger maximumIntegerDigits;
@property NSUInteger minimumFractionDigits;
@property NSUInteger maximumFractionDigits;
@property (copy) NSNumber *minimum;
@property (copy) NSNumber *maximum;
@property (copy) NSString *currencyGroupingSeparator;
@property (getter=isLenient) BOOL lenient;
@property BOOL usesSignificantDigits;
@property NSUInteger minimumSignificantDigits;
@property NSUInteger maximumSignificantDigits;
@property (getter=isPartialStringValidationEnabled) BOOL partialStringValidationEnabled;

@end
