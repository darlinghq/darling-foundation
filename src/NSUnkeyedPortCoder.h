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

#import "NSConcretePortCoder.h"

@class NSInvocation, NSMutableArray;

CF_PRIVATE
@interface NSUnkeyedPortCoder : NSConcretePortCoder {
    NSPort *_recvPort;
    NSPort *_sendPort;
    NSMutableArray *_components;

    BOOL _isBycopy;
    BOOL _isByref;

    NSUInteger _componentIndex;
    NSUInteger _readingOffset;
}

- (NSArray *) components;
- (BOOL) _hasMoreData;

- (void) encodeObject: (id) object
             isBycopy: (BOOL) isBycopy
              isByref: (BOOL) isByref;

- (id) decodeRetainedObject NS_RETURNS_RETAINED;

- (void) encodeReturnValue: (NSInvocation *) invocation;
- (void) decodeReturnValue: (NSInvocation *) invocation;

@end
