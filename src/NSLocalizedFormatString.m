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

// A localized string from a .stringsdict table, made by CoreFoundation's string
// table loader (CFBundle). Its characters are the entry's
// NSStringLocalizedFormatKey value; it also keeps the whole entry, which
// CoreFoundation's string formatting consults to expand the %#@variable@
// specifiers of the format. Copies, mutable or not, keep the entry; strings
// derived in any other way are ordinary strings.

#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <CoreFoundation/CFString.h>

@interface __NSLocalizedFormatString : NSMutableString {
    NSMutableString *_storage;
    NSDictionary *_configuration;
}
@end

@implementation __NSLocalizedFormatString

- (instancetype)_initWithFormat:(NSString *)format configuration:(NSDictionary *)configuration
{
    self = [super init];
    if (self) {
        _storage = (NSMutableString *)CFStringCreateMutableCopy(kCFAllocatorDefault, 0, (CFStringRef)format);
        _configuration = [configuration copy];
    }
    return self;
}

- (void)dealloc
{
    [_storage release];
    [_configuration release];
    [super dealloc];
}

- (NSDictionary *)_localizedFormatConfiguration
{
    return _configuration;
}

- (NSUInteger)length
{
    return [_storage length];
}

- (unichar)characterAtIndex:(NSUInteger)index
{
    return [_storage characterAtIndex:index];
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)range
{
    [_storage getCharacters:buffer range:range];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)string
{
    [_storage replaceCharactersInRange:range withString:string];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[__NSLocalizedFormatString allocWithZone:zone] _initWithFormat:_storage configuration:_configuration];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[__NSLocalizedFormatString allocWithZone:zone] _initWithFormat:_storage configuration:_configuration];
}

@end
