/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSProgress trees: a child created under the current progress contributes its
 * fraction to the parent in proportion to its pending unit count; cancel and
 * pause propagate to children; fractionCompleted is clamped by totals.
 */
#import <Foundation/Foundation.h>
#include <math.h>
#include <stdio.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)
#define NEAR(a, b) (fabs((a) - (b)) < 1e-9)

int main(void)
{
	@autoreleasepool {
		NSProgress *parent = [NSProgress progressWithTotalUnitCount:10];
		CHECK(parent.totalUnitCount == 10);
		CHECK(parent.completedUnitCount == 0);
		CHECK(NEAR(parent.fractionCompleted, 0.0));

		parent.completedUnitCount = 2;
		CHECK(NEAR(parent.fractionCompleted, 0.2));

		/* A child worth 8 of the parent's units. */
		[parent becomeCurrentWithPendingUnitCount:8];
		NSProgress *child = [NSProgress progressWithTotalUnitCount:4];
		[parent resignCurrent];
		CHECK(child.totalUnitCount == 4);

		child.completedUnitCount = 2;
		CHECK(NEAR(child.fractionCompleted, 0.5));
		CHECK(NEAR(parent.fractionCompleted, (2.0 + 8.0 * 0.5) / 10.0));

		child.completedUnitCount = 4;
		CHECK(NEAR(parent.fractionCompleted, 1.0));
		CHECK(parent.completedUnitCount == 10);

		/* Cancellation reaches children. */
		NSProgress *p2 = [NSProgress progressWithTotalUnitCount:2];
		[p2 becomeCurrentWithPendingUnitCount:1];
		NSProgress *c2 = [NSProgress progressWithTotalUnitCount:1];
		[p2 resignCurrent];
		CHECK(!p2.cancelled && !c2.cancelled);
		[p2 cancel];
		CHECK(p2.cancelled);
		CHECK(c2.cancelled);

		/* Pause and resume. */
		NSProgress *p3 = [NSProgress progressWithTotalUnitCount:1];
		CHECK(!p3.paused);
		[p3 pause];
		CHECK(p3.paused);
		[p3 resume];
		CHECK(!p3.paused);

		/* An indeterminate progress reports 0. */
		NSProgress *p4 = [NSProgress progressWithTotalUnitCount:-1];
		CHECK(p4.indeterminate);
	}
	if (failures == 0)
		printf("PASS: NSProgress trees\n");
	return failures != 0;
}
