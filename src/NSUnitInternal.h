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

// Private pieces of the unit classes shared between their implementation files.

#import <Foundation/NSUnit.h>

// The converter of the fuel efficiency units that are distance per volume.
@interface NSUnitConverterReciprocal : NSUnitConverter <NSCopying, NSSecureCoding>
{
    double _coefficient;
}

- (instancetype)initWithCoefficient:(double)coefficient;

@end

// The id that identifies a predefined unit in an archive, or -1 for one that is not among the
// units whose id is known.
NSInteger _NSDimensionArchiveSpecifier(NSDimension *unit);
