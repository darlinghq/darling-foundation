/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * -attribute:atIndex:longestEffectiveRange:inRange: treats an absent
 * attribute as a value (nil equals nil) and compares values with isEqual:
 * rather than by pointer.
 *
 * Build: clang -target <arch>-apple-macos... -framework Foundation
 *        -lobjc nsattributedstring_longest_range.m
 */

#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expect(int ok, const char* what)
{
	printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
	if (!ok)
		failures++;
}

int main(void)
{
	@autoreleasepool {
		NSMutableAttributedString* s = [[[NSMutableAttributedString alloc] initWithString:@"0123456789"] autorelease];
		/* "bold" is absent on 0-2 and 7-9, present on 3-6 (two equal but distinct strings) */
		[s addAttribute:@"bold" value:[NSString stringWithFormat:@"%d", 1] range:NSMakeRange(3, 2)];
		[s addAttribute:@"bold" value:[NSString stringWithFormat:@"%d", 1] range:NSMakeRange(5, 2)];

		NSRange r;
		id v = [s attribute:@"bold" atIndex:0 longestEffectiveRange:&r inRange:NSMakeRange(0, 10)];
		expect(v == nil && NSEqualRanges(r, NSMakeRange(0, 3)), "absent attribute at the start spans 0..3");

		v = [s attribute:@"bold" atIndex:8 longestEffectiveRange:&r inRange:NSMakeRange(0, 10)];
		expect(v == nil && NSEqualRanges(r, NSMakeRange(7, 3)), "absent attribute at the end spans 7..10");

		v = [s attribute:@"bold" atIndex:4 longestEffectiveRange:&r inRange:NSMakeRange(0, 10)];
		expect(v != nil && NSEqualRanges(r, NSMakeRange(3, 4)), "equal (isEqual:) values merge into one run");

		v = [s attribute:@"bold" atIndex:4 longestEffectiveRange:&r inRange:NSMakeRange(4, 1)];
		expect(NSEqualRanges(r, NSMakeRange(4, 1)), "result is clipped to the limit range");
	}
	printf("%s\n", failures ? "FAILED" : "ALL PASSED");
	return failures ? 1 : 0;
}
