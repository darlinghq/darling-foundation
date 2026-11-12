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

// The keyed coding every NSTextCheckingResult subclass shares: the matched
// range under NSRangeLocation and NSRangeLength.
#import <Foundation/NSCoder.h>
#import <Foundation/NSRange.h>

static inline void NSTextCheckingResultEncodeRange(NSCoder *coder, NSRange range)
{
    [coder encodeInteger:(NSInteger)range.location forKey:@"NSRangeLocation"];
    [coder encodeInteger:(NSInteger)range.length forKey:@"NSRangeLength"];
}

// Returns NO for a coder that is not keyed, a missing range, or one that does
// not fit in an NSRange.
static inline BOOL NSTextCheckingResultDecodeRange(NSCoder *coder, NSRange *range)
{
    if (![coder allowsKeyedCoding] || ![coder containsValueForKey:@"NSRangeLocation"] || ![coder containsValueForKey:@"NSRangeLength"])
    {
        return NO;
    }
    NSInteger location = [coder decodeIntegerForKey:@"NSRangeLocation"];
    NSInteger length = [coder decodeIntegerForKey:@"NSRangeLength"];
    if (location < 0 || length < 0 || (NSUInteger)location + (NSUInteger)length < (NSUInteger)location)
    {
        return NO;
    }
    *range = NSMakeRange((NSUInteger)location, (NSUInteger)length);
    return YES;
}
