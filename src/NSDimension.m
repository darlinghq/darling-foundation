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

#import <Foundation/NSUnit.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyedArchiver.h>
#import "NSUnitInternal.h"

@implementation NSDimension

- (instancetype)initWithSymbol:(NSString *)symbol converter:(NSUnitConverter *)converter
{
    self = [super initWithSymbol:symbol];
    if (self != nil)
        _converter = [converter copy];
    return self;
}

- (void)dealloc
{
    [_converter release];
    [super dealloc];
}

- (NSUnitConverter *)converter
{
    return _converter;
}

+ (instancetype)baseUnit
{
    [NSException raise:NSInternalInconsistencyException format:@"+[%@ baseUnit] is implemented by the subclasses of NSDimension", self];
    return nil;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *symbol = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.symbol"];
    NSUnitConverter *converter = [coder decodeObjectOfClass:[NSUnitConverter class] forKey:@"NS.converter"];

    // NS.specifier is the id of a predefined unit in an archive. The symbol and the converter that
    // are archived with it carry the same information, so decoding does not need it.
    if (symbol == nil || converter == nil)
    {
        [self release];
        [NSException raise:NSInvalidUnarchiveOperationException format:@"A dimension has no symbol or no converter"];
    }
    return [self initWithSymbol:symbol converter:converter];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeObject:_converter forKey:@"NS.converter"];
    [coder encodeInteger:_NSDimensionArchiveSpecifier(self) forKey:@"NS.specifier"];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    return [super isEqual:object] && [((NSDimension *) object)->_converter isEqual:_converter];
}

- (NSUInteger)hash
{
    return [super hash] ^ [_converter hash];
}

@end
