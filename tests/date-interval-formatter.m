/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSDateIntervalFormatter formats both ends of an interval with the configured
 * style, in the configured locale and time zone; nil dates give nil.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

int main(void)
{
	@autoreleasepool {
		NSDateIntervalFormatter *f = [[NSDateIntervalFormatter alloc] init];
		f.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
		// Not set through -setTimeZone: here: copying an NSTimeZone is not implemented in CoreFoundation yet.
		setenv("TZ", "UTC", 1);
		[NSTimeZone resetSystemTimeZone];
		f.dateStyle = NSDateIntervalFormatterMediumStyle;
		f.timeStyle = NSDateIntervalFormatterNoStyle;

		NSDate *a = [NSDate dateWithTimeIntervalSince1970:1700000000]; /* 2023-11-14 22:13:20 UTC */
		NSDate *b = [NSDate dateWithTimeIntervalSince1970:1700000000 + 3 * 86400];

		NSString *s = [f stringFromDate:a toDate:b];
		CHECK(s != nil);
		CHECK([s containsString:@"14"]);
		CHECK([s containsString:@"17"]);
		CHECK([s containsString:@"2023"]);

		NSString *viaInterval = [f stringFromDateInterval:[[NSDateInterval alloc] initWithStartDate:a endDate:b]];
		CHECK([viaInterval isEqualToString:s]);

		f.dateStyle = NSDateIntervalFormatterNoStyle;
		f.timeStyle = NSDateIntervalFormatterShortStyle;
		NSString *t = [f stringFromDate:a toDate:b];
		CHECK(t != nil);
		CHECK([t containsString:@"10:13"]);

		CHECK([f.locale.localeIdentifier isEqualToString:@"en_US"]);
		CHECK([f.timeZone secondsFromGMT] == 0);
	}
	if (failures == 0)
		printf("PASS: NSDateIntervalFormatter formats both ends\n");
	return failures != 0;
}
