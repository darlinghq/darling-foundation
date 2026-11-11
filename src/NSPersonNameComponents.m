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

#import <Foundation/NSPersonNameComponents.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSString.h>

// Keyed archives store the components inside a separate holder object under the key
// "NS.nameComponentsPrivate"; the root object itself carries no other keys. The holder writes all seven
// values, with nil encoded as the archive's null reference.
// Evidence: black-box observation on macOS 27 (tier 2), keyed archive dumped with plutil, probe
// vd-upstream/mac-probes/v217-personname.m. Test: nspersonnamecomponents.m (test_quirk_archive_layout).
@interface _NSPersonNameComponentsData : NSObject <NSSecureCoding>
{
    @public
    NSString *_namePrefix;
    NSString *_givenName;
    NSString *_middleName;
    NSString *_familyName;
    NSString *_nameSuffix;
    NSString *_nickname;
    NSPersonNameComponents *_phoneticRepresentation;
}
@end

@implementation _NSPersonNameComponentsData

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)dealloc
{
    [_namePrefix release];
    [_givenName release];
    [_middleName release];
    [_familyName release];
    [_nameSuffix release];
    [_nickname release];
    [_phoneticRepresentation release];
    [super dealloc];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil)
    {
        _namePrefix = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.namePrefix"] copy];
        _givenName = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.givenName"] copy];
        _middleName = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.middleName"] copy];
        _familyName = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.familyName"] copy];
        _nameSuffix = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.nameSuffix"] copy];
        _nickname = [[coder decodeObjectOfClass:[NSString class] forKey:@"NS.nickname"] copy];
        _phoneticRepresentation = [[coder decodeObjectOfClass:[NSPersonNameComponents class] forKey:@"NS.phoneticRepresentation"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_familyName forKey:@"NS.familyName"];
    [coder encodeObject:_givenName forKey:@"NS.givenName"];
    [coder encodeObject:_middleName forKey:@"NS.middleName"];
    [coder encodeObject:_namePrefix forKey:@"NS.namePrefix"];
    [coder encodeObject:_nameSuffix forKey:@"NS.nameSuffix"];
    [coder encodeObject:_nickname forKey:@"NS.nickname"];
    [coder encodeObject:_phoneticRepresentation forKey:@"NS.phoneticRepresentation"];
}

@end

@implementation NSPersonNameComponents

@synthesize namePrefix = _namePrefix;
@synthesize givenName = _givenName;
@synthesize middleName = _middleName;
@synthesize familyName = _familyName;
@synthesize nameSuffix = _nameSuffix;
@synthesize nickname = _nickname;
@synthesize phoneticRepresentation = _phoneticRepresentation;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)dealloc
{
    [_namePrefix release];
    [_givenName release];
    [_middleName release];
    [_familyName release];
    [_nameSuffix release];
    [_nickname release];
    [_phoneticRepresentation release];
    [super dealloc];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self != nil)
    {
        _NSPersonNameComponentsData *data = [coder decodeObjectOfClass:[_NSPersonNameComponentsData class] forKey:@"NS.nameComponentsPrivate"];
        if (data != nil)
        {
            _namePrefix = [data->_namePrefix copy];
            _givenName = [data->_givenName copy];
            _middleName = [data->_middleName copy];
            _familyName = [data->_familyName copy];
            _nameSuffix = [data->_nameSuffix copy];
            _nickname = [data->_nickname copy];
            _phoneticRepresentation = [data->_phoneticRepresentation copy];
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    _NSPersonNameComponentsData *data = [[_NSPersonNameComponentsData alloc] init];
    data->_namePrefix = [_namePrefix retain];
    data->_givenName = [_givenName retain];
    data->_middleName = [_middleName retain];
    data->_familyName = [_familyName retain];
    data->_nameSuffix = [_nameSuffix retain];
    data->_nickname = [_nickname retain];
    data->_phoneticRepresentation = [_phoneticRepresentation retain];
    [coder encodeObject:data forKey:@"NS.nameComponentsPrivate"];
    [data release];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSPersonNameComponents *copy = [[[self class] allocWithZone:zone] init];
    copy->_namePrefix = [_namePrefix copy];
    copy->_givenName = [_givenName copy];
    copy->_middleName = [_middleName copy];
    copy->_familyName = [_familyName copy];
    copy->_nameSuffix = [_nameSuffix copy];
    copy->_nickname = [_nickname copy];
    copy->_phoneticRepresentation = [_phoneticRepresentation copy];
    return copy;
}

static BOOL equalOrBothNil(id a, id b)
{
    return a == b || [a isEqual:b];
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
    {
        return YES;
    }
    if (![other isKindOfClass:[NSPersonNameComponents class]])
    {
        return NO;
    }
    NSPersonNameComponents *components = other;
    return equalOrBothNil(_namePrefix, components->_namePrefix)
        && equalOrBothNil(_givenName, components->_givenName)
        && equalOrBothNil(_middleName, components->_middleName)
        && equalOrBothNil(_familyName, components->_familyName)
        && equalOrBothNil(_nameSuffix, components->_nameSuffix)
        && equalOrBothNil(_nickname, components->_nickname)
        && equalOrBothNil(_phoneticRepresentation, components->_phoneticRepresentation);
}

- (NSUInteger)hash
{
    return [_givenName hash] ^ ([_familyName hash] << 1) ^ ([_middleName hash] << 2) ^ ([_nickname hash] << 3);
}

// QUIRK: the description lists the seven values in this order and format, with no comma before the phonetic
// representation. Evidence: black-box observation on macOS 27 (tier 2), probe
// vd-upstream/mac-probes/v217-personname.m. Test: nspersonnamecomponents.m (test_quirk_description_format).
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> {givenName = %@, familyName = %@, middleName = %@, namePrefix = %@, nameSuffix = %@, nickname = %@ phoneticRepresentation = %@ }",
        [self class], self, _givenName, _familyName, _middleName, _namePrefix, _nameSuffix, _nickname, _phoneticRepresentation];
}

@end
