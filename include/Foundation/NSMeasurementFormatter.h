#import <Foundation/NSFormatter.h>

@class NSLocale, NSNumberFormatter;

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, NSMeasurementFormatterUnitOptions) {
    NSMeasurementFormatterUnitOptionsProvidedUnit = (1UL << 0),
    NSMeasurementFormatterUnitOptionsNaturalScale = (1UL << 1),
    NSMeasurementFormatterUnitOptionsTemperatureWithoutUnit = (1UL << 2),
};

// Formatting (stringFromMeasurement:, stringFromUnit:) is not implemented: it needs the localised
// unit names and the locale's preferred unit scale, which Foundation does not have yet. NSMeasurement
// and NSUnit exist.
@interface NSMeasurementFormatter : NSFormatter
{
    NSMeasurementFormatterUnitOptions _unitOptions;
    NSFormattingUnitStyle _unitStyle;
    NSLocale *_locale;
    NSNumberFormatter *_numberFormatter;
}

@property NSMeasurementFormatterUnitOptions unitOptions;
@property NSFormattingUnitStyle unitStyle;
@property (null_resettable, copy) NSLocale *locale;
@property (null_resettable, copy) NSNumberFormatter *numberFormatter;

@end

NS_ASSUME_NONNULL_END
