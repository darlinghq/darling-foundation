/*
 This file is part of Darling.

 Copyright (C) 2026 redminote11tech

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

@class NSString, NSDate;

NS_ASSUME_NONNULL_BEGIN

@interface NSDistributedLock : NSObject {
    NSString *_path;
    BOOL _isLocked;
}

@property (readonly, copy) NSDate *lockDate;

+ (nullable NSDistributedLock *)lockWithPath:(NSString *)path;
- (nullable instancetype)init; // NS_UNAVAILABLE
- (nullable instancetype)initWithPath:(NSString *)path NS_DESIGNATED_INITIALIZER;

- (BOOL)tryLock;
- (void)unlock;
- (void)breakLock;

@end

NS_ASSUME_NONNULL_END
