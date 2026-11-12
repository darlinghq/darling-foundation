/*
 This file is part of Darling.

 Copyright (C) 2026 Lubos Dolezel

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

// The predefined dimensions and their units. Each unit is defined by its symbol and by how many
// base units it is (and, for the temperature scales and the like, the offset of its zero). The
// values are from the SI definitions and NIST Special Publication 811 (Guide for the Use of the
// International System of Units, appendix B, conversion factors), the IEC 80000-13 prefixes for
// information, and the notes at each dimension.

#import <Foundation/NSUnit.h>
#import <dispatch/dispatch.h>
#import <math.h>
#import <objc/runtime.h>
#import "NSUnitInternal.h"

// A predefined unit is created once and shared.
#define UNIT_WITH_CONVERTER(Class, name, symbol, converterExpression) \
+ (Class *)name \
{ \
    static Class *unit; \
    static dispatch_once_t once; \
    dispatch_once(&once, ^{ \
        NSUnitConverter *converter = converterExpression; \
        unit = [[Class alloc] initWithSymbol:symbol converter:converter]; \
        [converter release]; \
    }); \
    return unit; \
}

#define UNIT_LINEAR(Class, name, symbol, coefficient) \
    UNIT_WITH_CONVERTER(Class, name, symbol, [[NSUnitConverterLinear alloc] initWithCoefficient:(coefficient)])

#define UNIT_AFFINE(Class, name, symbol, coefficient, offsetValue) \
    UNIT_WITH_CONVERTER(Class, name, symbol, [[NSUnitConverterLinear alloc] initWithCoefficient:(coefficient) constant:(offsetValue)])

#define UNIT_RECIPROCAL(Class, name, symbol, coefficient) \
    UNIT_WITH_CONVERTER(Class, name, symbol, [[NSUnitConverterReciprocal alloc] initWithCoefficient:(coefficient)])

#pragma mark - NSUnitAcceleration

// Values: Standard gravity is 9.80665 m/s^2 exactly (CGPM, 1901).
@implementation NSUnitAcceleration

UNIT_LINEAR(NSUnitAcceleration, metersPerSecondSquared, @"m/s\u00b2", 1.0)
UNIT_LINEAR(NSUnitAcceleration, gravity, @"g", 9.80665)

+ (instancetype)baseUnit { return [NSUnitAcceleration metersPerSecondSquared]; }

@end

#pragma mark - NSUnitAngle

// Values: A right angle is 100 gradians; a revolution is 360 degrees.
@implementation NSUnitAngle

UNIT_LINEAR(NSUnitAngle, degrees, @"\u00b0", 1.0)
// QUIRK: the arc minute and arc second symbols are the modifier letters prime U+02B9 and
// double prime U+02BA, not ASCII quote characters. Not documented. Evidence: black-box
// observation on macOS 26.7.3 (tier 2), MC26.15, probe vd-upstream/mac-probes/v409-nsunit.m.
// Test: test_quirk_unit_symbols in tests/nsunit-nsmeasurement.m
UNIT_LINEAR(NSUnitAngle, arcMinutes, @"\u02b9", 1.0 / 60.0)
UNIT_LINEAR(NSUnitAngle, arcSeconds, @"\u02ba", 1.0 / 3600.0)
UNIT_LINEAR(NSUnitAngle, radians, @"rad", 180.0 / M_PI)
UNIT_LINEAR(NSUnitAngle, gradians, @"grad", 0.9)
UNIT_LINEAR(NSUnitAngle, revolutions, @"rev", 360.0)

+ (instancetype)baseUnit { return [NSUnitAngle degrees]; }

@end

#pragma mark - NSUnitArea

// Values: The inch, foot, yard and mile are the international ones (exactly 0.0254 m, 0.3048 m, 0.9144
// m and 1609.344 m); an acre is 4046.8564224 m^2 (NIST SP 811, appendix B); an are is 100 m^2, a
// hectare 10^4 m^2.
@implementation NSUnitArea

UNIT_LINEAR(NSUnitArea, squareMegameters, @"Mm\u00b2", 1.0e12)
UNIT_LINEAR(NSUnitArea, squareKilometers, @"km\u00b2", 1.0e6)
UNIT_LINEAR(NSUnitArea, squareMeters, @"m\u00b2", 1.0)
UNIT_LINEAR(NSUnitArea, squareCentimeters, @"cm\u00b2", 1.0e-4)
UNIT_LINEAR(NSUnitArea, squareMillimeters, @"mm\u00b2", 1.0e-6)
UNIT_LINEAR(NSUnitArea, squareMicrometers, @"\u00b5m\u00b2", 1.0e-12)
UNIT_LINEAR(NSUnitArea, squareNanometers, @"nm\u00b2", 1.0e-18)
UNIT_LINEAR(NSUnitArea, squareInches, @"in\u00b2", 0.0254 * 0.0254)
UNIT_LINEAR(NSUnitArea, squareFeet, @"ft\u00b2", 0.3048 * 0.3048)
UNIT_LINEAR(NSUnitArea, squareYards, @"yd\u00b2", 0.9144 * 0.9144)
UNIT_LINEAR(NSUnitArea, squareMiles, @"mi\u00b2", 1609.344 * 1609.344)
UNIT_LINEAR(NSUnitArea, acres, @"ac", 4046.8564224)
UNIT_LINEAR(NSUnitArea, ares, @"a", 100.0)
UNIT_LINEAR(NSUnitArea, hectares, @"ha", 10000.0)

+ (instancetype)baseUnit { return [NSUnitArea squareMeters]; }

@end

#pragma mark - NSUnitConcentrationMass

// Values: A milligram per decilitre is 10^-3 g / 10^-1 L = 0.01 g/L.
@implementation NSUnitConcentrationMass

UNIT_LINEAR(NSUnitConcentrationMass, gramsPerLiter, @"g/L", 1.0)
UNIT_LINEAR(NSUnitConcentrationMass, milligramsPerDeciliter, @"mg/dL", 0.01)
// A millimole per litre of a substance of the given molar mass is gramsPerMole / 1000 g/L.
+ (NSUnitConcentrationMass *)millimolesPerLiterWithGramsPerMole:(double)gramsPerMole
{
    NSUnitConverterLinear *converter = [[NSUnitConverterLinear alloc] initWithCoefficient:gramsPerMole / 1000.0];
    NSUnitConcentrationMass *unit = [[[self alloc] initWithSymbol:@"mmol/L" converter:converter] autorelease];
    [converter release];
    return unit;
}

+ (instancetype)baseUnit { return [NSUnitConcentrationMass gramsPerLiter]; }

@end

#pragma mark - NSUnitDispersion

@implementation NSUnitDispersion

UNIT_LINEAR(NSUnitDispersion, partsPerMillion, @"ppm", 1.0)

+ (instancetype)baseUnit { return [NSUnitDispersion partsPerMillion]; }

@end

#pragma mark - NSUnitDuration

@implementation NSUnitDuration

UNIT_LINEAR(NSUnitDuration, picoseconds, @"ps", 1.0e-12)
UNIT_LINEAR(NSUnitDuration, nanoseconds, @"ns", 1.0e-9)
UNIT_LINEAR(NSUnitDuration, microseconds, @"\u00b5s", 1.0e-6)
UNIT_LINEAR(NSUnitDuration, milliseconds, @"ms", 1.0e-3)
UNIT_LINEAR(NSUnitDuration, seconds, @"s", 1.0)
UNIT_LINEAR(NSUnitDuration, minutes, @"min", 60.0)
UNIT_LINEAR(NSUnitDuration, hours, @"hr", 3600.0)

+ (instancetype)baseUnit { return [NSUnitDuration seconds]; }

@end

#pragma mark - NSUnitElectricCharge

// Values: An ampere hour is 3600 coulombs.
@implementation NSUnitElectricCharge

UNIT_LINEAR(NSUnitElectricCharge, coulombs, @"C", 1.0)
UNIT_LINEAR(NSUnitElectricCharge, megaampereHours, @"MAh", 3.6e9)
UNIT_LINEAR(NSUnitElectricCharge, kiloampereHours, @"kAh", 3.6e6)
UNIT_LINEAR(NSUnitElectricCharge, ampereHours, @"Ah", 3600.0)
UNIT_LINEAR(NSUnitElectricCharge, milliampereHours, @"mAh", 3.6)
UNIT_LINEAR(NSUnitElectricCharge, microampereHours, @"\u00b5Ah", 3.6e-3)

+ (instancetype)baseUnit { return [NSUnitElectricCharge coulombs]; }

@end

#pragma mark - NSUnitElectricCurrent

@implementation NSUnitElectricCurrent

UNIT_LINEAR(NSUnitElectricCurrent, megaamperes, @"MA", 1.0e6)
UNIT_LINEAR(NSUnitElectricCurrent, kiloamperes, @"kA", 1.0e3)
UNIT_LINEAR(NSUnitElectricCurrent, amperes, @"A", 1.0)
UNIT_LINEAR(NSUnitElectricCurrent, milliamperes, @"mA", 1.0e-3)
UNIT_LINEAR(NSUnitElectricCurrent, microamperes, @"\u00b5A", 1.0e-6)

+ (instancetype)baseUnit { return [NSUnitElectricCurrent amperes]; }

@end

#pragma mark - NSUnitElectricPotentialDifference

@implementation NSUnitElectricPotentialDifference

UNIT_LINEAR(NSUnitElectricPotentialDifference, megavolts, @"MV", 1.0e6)
UNIT_LINEAR(NSUnitElectricPotentialDifference, kilovolts, @"kV", 1.0e3)
UNIT_LINEAR(NSUnitElectricPotentialDifference, volts, @"V", 1.0)
UNIT_LINEAR(NSUnitElectricPotentialDifference, millivolts, @"mV", 1.0e-3)
UNIT_LINEAR(NSUnitElectricPotentialDifference, microvolts, @"\u00b5V", 1.0e-6)

+ (instancetype)baseUnit { return [NSUnitElectricPotentialDifference volts]; }

@end

#pragma mark - NSUnitElectricResistance

@implementation NSUnitElectricResistance

// QUIRK: the ohm sign is U+2126 (OHM SIGN), not the Greek capital omega U+03A9, in every
// ohm unit. Not documented. Evidence as for the arc symbols (MC26.15).
// Test: test_quirk_unit_symbols in tests/nsunit-nsmeasurement.m
UNIT_LINEAR(NSUnitElectricResistance, megaohms, @"M\u2126", 1.0e6)
UNIT_LINEAR(NSUnitElectricResistance, kiloohms, @"k\u2126", 1.0e3)
UNIT_LINEAR(NSUnitElectricResistance, ohms, @"\u2126", 1.0)
UNIT_LINEAR(NSUnitElectricResistance, milliohms, @"m\u2126", 1.0e-3)
UNIT_LINEAR(NSUnitElectricResistance, microohms, @"\u00b5\u2126", 1.0e-6)

+ (instancetype)baseUnit { return [NSUnitElectricResistance ohms]; }

@end

#pragma mark - NSUnitEnergy

// Values: The calorie is the thermochemical one, 4.184 J exactly (NIST SP 811, appendix B); a kilowatt
// hour is 3.6e6 J.
@implementation NSUnitEnergy

UNIT_LINEAR(NSUnitEnergy, kilojoules, @"kJ", 1.0e3)
UNIT_LINEAR(NSUnitEnergy, joules, @"J", 1.0)
UNIT_LINEAR(NSUnitEnergy, kilocalories, @"kCal", 4184.0)
UNIT_LINEAR(NSUnitEnergy, calories, @"cal", 4.184)
UNIT_LINEAR(NSUnitEnergy, kilowattHours, @"kWh", 3.6e6)

+ (instancetype)baseUnit { return [NSUnitEnergy joules]; }

@end

#pragma mark - NSUnitFrequency

@implementation NSUnitFrequency

UNIT_LINEAR(NSUnitFrequency, terahertz, @"THz", 1.0e12)
UNIT_LINEAR(NSUnitFrequency, gigahertz, @"GHz", 1.0e9)
UNIT_LINEAR(NSUnitFrequency, megahertz, @"MHz", 1.0e6)
UNIT_LINEAR(NSUnitFrequency, kilohertz, @"kHz", 1.0e3)
UNIT_LINEAR(NSUnitFrequency, hertz, @"Hz", 1.0)
UNIT_LINEAR(NSUnitFrequency, millihertz, @"mHz", 1.0e-3)
UNIT_LINEAR(NSUnitFrequency, microhertz, @"\u00b5Hz", 1.0e-6)
UNIT_LINEAR(NSUnitFrequency, nanohertz, @"nHz", 1.0e-9)
UNIT_LINEAR(NSUnitFrequency, framesPerSecond, @"fps", 1.0)

+ (instancetype)baseUnit { return [NSUnitFrequency hertz]; }

@end

#pragma mark - NSUnitFuelEfficiency

// Values: Fuel economy in distance per volume is the reciprocal of consumption in volume per distance.
// The base unit is litres per 100 km, so the coefficient is 100 L of the gallon in use (4.54609 L
// imperial, 3.785411784 L US) over the mile in km.
@implementation NSUnitFuelEfficiency

UNIT_LINEAR(NSUnitFuelEfficiency, litersPer100Kilometers, @"L/100km", 1.0)
UNIT_RECIPROCAL(NSUnitFuelEfficiency, milesPerImperialGallon, @"mpg", 100.0 * 4.54609 / 1.609344)
UNIT_RECIPROCAL(NSUnitFuelEfficiency, milesPerGallon, @"mpg", 100.0 * 3.785411784 / 1.609344)

+ (instancetype)baseUnit { return [NSUnitFuelEfficiency litersPer100Kilometers]; }

@end

#pragma mark - NSUnitIlluminance

@implementation NSUnitIlluminance

UNIT_LINEAR(NSUnitIlluminance, lux, @"lx", 1.0)

+ (instancetype)baseUnit { return [NSUnitIlluminance lux]; }

@end

#pragma mark - NSUnitInformationStorage

// Values: Decimal prefixes are powers of 1000 and binary prefixes (IEC 80000-13) powers of 1024; a
// byte is 8 bits and a nibble 4 bits.
@implementation NSUnitInformationStorage

// QUIRK: the byte symbol is "B" (so is the symbol of the base unit). Not documented.
// Evidence as for the arc symbols (MC26.15). Test: test_quirk_unit_symbols.
UNIT_LINEAR(NSUnitInformationStorage, bits, @"bit", 0.125)
UNIT_LINEAR(NSUnitInformationStorage, bytes, @"B", 1.0)
UNIT_LINEAR(NSUnitInformationStorage, nibbles, @"nibble", 0.5)
UNIT_LINEAR(NSUnitInformationStorage, yottabytes, @"YB", 1.0e24)
UNIT_LINEAR(NSUnitInformationStorage, zettabytes, @"ZB", 1.0e21)
UNIT_LINEAR(NSUnitInformationStorage, exabytes, @"EB", 1.0e18)
UNIT_LINEAR(NSUnitInformationStorage, petabytes, @"PB", 1.0e15)
UNIT_LINEAR(NSUnitInformationStorage, terabytes, @"TB", 1.0e12)
UNIT_LINEAR(NSUnitInformationStorage, gigabytes, @"GB", 1.0e9)
UNIT_LINEAR(NSUnitInformationStorage, megabytes, @"MB", 1.0e6)
UNIT_LINEAR(NSUnitInformationStorage, kilobytes, @"kB", 1.0e3)
UNIT_LINEAR(NSUnitInformationStorage, yottabits, @"Yb", 1.0e24 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, zettabits, @"Zb", 1.0e21 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, exabits, @"Eb", 1.0e18 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, petabits, @"Pb", 1.0e15 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, terabits, @"Tb", 1.0e12 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, gigabits, @"Gb", 1.0e9 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, megabits, @"Mb", 1.0e6 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, kilobits, @"kb", 1.0e3 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, yobibytes, @"YiB", 0x1p80)
UNIT_LINEAR(NSUnitInformationStorage, zebibytes, @"ZiB", 0x1p70)
UNIT_LINEAR(NSUnitInformationStorage, exbibytes, @"EiB", 0x1p60)
UNIT_LINEAR(NSUnitInformationStorage, pebibytes, @"PiB", 0x1p50)
UNIT_LINEAR(NSUnitInformationStorage, tebibytes, @"TiB", 0x1p40)
UNIT_LINEAR(NSUnitInformationStorage, gibibytes, @"GiB", 0x1p30)
UNIT_LINEAR(NSUnitInformationStorage, mebibytes, @"MiB", 0x1p20)
UNIT_LINEAR(NSUnitInformationStorage, kibibytes, @"KiB", 0x1p10)
UNIT_LINEAR(NSUnitInformationStorage, yobibits, @"Yib", 0x1p80 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, zebibits, @"Zib", 0x1p70 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, exbibits, @"Eib", 0x1p60 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, pebibits, @"Pib", 0x1p50 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, tebibits, @"Tib", 0x1p40 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, gibibits, @"Gib", 0x1p30 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, mebibits, @"Mib", 0x1p20 / 8.0)
UNIT_LINEAR(NSUnitInformationStorage, kibibits, @"Kib", 0x1p10 / 8.0)

+ (instancetype)baseUnit { return [NSUnitInformationStorage bytes]; }

@end

#pragma mark - NSUnitLength

// Values: International inch/foot/yard/mile; a fathom is 6 ft and a furlong 660 ft; the nautical mile
// is 1852 m (SI brochure); the astronomical unit is 149597870700 m (IAU 2012 resolution B2); the
// light-year is the distance light travels in a Julian year, 365.25 d * 86400 s * 299792458 m/s =
// 9460730472580800 m; the parsec is 648000/pi astronomical units; the Scandinavian mile is 10 km.
@implementation NSUnitLength

UNIT_LINEAR(NSUnitLength, megameters, @"Mm", 1.0e6)
UNIT_LINEAR(NSUnitLength, kilometers, @"km", 1.0e3)
UNIT_LINEAR(NSUnitLength, hectometers, @"hm", 100.0)
UNIT_LINEAR(NSUnitLength, decameters, @"dam", 10.0)
UNIT_LINEAR(NSUnitLength, meters, @"m", 1.0)
UNIT_LINEAR(NSUnitLength, decimeters, @"dm", 0.1)
UNIT_LINEAR(NSUnitLength, centimeters, @"cm", 0.01)
UNIT_LINEAR(NSUnitLength, millimeters, @"mm", 0.001)
UNIT_LINEAR(NSUnitLength, micrometers, @"\u00b5m", 1.0e-6)
UNIT_LINEAR(NSUnitLength, nanometers, @"nm", 1.0e-9)
UNIT_LINEAR(NSUnitLength, picometers, @"pm", 1.0e-12)
UNIT_LINEAR(NSUnitLength, inches, @"in", 0.0254)
UNIT_LINEAR(NSUnitLength, feet, @"ft", 0.3048)
UNIT_LINEAR(NSUnitLength, yards, @"yd", 0.9144)
UNIT_LINEAR(NSUnitLength, miles, @"mi", 1609.344)
UNIT_LINEAR(NSUnitLength, scandinavianMiles, @"smi", 10000.0)
UNIT_LINEAR(NSUnitLength, lightyears, @"ly", 9460730472580800.0)
UNIT_LINEAR(NSUnitLength, nauticalMiles, @"NM", 1852.0)
UNIT_LINEAR(NSUnitLength, fathoms, @"ftm", 6.0 * 0.3048)
UNIT_LINEAR(NSUnitLength, furlongs, @"fur", 660.0 * 0.3048)
UNIT_LINEAR(NSUnitLength, astronomicalUnits, @"ua", 149597870700.0)
UNIT_LINEAR(NSUnitLength, parsecs, @"pc", 648000.0 / M_PI * 149597870700.0)

+ (instancetype)baseUnit { return [NSUnitLength meters]; }

@end

#pragma mark - NSUnitMass

// Values: The avoirdupois pound is 0.45359237 kg exactly; ounce, stone and short ton are 1/16, 14 and
// 2000 of it; the metric carat is 200 mg; the troy ounce is 31.1034768 g; a slug is 1 lbf s^2/ft =
// 0.45359237 kg * 9.80665 m/s^2 / 0.3048 m.
@implementation NSUnitMass

UNIT_LINEAR(NSUnitMass, kilograms, @"kg", 1.0)
UNIT_LINEAR(NSUnitMass, grams, @"g", 1.0e-3)
UNIT_LINEAR(NSUnitMass, decigrams, @"dg", 1.0e-4)
UNIT_LINEAR(NSUnitMass, centigrams, @"cg", 1.0e-5)
UNIT_LINEAR(NSUnitMass, milligrams, @"mg", 1.0e-6)
UNIT_LINEAR(NSUnitMass, micrograms, @"\u00b5g", 1.0e-9)
UNIT_LINEAR(NSUnitMass, nanograms, @"ng", 1.0e-12)
UNIT_LINEAR(NSUnitMass, picograms, @"pg", 1.0e-15)
UNIT_LINEAR(NSUnitMass, ounces, @"oz", 0.45359237 / 16.0)
UNIT_LINEAR(NSUnitMass, poundsMass, @"lb", 0.45359237)
UNIT_LINEAR(NSUnitMass, stones, @"st", 14.0 * 0.45359237)
UNIT_LINEAR(NSUnitMass, metricTons, @"t", 1000.0)
UNIT_LINEAR(NSUnitMass, shortTons, @"ton", 2000.0 * 0.45359237)
UNIT_LINEAR(NSUnitMass, carats, @"ct", 2.0e-4)
UNIT_LINEAR(NSUnitMass, ouncesTroy, @"oz t", 0.0311034768)
UNIT_LINEAR(NSUnitMass, slugs, @"slug", 0.45359237 * 9.80665 / 0.3048)

+ (instancetype)baseUnit { return [NSUnitMass kilograms]; }

@end

#pragma mark - NSUnitPower

// Values: Mechanical horsepower is 550 ft lbf/s, 745.6998715822702 W (NIST SP 811, appendix B).
@implementation NSUnitPower

UNIT_LINEAR(NSUnitPower, terawatts, @"TW", 1.0e12)
UNIT_LINEAR(NSUnitPower, gigawatts, @"GW", 1.0e9)
UNIT_LINEAR(NSUnitPower, megawatts, @"MW", 1.0e6)
UNIT_LINEAR(NSUnitPower, kilowatts, @"kW", 1.0e3)
UNIT_LINEAR(NSUnitPower, watts, @"W", 1.0)
UNIT_LINEAR(NSUnitPower, milliwatts, @"mW", 1.0e-3)
UNIT_LINEAR(NSUnitPower, microwatts, @"\u00b5W", 1.0e-6)
UNIT_LINEAR(NSUnitPower, nanowatts, @"nW", 1.0e-9)
UNIT_LINEAR(NSUnitPower, picowatts, @"pW", 1.0e-12)
UNIT_LINEAR(NSUnitPower, femtowatts, @"fW", 1.0e-15)
UNIT_LINEAR(NSUnitPower, horsepower, @"hp", 550.0 * 0.3048 * 0.45359237 * 9.80665)

+ (instancetype)baseUnit { return [NSUnitPower watts]; }

@end

#pragma mark - NSUnitPressure

// Values: Inch of mercury at 0 degC is 3386.389 Pa and the conventional millimetre of mercury
// 133.322387415 Pa (NIST SP 811, appendix B); psi is 1 lbf/in^2 with the pound-force 0.45359237 kg *
// 9.80665 m/s^2.
@implementation NSUnitPressure

UNIT_LINEAR(NSUnitPressure, newtonsPerMetersSquared, @"N/m\u00b2", 1.0)
UNIT_LINEAR(NSUnitPressure, gigapascals, @"GPa", 1.0e9)
UNIT_LINEAR(NSUnitPressure, megapascals, @"MPa", 1.0e6)
UNIT_LINEAR(NSUnitPressure, kilopascals, @"kPa", 1.0e3)
UNIT_LINEAR(NSUnitPressure, hectopascals, @"hPa", 100.0)
UNIT_LINEAR(NSUnitPressure, inchesOfMercury, @"inHg", 3386.389)
UNIT_LINEAR(NSUnitPressure, bars, @"bar", 1.0e5)
UNIT_LINEAR(NSUnitPressure, millibars, @"mbar", 100.0)
UNIT_LINEAR(NSUnitPressure, millimetersOfMercury, @"mmHg", 133.322387415)
UNIT_LINEAR(NSUnitPressure, poundsForcePerSquareInch, @"psi", 0.45359237 * 9.80665 / (0.0254 * 0.0254))

+ (instancetype)baseUnit { return [NSUnitPressure newtonsPerMetersSquared]; }

@end

#pragma mark - NSUnitSpeed

// Values: A knot is one nautical mile per hour.
@implementation NSUnitSpeed

UNIT_LINEAR(NSUnitSpeed, metersPerSecond, @"m/s", 1.0)
UNIT_LINEAR(NSUnitSpeed, kilometersPerHour, @"km/h", 1000.0 / 3600.0)
UNIT_LINEAR(NSUnitSpeed, milesPerHour, @"mph", 1609.344 / 3600.0)
UNIT_LINEAR(NSUnitSpeed, knots, @"kn", 1852.0 / 3600.0)

+ (instancetype)baseUnit { return [NSUnitSpeed metersPerSecond]; }

@end

#pragma mark - NSUnitTemperature

// Values: 0 degC is 273.15 K; a Fahrenheit degree is 5/9 K and 0 degF is 459.67 R = 459.67 * 5/9 K.
@implementation NSUnitTemperature

UNIT_LINEAR(NSUnitTemperature, kelvin, @"K", 1.0)
UNIT_AFFINE(NSUnitTemperature, celsius, @"\u00b0C", 1.0, 273.15)
UNIT_AFFINE(NSUnitTemperature, fahrenheit, @"\u00b0F", 5.0 / 9.0, 459.67 * 5.0 / 9.0)

+ (instancetype)baseUnit { return [NSUnitTemperature kelvin]; }

@end

#pragma mark - NSUnitVolume

// Values: The litre is 1 dm^3. The US gallon is 231 in^3 = 3.785411784 L; teaspoon, tablespoon, fluid
// ounce, cup, pint and quart are 1/768, 1/256, 1/128, 1/16, 1/8 and 1/4 of it. The imperial gallon is
// 4.54609 L (UK Weights and Measures Act 1985), the imperial fluid ounce 1/160 of it, the tablespoon
// 5/8 of that ounce and the teaspoon a third of a tablespoon. The US dry bushel is 2150.42 in^3, an
// acre foot 43560 ft^3 (NIST SP 811, appendix B). A metric cup is 250 mL.
@implementation NSUnitVolume

UNIT_LINEAR(NSUnitVolume, megaliters, @"ML", 1.0e6)
UNIT_LINEAR(NSUnitVolume, kiloliters, @"kL", 1.0e3)
UNIT_LINEAR(NSUnitVolume, liters, @"L", 1.0)
UNIT_LINEAR(NSUnitVolume, deciliters, @"dL", 0.1)
UNIT_LINEAR(NSUnitVolume, centiliters, @"cL", 0.01)
UNIT_LINEAR(NSUnitVolume, milliliters, @"mL", 0.001)
UNIT_LINEAR(NSUnitVolume, cubicKilometers, @"km\u00b3", 1.0e12)
UNIT_LINEAR(NSUnitVolume, cubicMeters, @"m\u00b3", 1000.0)
UNIT_LINEAR(NSUnitVolume, cubicDecimeters, @"dm\u00b3", 1.0)
UNIT_LINEAR(NSUnitVolume, cubicCentimeters, @"cm\u00b3", 0.001)
UNIT_LINEAR(NSUnitVolume, cubicMillimeters, @"mm\u00b3", 1.0e-6)
UNIT_LINEAR(NSUnitVolume, cubicInches, @"in\u00b3", 1000.0 * 0.0254 * 0.0254 * 0.0254)
UNIT_LINEAR(NSUnitVolume, cubicFeet, @"ft\u00b3", 1000.0 * 0.3048 * 0.3048 * 0.3048)
UNIT_LINEAR(NSUnitVolume, cubicYards, @"yd\u00b3", 1000.0 * 0.9144 * 0.9144 * 0.9144)
UNIT_LINEAR(NSUnitVolume, cubicMiles, @"mi\u00b3", 1000.0 * 1609.344 * 1609.344 * 1609.344)
UNIT_LINEAR(NSUnitVolume, acreFeet, @"acre ft", 43560.0 * 1000.0 * 0.3048 * 0.3048 * 0.3048)
UNIT_LINEAR(NSUnitVolume, bushels, @"bsh", 2150.42 * 1000.0 * 0.0254 * 0.0254 * 0.0254)
UNIT_LINEAR(NSUnitVolume, teaspoons, @"tsp", 3.785411784 / 768.0)
UNIT_LINEAR(NSUnitVolume, tablespoons, @"tbsp", 3.785411784 / 256.0)
UNIT_LINEAR(NSUnitVolume, fluidOunces, @"fl oz", 3.785411784 / 128.0)
UNIT_LINEAR(NSUnitVolume, cups, @"cup", 3.785411784 / 16.0)
UNIT_LINEAR(NSUnitVolume, pints, @"pt", 3.785411784 / 8.0)
UNIT_LINEAR(NSUnitVolume, quarts, @"qt", 3.785411784 / 4.0)
UNIT_LINEAR(NSUnitVolume, gallons, @"gal", 3.785411784)
UNIT_LINEAR(NSUnitVolume, imperialTeaspoons, @"tsp", 4.54609 / 160.0 * 0.625 / 3.0)
UNIT_LINEAR(NSUnitVolume, imperialTablespoons, @"tbsp", 4.54609 / 160.0 * 0.625)
UNIT_LINEAR(NSUnitVolume, imperialFluidOunces, @"fl oz", 4.54609 / 160.0)
UNIT_LINEAR(NSUnitVolume, imperialPints, @"pt", 4.54609 / 8.0)
UNIT_LINEAR(NSUnitVolume, imperialQuarts, @"qt", 4.54609 / 4.0)
UNIT_LINEAR(NSUnitVolume, imperialGallons, @"gal", 4.54609)
UNIT_LINEAR(NSUnitVolume, metricCups, @"metric cup", 0.25)

+ (instancetype)baseUnit { return [NSUnitVolume liters]; }

@end

#pragma mark - Archive identifiers

// The ids with which an archive names the predefined units. The others are archived as -1 and
// are identified by their symbol and converter. The imperial teaspoon, tablespoon, pint and
// quart carry the ids of their US namesakes.
// QUIRK: the ids are part of the archive layout. Not documented. Evidence: black-box
// observation on macOS 26.7.3 (tier 2), MC26.13 and MC26.15 (probe v409-nsunit.m); only the ids
// listed in MC26.15 are known, the remaining predefined units archive -1 until they are observed.
// Test: test_quirk_archive_specifiers in tests/nsunit-nsmeasurement.m
NSInteger _NSDimensionArchiveSpecifier(NSDimension *unit)
{
    static const struct { const char *dimension; const char *selector; NSInteger specifier; } known[] = {
        { "NSUnitAcceleration", "metersPerSecondSquared", 1 }, { "NSUnitAcceleration", "gravity", 0 },
        { "NSUnitAngle", "degrees", 256 }, { "NSUnitAngle", "arcMinutes", 257 }, { "NSUnitAngle", "arcSeconds", 258 },
        { "NSUnitAngle", "radians", 259 }, { "NSUnitAngle", "revolutions", 260 },
        { "NSUnitArea", "squareMeters", 512 }, { "NSUnitArea", "squareKilometers", 513 }, { "NSUnitArea", "squareFeet", 514 },
        { "NSUnitArea", "squareMiles", 515 }, { "NSUnitArea", "acres", 516 }, { "NSUnitArea", "hectares", 517 },
        { "NSUnitArea", "squareCentimeters", 518 }, { "NSUnitArea", "squareInches", 519 }, { "NSUnitArea", "squareYards", 520 },
        { "NSUnitLength", "meters", 1280 }, { "NSUnitLength", "kilometers", 1282 },
        { "NSUnitMass", "grams", 1536 },
        { "NSUnitDuration", "hours", 1028 }, { "NSUnitDuration", "minutes", 1029 }, { "NSUnitDuration", "seconds", 1030 },
        { "NSUnitDuration", "milliseconds", 1031 }, { "NSUnitDuration", "microseconds", 1032 }, { "NSUnitDuration", "nanoseconds", 1033 },
        { "NSUnitSpeed", "metersPerSecond", 2304 },
        { "NSUnitTemperature", "fahrenheit", 2561 },
        { "NSUnitVolume", "milliliters", 2819 }, { "NSUnitVolume", "megaliters", 2823 },
        { "NSUnitVolume", "teaspoons", 2831 }, { "NSUnitVolume", "imperialTeaspoons", 2831 },
        { "NSUnitVolume", "tablespoons", 2832 }, { "NSUnitVolume", "imperialTablespoons", 2832 },
        { "NSUnitVolume", "imperialFluidOunces", 2833 },
        { "NSUnitVolume", "pints", 2835 }, { "NSUnitVolume", "imperialPints", 2835 },
        { "NSUnitVolume", "quarts", 2836 }, { "NSUnitVolume", "imperialQuarts", 2836 },
        { "NSUnitVolume", "gallons", 2837 }, { "NSUnitVolume", "metricCups", 2838 }, { "NSUnitVolume", "imperialGallons", 2840 },
        { "NSUnitFuelEfficiency", "milesPerGallon", 3329 }, { "NSUnitFuelEfficiency", "litersPer100Kilometers", 3330 },
        { "NSUnitFuelEfficiency", "milesPerImperialGallon", 3331 },
        { "NSUnitInformationStorage", "bits", 3584 }, { "NSUnitInformationStorage", "bytes", 3585 },
        { "NSUnitElectricResistance", "ohms", 3842 },
        { "NSUnitIlluminance", "lux", 4352 },
        { "NSUnitConcentrationMass", "milligramsPerDeciliter", 4609 },
        { "NSUnitDispersion", "partsPerMillion", 4611 },
    };

    for (size_t i = 0; i < sizeof(known) / sizeof(known[0]); i++)
    {
        Class dimension = objc_getClass(known[i].dimension);
        SEL selector = sel_registerName(known[i].selector);
        if ([unit class] == dimension && [dimension respondsToSelector:selector] && [unit isEqual:[dimension performSelector:selector]])
            return known[i].specifier;
    }
    return -1;
}
