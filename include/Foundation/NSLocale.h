#import <Foundation/NSObject.h>
#import <CoreFoundation/CFLocale.h>

typedef NS_ENUM(NSUInteger, NSLocaleLanguageDirection) {
    NSLocaleLanguageDirectionUnknown     = kCFLocaleLanguageDirectionUnknown,
    NSLocaleLanguageDirectionLeftToRight = kCFLocaleLanguageDirectionLeftToRight,
    NSLocaleLanguageDirectionRightToLeft = kCFLocaleLanguageDirectionRightToLeft,
    NSLocaleLanguageDirectionTopToBottom = kCFLocaleLanguageDirectionTopToBottom,
    NSLocaleLanguageDirectionBottomToTop = kCFLocaleLanguageDirectionBottomToTop
};

@class NSArray, NSDictionary, NSString;

FOUNDATION_EXPORT NSString * const NSCurrentLocaleDidChangeNotification;
FOUNDATION_EXPORT NSString * const NSLocaleIdentifier;
FOUNDATION_EXPORT NSString * const NSLocaleLanguageCode;
FOUNDATION_EXPORT NSString * const NSLocaleCountryCode;
FOUNDATION_EXPORT NSString * const NSLocaleScriptCode;
FOUNDATION_EXPORT NSString * const NSLocaleVariantCode;
FOUNDATION_EXPORT NSString * const NSLocaleExemplarCharacterSet;
FOUNDATION_EXPORT NSString * const NSLocaleCalendar;
FOUNDATION_EXPORT NSString * const NSLocaleCollationIdentifier;
FOUNDATION_EXPORT NSString * const NSLocaleUsesMetricSystem;
FOUNDATION_EXPORT NSString * const NSLocaleLanguageConfidenceHigh;
FOUNDATION_EXPORT NSString * const NSLocaleLanguageConfidenceMedium;
FOUNDATION_EXPORT NSString * const NSLocaleMeasurementSystem;
FOUNDATION_EXPORT NSString * const NSLocaleDecimalSeparator;
FOUNDATION_EXPORT NSString * const NSLocaleGroupingSeparator;
FOUNDATION_EXPORT NSString * const NSLocaleCurrencySymbol;
FOUNDATION_EXPORT NSString * const NSLocaleCurrencyCode;
FOUNDATION_EXPORT NSString * const NSLocaleCollatorIdentifier;
FOUNDATION_EXPORT NSString * const NSLocaleQuotationBeginDelimiterKey;
FOUNDATION_EXPORT NSString * const NSLocaleQuotationEndDelimiterKey;
FOUNDATION_EXPORT NSString * const NSLocaleAlternateQuotationBeginDelimiterKey;
FOUNDATION_EXPORT NSString * const NSLocaleAlternateQuotationEndDelimiterKey;
FOUNDATION_EXPORT NSString * const NSGregorianCalendar;
FOUNDATION_EXPORT NSString * const NSBuddhistCalendar;
FOUNDATION_EXPORT NSString * const NSChineseCalendar;
FOUNDATION_EXPORT NSString * const NSHebrewCalendar;
FOUNDATION_EXPORT NSString * const NSIslamicCalendar;
FOUNDATION_EXPORT NSString * const NSIslamicCivilCalendar;
FOUNDATION_EXPORT NSString * const NSJapaneseCalendar;
FOUNDATION_EXPORT NSString * const NSRepublicOfChinaCalendar;
FOUNDATION_EXPORT NSString * const NSPersianCalendar;
FOUNDATION_EXPORT NSString * const NSIndianCalendar;
FOUNDATION_EXPORT NSString * const NSISO8601Calendar;

@interface NSLocale : NSObject <NSCopying, NSSecureCoding>

- (id)objectForKey:(id)key;
- (NSString *)displayNameForKey:(id)key value:(id)value;

@end

@interface NSLocale (NSExtendedLocale)

@property (readonly, copy) NSString *localeIdentifier;
@property (readonly, copy) NSString *languageCode;
@property (readonly, copy) NSString *languageIdentifier;
@property (readonly, copy) NSString *countryCode;
@property (readonly, copy) NSString *regionCode;
@property (readonly, copy) NSString *scriptCode;
@property (readonly, copy) NSString *variantCode;
@property (readonly, copy) NSCharacterSet *exemplarCharacterSet;
@property (readonly, copy) NSString *calendarIdentifier;
@property (readonly, copy) NSString *collationIdentifier;
@property (readonly) BOOL usesMetricSystem;
@property (readonly, copy) NSString *decimalSeparator;
@property (readonly, copy) NSString *groupingSeparator;
@property (readonly, copy) NSString *currencySymbol;
@property (readonly, copy) NSString *currencyCode;
@property (readonly, copy) NSString *collatorIdentifier;
@property (readonly, copy) NSString *quotationBeginDelimiter;
@property (readonly, copy) NSString *quotationEndDelimiter;
@property (readonly, copy) NSString *alternateQuotationBeginDelimiter;
@property (readonly, copy) NSString *alternateQuotationEndDelimiter;

@end

@interface NSLocale (NSLocaleCreation)

+ (id)systemLocale;
+ (id)currentLocale;
+ (instancetype)autoupdatingCurrentLocale;
+ (instancetype)localeWithLocaleIdentifier:(NSString *)identifier;
- (instancetype)initWithLocaleIdentifier:(NSString *)string;
- (id)init;

@end

@interface NSLocale (NSLocaleDisplayNames)

- (NSString *)localizedStringForLocaleIdentifier:(NSString *)localeIdentifier;
- (NSString *)localizedStringForLanguageCode:(NSString *)languageCode;
- (NSString *)localizedStringForCountryCode:(NSString *)countryCode;
- (NSString *)localizedStringForScriptCode:(NSString *)scriptCode;
- (NSString *)localizedStringForVariantCode:(NSString *)variantCode;
- (NSString *)localizedStringForCollationIdentifier:(NSString *)collationIdentifier;
- (NSString *)localizedStringForCurrencyCode:(NSString *)currencyCode;
- (NSString *)localizedStringForCollatorIdentifier:(NSString *)collatorIdentifier;

@end

@interface NSLocale (NSLocaleGeneralInfo)

+ (NSArray *)availableLocaleIdentifiers;
+ (NSArray *)ISOLanguageCodes;
+ (NSArray *)ISOCountryCodes;
+ (NSArray *)ISOCurrencyCodes;
+ (NSArray *)commonISOCurrencyCodes;
+ (NSArray *)preferredLanguages;
+ (NSDictionary *)componentsFromLocaleIdentifier:(NSString *)string;
+ (NSString *)localeIdentifierFromComponents:(NSDictionary *)dict;
+ (NSString *)canonicalLocaleIdentifierFromString:(NSString *)string;
+ (NSString *)canonicalLanguageIdentifierFromString:(NSString *)string;
+ (NSString *)localeIdentifierFromWindowsLocaleCode:(uint32_t)lcid;
+ (uint32_t)windowsLocaleCodeFromLocaleIdentifier:(NSString *)localeIdentifier;
+ (NSLocaleLanguageDirection)characterDirectionForLanguage:(NSString *)isoLangCode;
+ (NSLocaleLanguageDirection)lineDirectionForLanguage:(NSString *)isoLangCode;

@end
