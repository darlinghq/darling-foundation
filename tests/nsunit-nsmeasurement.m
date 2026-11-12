/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSUnit, NSDimension, the unit converters, the predefined dimensions and NSMeasurement.
 * The expected numbers are from the SI definitions and NIST Special Publication 811, appendix B.
 * Run it with the argument "strict" to compare against exact definitions; without it the
 * quantities that vendors round (horsepower, inch of mercury) are compared to 1e-4.
 */
#import <Foundation/Foundation.h>
#import <Foundation/NSUnit.h>
#import <Foundation/NSMeasurement.h>
#import <objc/runtime.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

static int failures;

static void expectTrue(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        failures++;
    }
}

#define CHECK(c) expectTrue((c), @#c)
#define CHECK_CLOSE(a, b, tol) do { double _a = (a), _b = (b); \
    expectTrue(fabs(_a - _b) <= (tol) * fmax(fabs(_b), 1e-300), [NSString stringWithFormat:@"%s: %.17g vs %.17g", #a, _a, _b]); } while (0)

// value in unit `from`, as a number of unit `to`
static double convert(double value, NSUnit *from, NSUnit *to)
{
    NSMeasurement *m = [[[NSMeasurement alloc] initWithDoubleValue:value unit:from] autorelease];
    return [[m measurementByConvertingToUnit:to] doubleValue];
}

static BOOL raises(void (^block)(void))
{
    @try { block(); }
    @catch (NSException *e) { return YES; }
    return NO;
}

// A dimension that is not predefined, with its own base unit: a "wobble" of 3 base units
@interface TestWobble : NSDimension
+ (TestWobble *)wobbles;
+ (TestWobble *)tripleWobbles;
@end
@implementation TestWobble
+ (TestWobble *)wobbles { return [[[TestWobble alloc] initWithSymbol:@"wob" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:1] autorelease]] autorelease]; }
+ (TestWobble *)tripleWobbles { return [[[TestWobble alloc] initWithSymbol:@"3wob" converter:[[[NSUnitConverterLinear alloc] initWithCoefficient:3] autorelease]] autorelease]; }
+ (instancetype)baseUnit { return [self wobbles]; }
@end

static void testConverters(void)
{
    NSUnitConverterLinear *plain = [[[NSUnitConverterLinear alloc] initWithCoefficient:2.5] autorelease];
    CHECK(plain.coefficient == 2.5 && plain.constant == 0);
    CHECK([plain baseUnitValueFromValue:4] == 10);
    CHECK([plain valueFromBaseUnitValue:10] == 4);

    NSUnitConverterLinear *offset = [[[NSUnitConverterLinear alloc] initWithCoefficient:2 constant:5] autorelease];
    CHECK(offset.coefficient == 2 && offset.constant == 5);
    CHECK([offset baseUnitValueFromValue:3] == 11);
    CHECK([offset valueFromBaseUnitValue:11] == 3);
    CHECK([offset isEqual:[[[NSUnitConverterLinear alloc] initWithCoefficient:2 constant:5] autorelease]]);
    CHECK(![offset isEqual:plain]);
    CHECK([offset copy] != nil);

    // test_quirk_abstract_converter_does_not_raise (MC26.15, macOS 26.7.3): the abstract converter
    // methods do not raise; the abstract +baseUnit does, with NSInvalidArgumentException
    // (test_quirk_abstract_dimension_base_unit).
    CHECK(!raises(^{ [[[[NSUnitConverter alloc] init] autorelease] baseUnitValueFromValue:1]; }));
    CHECK(!raises(^{ [[[[NSUnitConverter alloc] init] autorelease] valueFromBaseUnitValue:1]; }));
    @try { [NSDimension baseUnit]; CHECK(NO); }
    @catch (NSException *e) { CHECK([[e name] isEqualToString:NSInvalidArgumentException]); }

    CHECK([NSUnitConverterLinear supportsSecureCoding]);
}

static void testUnits(void)
{
    NSUnit *plain = [[[NSUnit alloc] initWithSymbol:@"widget"] autorelease];
    CHECK([plain.symbol isEqualToString:@"widget"]);
    CHECK([plain isEqual:[[[NSUnit alloc] initWithSymbol:@"widget"] autorelease]]);
    CHECK(![plain isEqual:[[[NSUnit alloc] initWithSymbol:@"gadget"] autorelease]]);
    CHECK([plain hash] == [[[[NSUnit alloc] initWithSymbol:@"widget"] autorelease] hash]);
    CHECK([[plain copy] isEqual:plain]);
    CHECK([NSUnit supportsSecureCoding] && [NSDimension supportsSecureCoding] && [NSMeasurement supportsSecureCoding]);

    // the symbol is not shared with a mutable string
    NSMutableString *mutableSymbol = [NSMutableString stringWithString:@"abc"];
    NSUnit *copied = [[[NSUnit alloc] initWithSymbol:mutableSymbol] autorelease];
    [mutableSymbol appendString:@"d"];
    CHECK([copied.symbol isEqualToString:@"abc"]);

    NSDimension *metre = [NSUnitLength meters];
    CHECK(metre == [NSUnitLength meters]);
    CHECK([metre.symbol isEqualToString:@"m"]);
    CHECK([[NSUnitLength baseUnit] isEqual:metre]);
    CHECK([[NSUnitMass baseUnit].symbol isEqualToString:@"kg"]);
    CHECK([[NSUnitTemperature baseUnit].symbol isEqualToString:@"K"]);
    CHECK([[NSUnitDuration baseUnit].symbol isEqualToString:@"s"]);
    CHECK([[NSUnitVolume baseUnit].symbol isEqualToString:@"L"]);
    CHECK([[NSUnitFuelEfficiency baseUnit].symbol isEqualToString:@"L/100km"]);
    // test_quirk_unit_symbols (MC26.15, macOS 26.7.3)
    CHECK([[NSUnitInformationStorage baseUnit].symbol isEqualToString:@"B"]);
    CHECK([[NSUnitAngle arcMinutes].symbol isEqualToString:@"\u02b9"] && [[NSUnitAngle arcSeconds].symbol isEqualToString:@"\u02ba"]);
    CHECK([[NSUnitElectricResistance ohms].symbol isEqualToString:@"\u2126"] && [[NSUnitElectricResistance kiloohms].symbol isEqualToString:@"k\u2126"]);
    CHECK([[NSUnitVolume imperialPints].symbol isEqualToString:[NSUnitVolume pints].symbol]);
    CHECK(![[NSUnitVolume imperialTeaspoons] isEqual:[NSUnitVolume teaspoons]]);
    CHECK(![[NSUnitVolume gallons] isEqual:[NSUnitVolume imperialGallons]]);
    CHECK(![[NSUnitFuelEfficiency milesPerGallon] isEqual:[NSUnitFuelEfficiency milesPerImperialGallon]]);
}

// Every dimension's class methods that return units: all are units of the class, are shared, have a
// symbol, and convert to the base unit and back.
static void testCatalog(void)
{
    struct { const char *name; unsigned minimum; } dimensions[] = {
        { "NSUnitAcceleration", 2 }, { "NSUnitAngle", 6 }, { "NSUnitArea", 14 }, { "NSUnitConcentrationMass", 2 },
        { "NSUnitDispersion", 1 }, { "NSUnitDuration", 7 }, { "NSUnitElectricCharge", 6 }, { "NSUnitElectricCurrent", 5 },
        { "NSUnitElectricPotentialDifference", 5 }, { "NSUnitElectricResistance", 5 }, { "NSUnitEnergy", 5 },
        { "NSUnitFrequency", 9 }, { "NSUnitFuelEfficiency", 3 }, { "NSUnitIlluminance", 1 }, { "NSUnitInformationStorage", 35 },
        { "NSUnitLength", 22 }, { "NSUnitMass", 16 }, { "NSUnitPower", 11 }, { "NSUnitPressure", 10 }, { "NSUnitSpeed", 4 },
        { "NSUnitTemperature", 3 }, { "NSUnitVolume", 31 },
    };

    for (size_t d = 0; d < sizeof(dimensions) / sizeof(dimensions[0]); d++)
    {
        Class dimension = objc_getClass(dimensions[d].name);
        CHECK(dimension != Nil);
        if (dimension == Nil)
            continue;
        CHECK([dimension isSubclassOfClass:[NSDimension class]]);
        CHECK([dimension supportsSecureCoding]);

        unsigned units = 0;
        unsigned count;
        Method *methods = class_copyMethodList(object_getClass(dimension), &count);
        for (unsigned i = 0; i < count; i++)
        {
            SEL selector = method_getName(methods[i]);
            if (method_getNumberOfArguments(methods[i]) != 2 || strcmp(sel_getName(selector), "baseUnit") == 0
                || sel_getName(selector)[0] == '.')
                continue;
            char *returnType = method_copyReturnType(methods[i]);
            BOOL returnsObject = returnType[0] == '@';
            free(returnType);
            if (!returnsObject)
                continue;

            NSDimension *unit = [dimension performSelector:selector];
            if (![unit isKindOfClass:[NSDimension class]])
                continue; // for example the NSString returned by +icuType on macOS
            NSString *what = [NSString stringWithFormat:@"%s %s", dimensions[d].name, sel_getName(selector)];
            expectTrue([unit isMemberOfClass:dimension], [what stringByAppendingString:@" is of the class"]);
            expectTrue([unit.symbol length] > 0, [what stringByAppendingString:@" has a symbol"]);
            expectTrue([dimension performSelector:selector] == unit, [what stringByAppendingString:@" is shared"]);
            expectTrue(unit.converter != nil, [what stringByAppendingString:@" has a converter"]);
            double back = [unit.converter valueFromBaseUnitValue:[unit.converter baseUnitValueFromValue:7.0]];
            expectTrue(fabs(back - 7.0) < 1e-9, [what stringByAppendingString:@" round-trips through the base unit"]);
            units++;
        }
        free(methods);
        expectTrue(units >= dimensions[d].minimum, [NSString stringWithFormat:@"%s has %u units, expected at least %u", dimensions[d].name, units, dimensions[d].minimum]);

        NSDimension *base = [dimension baseUnit];
        CHECK([base isMemberOfClass:dimension]);
        CHECK([base.converter baseUnitValueFromValue:3.5] == 3.5);
    }
}

static void testConversions(BOOL strict)
{
    double loose = strict ? 1e-12 : 1e-4;
    double tight = 1e-12;

    // length
    CHECK_CLOSE(convert(1, [NSUnitLength miles], [NSUnitLength meters]), 1609.344, tight);
    CHECK_CLOSE(convert(1, [NSUnitLength inches], [NSUnitLength centimeters]), 2.54, tight);
    CHECK_CLOSE(convert(1, [NSUnitLength feet], [NSUnitLength inches]), 12, tight);
    CHECK_CLOSE(convert(1, [NSUnitLength yards], [NSUnitLength feet]), 3, tight);
    CHECK_CLOSE(convert(1, [NSUnitLength nauticalMiles], [NSUnitLength meters]), 1852, tight);
    CHECK_CLOSE(convert(1, [NSUnitLength astronomicalUnits], [NSUnitLength kilometers]), 149597870.7, tight);
    CHECK_CLOSE(convert(1, [NSUnitLength lightyears], [NSUnitLength kilometers]), 9460730472580.8, tight);
    CHECK_CLOSE(convert(1, [NSUnitLength parsecs], [NSUnitLength lightyears]), 3.2615637771674, 1e-9);
    CHECK_CLOSE(convert(1, [NSUnitLength fathoms], [NSUnitLength feet]), 6, tight);
    CHECK_CLOSE(convert(1, [NSUnitLength furlongs], [NSUnitLength yards]), 220, tight);
    CHECK_CLOSE(convert(1, [NSUnitLength megameters], [NSUnitLength meters]), 1e6, tight);
    CHECK_CLOSE(convert(1, [NSUnitLength picometers], [NSUnitLength nanometers]), 1e-3, tight);

    // mass
    CHECK_CLOSE(convert(1, [NSUnitMass poundsMass], [NSUnitMass grams]), 453.59237, tight);
    CHECK_CLOSE(convert(1, [NSUnitMass ounces], [NSUnitMass poundsMass]), 1.0 / 16, tight);
    CHECK_CLOSE(convert(1, [NSUnitMass stones], [NSUnitMass poundsMass]), 14, tight);
    CHECK_CLOSE(convert(1, [NSUnitMass shortTons], [NSUnitMass poundsMass]), 2000, tight);
    CHECK_CLOSE(convert(1, [NSUnitMass metricTons], [NSUnitMass kilograms]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitMass carats], [NSUnitMass milligrams]), 200, tight);
    CHECK_CLOSE(convert(1, [NSUnitMass ouncesTroy], [NSUnitMass grams]), 31.1034768, tight);
    CHECK_CLOSE(convert(1, [NSUnitMass slugs], [NSUnitMass kilograms]), 14.5939029372, 1e-10);
    CHECK_CLOSE(convert(1, [NSUnitMass micrograms], [NSUnitMass milligrams]), 1e-3, tight);

    // volume
    CHECK_CLOSE(convert(1, [NSUnitVolume gallons], [NSUnitVolume liters]), 3.785411784, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume gallons], [NSUnitVolume quarts]), 4, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume quarts], [NSUnitVolume pints]), 2, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume pints], [NSUnitVolume cups]), 2, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume cups], [NSUnitVolume fluidOunces]), 8, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume fluidOunces], [NSUnitVolume tablespoons]), 2, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume tablespoons], [NSUnitVolume teaspoons]), 3, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume imperialGallons], [NSUnitVolume liters]), 4.54609, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume imperialGallons], [NSUnitVolume imperialFluidOunces]), 160, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume cubicMeters], [NSUnitVolume liters]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume cubicInches], [NSUnitVolume milliliters]), 16.387064, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume cubicFeet], [NSUnitVolume liters]), 28.316846592, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume acreFeet], [NSUnitVolume cubicFeet]), 43560, tight);
    CHECK_CLOSE(convert(1, [NSUnitVolume metricCups], [NSUnitVolume milliliters]), 250, tight);

    // area
    CHECK_CLOSE(convert(1, [NSUnitArea hectares], [NSUnitArea squareMeters]), 10000, tight);
    CHECK_CLOSE(convert(1, [NSUnitArea acres], [NSUnitArea squareFeet]), 43560, 1e-9);
    CHECK_CLOSE(convert(1, [NSUnitArea squareMiles], [NSUnitArea acres]), 640, 1e-9);
    CHECK_CLOSE(convert(1, [NSUnitArea squareKilometers], [NSUnitArea hectares]), 100, tight);
    CHECK_CLOSE(convert(1, [NSUnitArea squareInches], [NSUnitArea squareCentimeters]), 6.4516, tight);

    // angle
    CHECK_CLOSE(convert(M_PI, [NSUnitAngle radians], [NSUnitAngle degrees]), 180, tight);
    CHECK_CLOSE(convert(1, [NSUnitAngle revolutions], [NSUnitAngle degrees]), 360, tight);
    CHECK_CLOSE(convert(100, [NSUnitAngle gradians], [NSUnitAngle degrees]), 90, tight);
    CHECK_CLOSE(convert(60, [NSUnitAngle arcMinutes], [NSUnitAngle degrees]), 1, tight);
    CHECK_CLOSE(convert(3600, [NSUnitAngle arcSeconds], [NSUnitAngle degrees]), 1, tight);

    // time, frequency, speed, acceleration
    CHECK_CLOSE(convert(1, [NSUnitDuration hours], [NSUnitDuration seconds]), 3600, tight);
    CHECK_CLOSE(convert(1, [NSUnitDuration minutes], [NSUnitDuration milliseconds]), 60000, tight);
    CHECK_CLOSE(convert(1, [NSUnitDuration microseconds], [NSUnitDuration nanoseconds]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitDuration picoseconds], [NSUnitDuration nanoseconds]), 1e-3, tight);
    CHECK_CLOSE(convert(1, [NSUnitFrequency gigahertz], [NSUnitFrequency megahertz]), 1000, tight);
    CHECK_CLOSE(convert(60, [NSUnitSpeed milesPerHour], [NSUnitSpeed metersPerSecond]), 26.8224, tight);
    CHECK_CLOSE(convert(1, [NSUnitSpeed knots], [NSUnitSpeed kilometersPerHour]), 1.852, tight);
    CHECK_CLOSE(convert(36, [NSUnitSpeed kilometersPerHour], [NSUnitSpeed metersPerSecond]), 10, tight);
    CHECK_CLOSE(convert(1, [NSUnitAcceleration gravity], [NSUnitAcceleration metersPerSecondSquared]), 9.80665, tight);

    // temperature, with its offsets
    CHECK_CLOSE(convert(0, [NSUnitTemperature celsius], [NSUnitTemperature kelvin]), 273.15, tight);
    CHECK_CLOSE(convert(100, [NSUnitTemperature celsius], [NSUnitTemperature fahrenheit]), 212, tight);
    CHECK_CLOSE(convert(32, [NSUnitTemperature fahrenheit], [NSUnitTemperature celsius]) + 1, 1, tight);
    CHECK_CLOSE(convert(-40, [NSUnitTemperature celsius], [NSUnitTemperature fahrenheit]), -40, tight);
    CHECK_CLOSE(convert(0, [NSUnitTemperature kelvin], [NSUnitTemperature celsius]), -273.15, tight);
    CHECK_CLOSE(convert(0, [NSUnitTemperature kelvin], [NSUnitTemperature fahrenheit]), -459.67, tight);

    // energy, power, pressure
    CHECK_CLOSE(convert(1, [NSUnitEnergy kilowattHours], [NSUnitEnergy joules]), 3.6e6, tight);
    CHECK_CLOSE(convert(1, [NSUnitEnergy calories], [NSUnitEnergy joules]), 4.184, tight);
    CHECK_CLOSE(convert(1, [NSUnitEnergy kilocalories], [NSUnitEnergy calories]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitPower horsepower], [NSUnitPower watts]), 745.69987158227022, loose);
    CHECK_CLOSE(convert(1, [NSUnitPower gigawatts], [NSUnitPower megawatts]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitPressure bars], [NSUnitPressure kilopascals]), 100, tight);
    CHECK_CLOSE(convert(1013.25, [NSUnitPressure hectopascals], [NSUnitPressure bars]), 1.01325, tight);
    CHECK_CLOSE(convert(1, [NSUnitPressure poundsForcePerSquareInch], [NSUnitPressure kilopascals]), 6.894757293168, 1e-10);
    CHECK_CLOSE(convert(1, [NSUnitPressure millimetersOfMercury], [NSUnitPressure kilopascals]), 0.133322387415, loose);
    CHECK_CLOSE(convert(1, [NSUnitPressure inchesOfMercury], [NSUnitPressure kilopascals]), 3.386389, loose);

    // electricity
    CHECK_CLOSE(convert(1, [NSUnitElectricCharge ampereHours], [NSUnitElectricCharge coulombs]), 3600, tight);
    CHECK_CLOSE(convert(1000, [NSUnitElectricCharge milliampereHours], [NSUnitElectricCharge ampereHours]), 1, tight);
    CHECK_CLOSE(convert(1, [NSUnitElectricCurrent kiloamperes], [NSUnitElectricCurrent milliamperes]), 1e6, tight);
    CHECK_CLOSE(convert(1, [NSUnitElectricPotentialDifference kilovolts], [NSUnitElectricPotentialDifference volts]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitElectricResistance megaohms], [NSUnitElectricResistance kiloohms]), 1000, tight);

    // information: decimal and binary prefixes, bits and bytes
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage bytes], [NSUnitInformationStorage bits]), 8, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage nibbles], [NSUnitInformationStorage bits]), 4, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage kilobytes], [NSUnitInformationStorage bytes]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage kibibytes], [NSUnitInformationStorage bytes]), 1024, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage gigabytes], [NSUnitInformationStorage megabytes]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage gibibytes], [NSUnitInformationStorage mebibytes]), 1024, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage kilobits], [NSUnitInformationStorage bits]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage kibibits], [NSUnitInformationStorage bits]), 1024, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage megabits], [NSUnitInformationStorage kilobytes]), 125, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage yottabytes], [NSUnitInformationStorage zettabytes]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage yobibytes], [NSUnitInformationStorage zebibytes]), 1024, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage terabytes], [NSUnitInformationStorage gigabytes]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage petabytes], [NSUnitInformationStorage terabytes]), 1000, tight);
    CHECK_CLOSE(convert(1, [NSUnitInformationStorage exabytes], [NSUnitInformationStorage petabytes]), 1000, tight);

    // concentration, dispersion
    CHECK_CLOSE(convert(1, [NSUnitConcentrationMass milligramsPerDeciliter], [NSUnitConcentrationMass gramsPerLiter]), 0.01, tight);
    NSUnitConcentrationMass *glucose = [NSUnitConcentrationMass millimolesPerLiterWithGramsPerMole:180.156];
    CHECK([glucose.symbol isEqualToString:@"mmol/L"]);
    CHECK_CLOSE(convert(1, glucose, [NSUnitConcentrationMass gramsPerLiter]), 0.180156, tight);
    CHECK_CLOSE(convert(1, glucose, [NSUnitConcentrationMass milligramsPerDeciliter]), 18.0156, tight);
    CHECK_CLOSE(convert(5, [NSUnitDispersion partsPerMillion], [NSUnitDispersion partsPerMillion]), 5, tight);

    // fuel efficiency is reciprocal
    CHECK_CLOSE(convert(1, [NSUnitFuelEfficiency milesPerGallon], [NSUnitFuelEfficiency litersPer100Kilometers]), 235.2145833, 1e-8);
    CHECK_CLOSE(convert(10, [NSUnitFuelEfficiency litersPer100Kilometers], [NSUnitFuelEfficiency milesPerGallon]), 23.52145833, 1e-8);
    CHECK_CLOSE(convert(1, [NSUnitFuelEfficiency milesPerImperialGallon], [NSUnitFuelEfficiency litersPer100Kilometers]), 282.4809363, 1e-8);
    CHECK_CLOSE(convert(30, [NSUnitFuelEfficiency milesPerGallon], [NSUnitFuelEfficiency milesPerImperialGallon]), 36.0285, 1e-4);

    CHECK_CLOSE(convert(1, [NSUnitIlluminance lux], [NSUnitIlluminance lux]), 1, tight);
}

static void testMeasurements(void)
{
    NSMeasurement *km = [[[NSMeasurement alloc] initWithDoubleValue:2.5 unit:[NSUnitLength kilometers]] autorelease];
    CHECK(km.doubleValue == 2.5);
    CHECK([km.unit isEqual:[NSUnitLength kilometers]]);
    CHECK([km canBeConvertedToUnit:[NSUnitLength miles]]);
    CHECK(![km canBeConvertedToUnit:[NSUnitMass grams]]);
    CHECK(![km canBeConvertedToUnit:[[[NSUnit alloc] initWithSymbol:@"km"] autorelease]]);

    NSMeasurement *metres = [km measurementByConvertingToUnit:[NSUnitLength meters]];
    CHECK_CLOSE(metres.doubleValue, 2500, 1e-12);
    CHECK([metres.unit isEqual:[NSUnitLength meters]]);
    CHECK([[km measurementByConvertingToUnit:[NSUnitLength kilometers]] isEqual:km]);
    CHECK(raises(^{ [km measurementByConvertingToUnit:[NSUnitMass grams]]; }));
    CHECK(raises(^{ [km measurementByConvertingToUnit:[[[NSUnit alloc] initWithSymbol:@"km"] autorelease]]; }));

    // adding in one unit stays in it, in different units goes to the base unit
    NSMeasurement *a = [[[NSMeasurement alloc] initWithDoubleValue:1.5 unit:[NSUnitLength kilometers]] autorelease];
    NSMeasurement *sum = [km measurementByAddingMeasurement:a];
    CHECK(sum.doubleValue == 4 && [sum.unit isEqual:[NSUnitLength kilometers]]);
    NSMeasurement *diff = [km measurementBySubtractingMeasurement:a];
    CHECK(diff.doubleValue == 1 && [diff.unit isEqual:[NSUnitLength kilometers]]);
    NSMeasurement *m500 = [[[NSMeasurement alloc] initWithDoubleValue:500 unit:[NSUnitLength meters]] autorelease];
    sum = [km measurementByAddingMeasurement:m500];
    CHECK_CLOSE(sum.doubleValue, 3000, 1e-12);
    CHECK([sum.unit isEqual:[NSUnitLength meters]]);
    diff = [km measurementBySubtractingMeasurement:m500];
    CHECK_CLOSE(diff.doubleValue, 2000, 1e-12);
    CHECK([diff.unit isEqual:[NSUnitLength meters]]);
    NSMeasurement *grams = [[[NSMeasurement alloc] initWithDoubleValue:1 unit:[NSUnitMass grams]] autorelease];
    CHECK(raises(^{ [km measurementByAddingMeasurement:grams]; }));
    CHECK(raises(^{ [km measurementBySubtractingMeasurement:grams]; }));

    // temperatures add as absolute values in the base unit
    NSMeasurement *c = [[[NSMeasurement alloc] initWithDoubleValue:10 unit:[NSUnitTemperature celsius]] autorelease];
    NSMeasurement *k = [[[NSMeasurement alloc] initWithDoubleValue:1 unit:[NSUnitTemperature kelvin]] autorelease];
    CHECK_CLOSE([[c measurementByAddingMeasurement:k] doubleValue], 284.15, 1e-12);

    // equality and hash
    NSMeasurement *thousandMetres = [[[NSMeasurement alloc] initWithDoubleValue:1000 unit:[NSUnitLength meters]] autorelease];
    NSMeasurement *oneKm = [[[NSMeasurement alloc] initWithDoubleValue:1 unit:[NSUnitLength kilometers]] autorelease];
    CHECK([thousandMetres isEqual:oneKm]);
    CHECK([thousandMetres hash] == [oneKm hash]);
    CHECK(![thousandMetres isEqual:km]);
    CHECK(![oneKm isEqual:[[[NSMeasurement alloc] initWithDoubleValue:1 unit:[NSUnitMass kilograms]] autorelease]]);
    CHECK(![oneKm isEqual:@"1 km"]);
    NSMeasurement *negativeZero = [[[NSMeasurement alloc] initWithDoubleValue:-0.0 unit:[NSUnitLength meters]] autorelease];
    NSMeasurement *zero = [[[NSMeasurement alloc] initWithDoubleValue:0.0 unit:[NSUnitLength meters]] autorelease];
    CHECK([negativeZero isEqual:zero] && [negativeZero hash] == [zero hash]);
    CHECK([[oneKm copy] isEqual:oneKm]);

    // units that are not dimensions convert to themselves only
    NSUnit *widget = [[[NSUnit alloc] initWithSymbol:@"widget"] autorelease];
    NSMeasurement *widgets = [[[NSMeasurement alloc] initWithDoubleValue:3 unit:widget] autorelease];
    CHECK([widgets canBeConvertedToUnit:widget]);
    CHECK([[widgets measurementByAddingMeasurement:widgets] doubleValue] == 6);
    CHECK(raises(^{ [widgets measurementByAddingMeasurement:km]; }));

    // a dimension of the application
    NSMeasurement *wobbles = [[[NSMeasurement alloc] initWithDoubleValue:2 unit:[TestWobble tripleWobbles]] autorelease];
    CHECK_CLOSE([[wobbles measurementByConvertingToUnit:[TestWobble wobbles]] doubleValue], 6, 1e-12);
    CHECK(![wobbles canBeConvertedToUnit:[NSUnitLength meters]]);
}

static NSDictionary *archiveObjects(id root)
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:root requiringSecureCoding:YES error:&error];
    expectTrue(data != nil, [NSString stringWithFormat:@"archive %@: %@", root, error]);
    if (!data)
        return nil;
    return [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
}

static id unarchive(id root, Class cls)
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:root requiringSecureCoding:YES error:&error];
    expectTrue(data != nil, @"archive");
    if (!data)
        return nil;
    id result = [NSKeyedUnarchiver unarchivedObjectOfClass:cls fromData:data error:&error];
    expectTrue(result != nil, [NSString stringWithFormat:@"unarchive %@ as %@: %@", root, cls, error]);
    return result;
}

// the archived dictionary of the first object that has the key
static NSDictionary *objectWithKey(NSDictionary *archive, NSString *key)
{
    for (id object in archive[@"$objects"])
    {
        if ([object isKindOfClass:[NSDictionary class]] && object[key] != nil)
            return object;
    }
    return nil;
}

static void testSecureCoding(void)
{
    // each kind of object round-trips
    NSMeasurement *m = [[[NSMeasurement alloc] initWithDoubleValue:12.25 unit:[NSUnitLength feet]] autorelease];
    NSMeasurement *m2 = unarchive(m, [NSMeasurement class]);
    CHECK([m2 isEqual:m] && m2.doubleValue == 12.25 && [m2.unit isEqual:[NSUnitLength feet]]);
    CHECK([m2.unit isMemberOfClass:[NSUnitLength class]]);

    NSMeasurement *t = [[[NSMeasurement alloc] initWithDoubleValue:98.6 unit:[NSUnitTemperature fahrenheit]] autorelease];
    NSMeasurement *t2 = unarchive(t, [NSMeasurement class]);
    CHECK([t2.unit isEqual:[NSUnitTemperature fahrenheit]]);
    CHECK_CLOSE([[t2 measurementByConvertingToUnit:[NSUnitTemperature celsius]] doubleValue], 37, 1e-12);

    NSMeasurement *fuel = [[[NSMeasurement alloc] initWithDoubleValue:30 unit:[NSUnitFuelEfficiency milesPerGallon]] autorelease];
    NSMeasurement *fuel2 = unarchive(fuel, [NSMeasurement class]);
    CHECK([fuel2.unit isEqual:[NSUnitFuelEfficiency milesPerGallon]]);
    CHECK(![fuel2.unit isEqual:[NSUnitFuelEfficiency milesPerImperialGallon]]);

    NSUnit *plain = [[[NSUnit alloc] initWithSymbol:@"widget"] autorelease];
    NSMeasurement *widgets = unarchive([[[NSMeasurement alloc] initWithDoubleValue:3 unit:plain] autorelease], [NSMeasurement class]);
    CHECK([widgets.unit isEqual:plain] && [widgets.unit isMemberOfClass:[NSUnit class]]);

    NSUnit *u = unarchive([NSUnitMass grams], [NSUnit class]);
    CHECK([u isEqual:[NSUnitMass grams]] && [u isKindOfClass:[NSDimension class]]);
    NSDimension *custom = unarchive([TestWobble tripleWobbles], [NSDimension class]);
    CHECK([custom isMemberOfClass:[TestWobble class]] && [custom isEqual:[TestWobble tripleWobbles]]);
    NSUnitConverterLinear *converter = unarchive([[[NSUnitConverterLinear alloc] initWithCoefficient:3 constant:4] autorelease], [NSUnitConverter class]);
    CHECK([converter isKindOfClass:[NSUnitConverterLinear class]] && converter.coefficient == 3 && converter.constant == 4);

    // every predefined unit survives
    for (NSDimension *unit in @[[NSUnitArea acres], [NSUnitVolume imperialPints], [NSUnitInformationStorage kibibytes], [NSUnitPower horsepower],
                                [NSUnitAngle arcSeconds], [NSUnitElectricResistance ohms], [NSUnitConcentrationMass milligramsPerDeciliter]])
        expectTrue([unarchive(unit, [NSUnit class]) isEqual:unit], [NSString stringWithFormat:@"%@ round trip", unit.symbol]);

    // the archive layout: Mac check pending for the units other than those with a known id
    NSDictionary *archive = archiveObjects(m);
    NSDictionary *measurement = objectWithKey(archive, @"NS.value");
    CHECK(measurement != nil && [measurement[@"NS.value"] doubleValue] == 12.25 && measurement[@"NS.unit"] != nil);
    NSDictionary *unit = objectWithKey(archive, @"NS.converter");
    CHECK(unit != nil && unit[@"NS.symbol"] != nil && unit[@"NS.specifier"] != nil);
    NSDictionary *linear = objectWithKey(archive, @"NS.coefficient");
    CHECK(linear != nil && [linear[@"NS.coefficient"] doubleValue] == 0.3048 && [linear[@"NS.constant"] doubleValue] == 0);

    struct { NSDimension *unit; int specifier; } known[] = {
        { [NSUnitLength meters], 1280 }, { [NSUnitLength kilometers], 1282 }, { [NSUnitMass grams], 1536 },
        { [NSUnitDuration seconds], 1030 }, { [NSUnitSpeed metersPerSecond], 2304 }, { [NSUnitTemperature fahrenheit], 2561 },
        // test_quirk_archive_specifiers: the ids observed on macOS 26.7.3 (MC26.15)
        { [NSUnitAcceleration baseUnit], 1 }, { [NSUnitAcceleration gravity], 0 }, { [NSUnitAngle degrees], 256 },
        { [NSUnitAngle arcMinutes], 257 }, { [NSUnitAngle arcSeconds], 258 }, { [NSUnitAngle radians], 259 },
        { [NSUnitAngle revolutions], 260 }, { [NSUnitArea squareMeters], 512 }, { [NSUnitArea acres], 516 },
        { [NSUnitArea squareYards], 520 }, { [NSUnitDuration hours], 1028 }, { [NSUnitDuration nanoseconds], 1033 },
        { [NSUnitVolume milliliters], 2819 }, { [NSUnitVolume megaliters], 2823 }, { [NSUnitVolume teaspoons], 2831 },
        { [NSUnitVolume imperialTeaspoons], 2831 }, { [NSUnitVolume imperialFluidOunces], 2833 },
        { [NSUnitVolume imperialPints], 2835 }, { [NSUnitVolume gallons], 2837 }, { [NSUnitVolume metricCups], 2838 },
        { [NSUnitVolume imperialGallons], 2840 }, { [NSUnitFuelEfficiency milesPerGallon], 3329 },
        { [NSUnitFuelEfficiency litersPer100Kilometers], 3330 }, { [NSUnitFuelEfficiency milesPerImperialGallon], 3331 },
        { [NSUnitInformationStorage bits], 3584 }, { [NSUnitInformationStorage bytes], 3585 },
        { [NSUnitElectricResistance ohms], 3842 }, { [NSUnitIlluminance baseUnit], 4352 },
        { [NSUnitConcentrationMass milligramsPerDeciliter], 4609 }, { [NSUnitDispersion baseUnit], 4611 },
    };
    for (size_t i = 0; i < sizeof(known) / sizeof(known[0]); i++)
    {
        NSDictionary *o = objectWithKey(archiveObjects(known[i].unit), @"NS.specifier");
        expectTrue([o[@"NS.specifier"] intValue] == known[i].specifier, [NSString stringWithFormat:@"%@ archives with its id", known[i].unit.symbol]);
    }
    CHECK([objectWithKey(archiveObjects([TestWobble tripleWobbles]), @"NS.specifier")[@"NS.specifier"] intValue] == -1);
    // units without a predefined id archive -1 (macOS 26.7.3, MC26.15)
    CHECK([objectWithKey(archiveObjects([NSUnitAngle gradians]), @"NS.specifier")[@"NS.specifier"] intValue] == -1);
    CHECK([objectWithKey(archiveObjects([NSUnitElectricResistance kiloohms]), @"NS.specifier")[@"NS.specifier"] intValue] == -1);

    // refused: other classes than the allowed ones
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:m requiringSecureCoding:YES error:NULL];
    CHECK([NSKeyedUnarchiver unarchivedObjectOfClass:[NSUnit class] fromData:data error:&error] == nil);
    CHECK(error != nil && error.code == NSCoderReadCorruptError);
    CHECK([NSKeyedUnarchiver unarchivedObjectOfClass:[NSString class] fromData:data error:&error] == nil);

    // an unit that has lost its symbol or its converter does not decode
    NSMutableDictionary *broken = [[archiveObjects([NSUnitMass grams]) mutableCopy] autorelease];
    NSMutableArray *objects = [[broken[@"$objects"] mutableCopy] autorelease];
    for (NSUInteger i = 0; i < [objects count]; i++)
    {
        if ([objects[i] isKindOfClass:[NSDictionary class]] && objects[i][@"NS.converter"] != nil)
        {
            NSMutableDictionary *d = [[objects[i] mutableCopy] autorelease];
            [d removeObjectForKey:@"NS.converter"];
            objects[i] = d;
        }
    }
    broken[@"$objects"] = objects;
    NSData *brokenData = [NSPropertyListSerialization dataWithPropertyList:broken format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    error = nil;
    CHECK([NSKeyedUnarchiver unarchivedObjectOfClass:[NSUnit class] fromData:brokenData error:&error] == nil);
    CHECK(error != nil && error.code == NSCoderReadCorruptError);
}

int main(int argc, char **argv)
{
    @autoreleasepool
    {
        BOOL strict = argc > 1 && strcmp(argv[1], "strict") == 0;
        testConverters();
        testUnits();
        testCatalog();
        testConversions(strict);
        testMeasurements();
        testSecureCoding();
    }
    if (failures)
    {
        NSLog(@"%d failures", failures);
        return 1;
    }
    NSLog(@"PASS");
    return 0;
}
