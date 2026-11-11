/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSLengthFormatter, NSMassFormatter and NSEnergyFormatter produce unit
 * strings for the short, medium and long styles and convert from the base
 * unit; the unit style round-trips; NSCopying keeps the configuration.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)
#define CHECK_STR(got, want) do { NSString *g_ = (got); if (![g_ isEqualToString:(want)]) { printf("FAIL line %d: got \"%s\", want \"%s\"\n", __LINE__, g_ ? [g_ UTF8String] : "(nil)", [(want) UTF8String]); failures++; } } while (0)

int main(void)
{
	@autoreleasepool {
		NSLocale *us = [NSLocale localeWithLocaleIdentifier:@"en_US"];

		NSLengthFormatter *len = [[NSLengthFormatter alloc] init];
		len.numberFormatter.locale = us;
		len.unitStyle = NSFormattingUnitStyleMedium;
		CHECK_STR([len unitStringFromValue:2 unit:NSLengthFormatterUnitKilometer], @"km");
		len.unitStyle = NSFormattingUnitStyleLong;
		CHECK_STR([len unitStringFromValue:2 unit:NSLengthFormatterUnitMeter], @"meters");
		CHECK_STR([len unitStringFromValue:1 unit:NSLengthFormatterUnitMeter], @"meter");
		len.unitStyle = NSFormattingUnitStyleShort;
		CHECK_STR([len stringFromValue:5 unit:NSLengthFormatterUnitCentimeter], @"5cm");
		CHECK(len.unitStyle == NSFormattingUnitStyleShort);

		NSLengthFormatter *lenCopy = [len copy];
		CHECK(lenCopy.unitStyle == NSFormattingUnitStyleShort);

		NSMassFormatter *mass = [[NSMassFormatter alloc] init];
		mass.numberFormatter.locale = us;
		mass.unitStyle = NSFormattingUnitStyleMedium;
		CHECK_STR([mass unitStringFromValue:3 unit:NSMassFormatterUnitKilogram], @"kg");
		mass.unitStyle = NSFormattingUnitStyleLong;
		CHECK_STR([mass unitStringFromValue:2 unit:NSMassFormatterUnitPound], @"pounds");

		NSEnergyFormatter *en = [[NSEnergyFormatter alloc] init];
		en.numberFormatter.locale = us;
		en.unitStyle = NSFormattingUnitStyleMedium;
		CHECK_STR([en unitStringFromValue:1 unit:NSEnergyFormatterUnitKilojoule], @"kJ");
		CHECK(!en.forFoodEnergyUse);
		en.forFoodEnergyUse = YES;
		CHECK(en.forFoodEnergyUse);

		/* The base-unit entry point switches to kilometres above 1000 m (1000 m stays in metres, as on macOS). */
		len.numberFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"fr_FR"];
		len.unitStyle = NSFormattingUnitStyleMedium;
		NSString *km = [len stringFromMeters:1500];
		CHECK([km containsString:@"1,5"] && [km containsString:@"km"]);
		NSString *m = [len stringFromMeters:999];
		CHECK([m containsString:@"999"] && ![m containsString:@"km"]);
	}
	if (failures == 0)
		printf("PASS: unit formatters\n");
	return failures != 0;
}
