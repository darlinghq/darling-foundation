// Helpers shared by NSLengthFormatter, NSMassFormatter and NSEnergyFormatter.
// Ported from swift-corelibs-foundation (Sources/Foundation/{Length,Mass,Energy}Formatter.swift),
// Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors,
// licensed under Apache License v2.0 with Runtime Library Exception.

#import <Foundation/NSException.h>
#import <Foundation/NSFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

static inline NSNumberFormatter *_NSUnitFormatterNewNumberFormatter(void)
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    return formatter;
}

static inline BOOL _NSUnitFormatterUsesMetricSystem(NSNumberFormatter *formatter)
{
    return [[[formatter locale] objectForKey:NSLocaleUsesMetricSystem] boolValue];
}

static inline NSString *_NSUnitFormatterJoin(NSNumberFormatter *formatter, NSFormattingUnitStyle style,
                                             double value, NSString *unitString)
{
    NSString *number = [formatter stringFromNumber:[NSNumber numberWithDouble:value]];
    if (number == nil)
    {
        [NSException raise:NSInternalInconsistencyException format:@"%@ cannot format %g", formatter, value];
    }
    return [NSString stringWithFormat:@"%@%@%@", number, style == NSFormattingUnitStyleShort ? @"" : @" ", unitString];
}
