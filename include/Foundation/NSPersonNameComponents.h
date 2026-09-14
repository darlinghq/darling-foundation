/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

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

#import <Foundation/NSObject.h>

@class NSString;

NS_ASSUME_NONNULL_BEGIN

@interface NSPersonNameComponents : NSObject <NSCopying, NSSecureCoding>
{
    NSString *_namePrefix;
    NSString *_givenName;
    NSString *_middleName;
    NSString *_familyName;
    NSString *_nameSuffix;
    NSString *_nickname;
    NSPersonNameComponents *_phoneticRepresentation;
}

@property (copy, nullable) NSString *namePrefix;
@property (copy, nullable) NSString *givenName;
@property (copy, nullable) NSString *middleName;
@property (copy, nullable) NSString *familyName;
@property (copy, nullable) NSString *nameSuffix;
@property (copy, nullable) NSString *nickname;
@property (copy, nullable) NSPersonNameComponents *phoneticRepresentation;

@end

NS_ASSUME_NONNULL_END
