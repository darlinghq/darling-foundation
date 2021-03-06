/*
  This file is part of Darling.

  Copyright (C) 2020 Lubos Dolezel

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

#import <Foundation/NSPortCoder.h>
#import <string.h>

@class NSConnection, NSSet;

CF_PRIVATE
@interface NSConcretePortCoder: NSPortCoder {
    NSSet *_whitelist;
}

- (void) _setWhitelist: (NSSet *) whitelist;
- (BOOL) _classAllowed: (Class) class;

- (NSConnection *) connection;
- (NSArray *) finishedComponents;
- (void) invalidate;

- (void) encodePortObject: (NSPort *) port forKey: (NSString *) key;
- (NSPort *) decodePortObjectForKey: (NSString *) key;

- (void) encodeInvocation: (NSInvocation *) invocation;
- (NSInvocation *) decodeInvocation;

@end
