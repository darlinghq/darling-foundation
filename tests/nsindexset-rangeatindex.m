/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * -[NSIndexSet rangeAtIndex:] returns the n-th contiguous range of the set.
 * test_quirk_range_at_index_out_of_bounds_raises: an index that is not smaller
 * than the number of ranges raises NSInvalidArgumentException (observed on
 * macOS 27).
 *
 * Build: clang -target <arch>-apple-macos... -framework Foundation
 *        -lobjc nsindexset-rangeatindex.m
 */

#import <Foundation/Foundation.h>
#include <stdio.h>

/* Not in the public headers. */
@interface NSIndexSet (RangeAtIndexTest)
- (NSRange)rangeAtIndex:(NSUInteger)idx;
@end

static int failures;

static void expect(BOOL ok, const char* what)
{
	printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
	if (!ok)
		failures++;
}

static BOOL raisesInvalidArgument(NSIndexSet* set, NSUInteger idx)
{
	@try {
		[set rangeAtIndex:idx];
	} @catch (NSException* e) {
		return [[e name] isEqualToString:NSInvalidArgumentException];
	}
	return NO;
}

int main(void)
{
	@autoreleasepool {
		NSIndexSet* empty = [NSIndexSet indexSet];
		NSIndexSet* single = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(5, 3)];
		// Built from the highest range down: adding ranges in ascending order leaves NSMutableIndexSet's
		// internal range list out of order (a separate, existing problem).
		NSMutableIndexSet* multi = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(100, 1)];
		[multi addIndexesInRange:NSMakeRange(10, 4)];
		[multi addIndexesInRange:NSMakeRange(1, 2)];

		NSRange r = [single rangeAtIndex:0];
		expect(r.location == 5 && r.length == 3, "single-range set, index 0");
		r = [multi rangeAtIndex:0];
		expect(r.location == 1 && r.length == 2, "multi-range set, index 0");
		r = [multi rangeAtIndex:1];
		expect(r.location == 10 && r.length == 4, "multi-range set, index 1");
		r = [multi rangeAtIndex:2];
		expect(r.location == 100 && r.length == 1, "multi-range set, index 2");

		expect(raisesInvalidArgument(empty, 0), "test_quirk_range_at_index_out_of_bounds_raises: empty set");
		expect(raisesInvalidArgument(single, 1), "test_quirk_range_at_index_out_of_bounds_raises: single-range set");
		expect(raisesInvalidArgument(multi, NSNotFound), "test_quirk_range_at_index_out_of_bounds_raises: NSNotFound");

	}
	printf("%d failure(s)\n", failures);
	return failures != 0;
}
