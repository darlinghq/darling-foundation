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

#import "NSConcreteDistantObjectRequest.h"
#import "NSConnectionInternal.h"

@implementation NSConcreteDistantObjectRequest

@synthesize conversation = _conversation;
@synthesize connection = _connection;
@synthesize invocation = _invocation;

- (instancetype) initWithConversation: (id) conversation
                           connection: (NSConnection *) connection
                           invocation: (NSInvocation *) invocation
                       sequenceNumber: (uint32_t) sequenceNumber
                        releasingPool: (NSAutoreleasePool *) pool
{
    _conversation = [conversation retain];
    _connection = [connection retain];
    _invocation = [invocation retain];
    _sequenceNumber = sequenceNumber;
    _pool = pool;
    return self;
}

- (void) replyWithException: (NSException *) exception {
    [_connection _replyToInvocation: _invocation
                      withException: exception
                     sequenceNumber: _sequenceNumber
                      releasingPool: _pool];
    _pool = nil;
}

- (void) dealloc {
    [_conversation release];
    [_connection release];
    [_invocation release];
    [_pool release];
    [super dealloc];
}

@end
