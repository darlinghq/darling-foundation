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

#import <Foundation/NSExtensionItem.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSAttributedString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

NSString * const NSExtensionItemAttributedTitleKey = @"NSExtensionItemAttributedTitleKey";
NSString * const NSExtensionItemAttributedContentTextKey = @"NSExtensionItemAttributedContentTextKey";
NSString * const NSExtensionItemAttachmentsKey = @"NSExtensionItemAttachmentsKey";

@implementation NSExtensionItem

- (void)dealloc
{
    [_userInfo release];
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSExtensionItem *copy = [[[self class] allocWithZone:zone] init];
    copy.userInfo = self.userInfo;
    return copy;
}

- (NSDictionary *)userInfo
{
    @synchronized (self) {
        return [[_userInfo retain] autorelease];
    }
}

- (void)setUserInfo:(NSDictionary *)userInfo
{
    NSDictionary *copied = [userInfo copy];
    @synchronized (self) {
        [_userInfo release];
        _userInfo = copied;
    }
}

- (id)userInfoValueForKey:(NSString *)key
{
    return [self.userInfo objectForKey:key];
}

// Sets one key of the user info, keeping the others; nil removes it.
- (void)setUserInfoValue:(id)value forKey:(NSString *)key
{
    id copied = [value copy];
    @synchronized (self) {
        NSMutableDictionary *userInfo = _userInfo ? [_userInfo mutableCopy] : [[NSMutableDictionary alloc] init];
        if (copied != nil) {
            [userInfo setObject:copied forKey:key];
        } else {
            [userInfo removeObjectForKey:key];
        }
        [_userInfo release];
        _userInfo = [userInfo copy];
        [userInfo release];
    }
    [copied release];
}

- (NSAttributedString *)attributedTitle
{
    return [self userInfoValueForKey:NSExtensionItemAttributedTitleKey];
}

- (void)setAttributedTitle:(NSAttributedString *)title
{
    [self setUserInfoValue:title forKey:NSExtensionItemAttributedTitleKey];
}

- (NSAttributedString *)attributedContentText
{
    return [self userInfoValueForKey:NSExtensionItemAttributedContentTextKey];
}

- (void)setAttributedContentText:(NSAttributedString *)text
{
    [self setUserInfoValue:text forKey:NSExtensionItemAttributedContentTextKey];
}

- (NSArray *)attachments
{
    return [self userInfoValueForKey:NSExtensionItemAttachmentsKey];
}

- (void)setAttachments:(NSArray *)attachments
{
    [self setUserInfoValue:attachments forKey:NSExtensionItemAttachmentsKey];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> - userInfo: %@", [self class], self, self.userInfo];
}

@end
