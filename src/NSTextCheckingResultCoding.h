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

// Returns NO for a coder that is not keyed or a missing range.
//
// QUIRK: a negative or overflowing location and length are accepted and carried
// into the NSRange unchanged, not refused. Not documented. Evidence: black-box
// observation on macOS 26.7.3 (tier 2), MC26.13 (the guest test decoding a
// result with a stored value of the wrong class does not fail there).
// Test: test_quirk_text_checking_result_lenient_decoding in
// tests/secure-coding-conformance.m
static inline BOOL NSTextCheckingResultDecodeRange(NSCoder *coder, NSRange *range)
{
    if (![coder allowsKeyedCoding] || ![coder containsValueForKey:@"NSRangeLocation"] || ![coder containsValueForKey:@"NSRangeLength"])
    {
        return NO;
    }
    NSInteger location = [coder decodeIntegerForKey:@"NSRangeLocation"];
    NSInteger length = [coder decodeIntegerForKey:@"NSRangeLength"];
    *range = NSMakeRange((NSUInteger)location, (NSUInteger)length);
    return YES;
}

// QUIRK: a string-valued field (replacement string, link target) stored with
// another plain value class (a number, or a string where a URL is expected) is
// not refused: the result still decodes, and the field is dropped when it
// cannot be converted. Not documented. Evidence: black-box observation on
// macOS 26.7.3 (tier 2), MC26.13. Test:
// test_quirk_text_checking_result_lenient_decoding in
// tests/secure-coding-conformance.m
static inline NSSet *NSTextCheckingResultLenientClasses(Class primary)
{
    return [NSSet setWithObjects:primary, [NSString class], [NSNumber class], nil];
}
