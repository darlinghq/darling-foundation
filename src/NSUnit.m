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

@implementation NSUnit

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithSymbol:(NSString *)symbol
{
    self = [super init];
    if (self != nil)
        _symbol = [symbol copy];
    return self;
}

- (void)dealloc
{
    [_symbol release];
    [super dealloc];
}

- (NSString *)symbol
{
    return _symbol;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *symbol = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.symbol"];
    if (symbol == nil)
    {
        [self release];
        [NSException raise:NSInvalidUnarchiveOperationException format:@"A unit has no symbol"];
    }
    return [self initWithSymbol:symbol];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_symbol forKey:@"NS.symbol"];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    return [object isMemberOfClass:[self class]] && [((NSUnit *) object)->_symbol isEqual:_symbol];
}

- (NSUInteger)hash
{
    return [_symbol hash];
}

@end
