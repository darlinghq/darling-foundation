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

#import <Foundation/NSObject.h>

@class NSArray, NSAttributedString, NSDictionary, NSString;

NS_ASSUME_NONNULL_BEGIN

// An item that an app and an extension exchange: some content and its
// attachments (https://developer.apple.com/documentation/foundation/nsextensionitem).
// The title, the content text and the attachments are kept in the user info,
// under the keys below.
// TODO: NSSecureCoding
@interface NSExtensionItem : NSObject <NSCopying> {
    NSDictionary *_userInfo;
}
@property (nullable, copy) NSAttributedString *attributedTitle;
@property (nullable, copy) NSAttributedString *attributedContentText;
@property (nullable, copy) NSArray *attachments;
@property (nullable, copy) NSDictionary *userInfo;
@end

FOUNDATION_EXPORT NSString * const NSExtensionItemAttributedTitleKey;
FOUNDATION_EXPORT NSString * const NSExtensionItemAttributedContentTextKey;
FOUNDATION_EXPORT NSString * const NSExtensionItemAttachmentsKey;

NS_ASSUME_NONNULL_END
