/*
  This file is part of Darling.

  Copyright (C) 2019 Lubos Dolezel

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

#import <Foundation/NSDistantObjectRequest.h>

@class NSAutoreleasePool;

CF_PRIVATE
@interface NSConcreteDistantObjectRequest : NSDistantObjectRequest {
    id _conversation;
    NSConnection *_connection;
    NSInvocation *_invocation;
    uint32_t _sequenceNumber;
    NSAutoreleasePool *_pool;
}

- (instancetype) initWithConversation: (id) conversation
                           connection: (NSConnection *) connection
                           invocation: (NSInvocation *) invocation
                       sequenceNumber: (uint32_t) sequenceNumber
                        releasingPool: (NSAutoreleasePool *) pool;

@end
