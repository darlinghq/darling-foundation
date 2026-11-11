/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSProcessInfo activities: begin returns a token, end and the perform
 * variants run the block exactly once, the option constants have their
 * documented values, and the power-state notification name is exported.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

int main(void)
{
	@autoreleasepool {
		NSProcessInfo *info = [NSProcessInfo processInfo];

		id token = [info beginActivityWithOptions:NSActivityUserInitiated reason:@"test"];
		CHECK(token != nil);
		[info endActivity:token];

		__block int ran = 0;
		[info performActivityWithOptions:NSActivityBackground reason:@"test" usingBlock:^{ ran++; }];
		CHECK(ran == 1);

		__block BOOL expired = YES;
		[info performExpiringActivityWithReason:@"test" usingBlock:^(BOOL e) { expired = e; }];
		CHECK(!expired);

		CHECK(NSActivityIdleDisplaySleepDisabled == (1ULL << 40));
		CHECK(NSActivityIdleSystemSleepDisabled == (1ULL << 20));
		CHECK(NSActivitySuddenTerminationDisabled == (1ULL << 14));
		CHECK(NSActivityAutomaticTerminationDisabled == (1ULL << 15));
		CHECK(NSActivityUserInitiated == (0x00FFFFFFULL | NSActivityIdleSystemSleepDisabled));
		CHECK(NSActivityBackground == 0xFFULL);
		CHECK(NSActivityLatencyCritical == 0xFF00000000ULL);

		CHECK([NSProcessInfoPowerStateDidChangeNotification length] > 0);

		[info disableSuddenTermination];
		[info enableSuddenTermination];
		[info disableAutomaticTermination:@"test"];
		[info enableAutomaticTermination:@"test"];
		info.automaticTerminationSupportEnabled = YES;
		CHECK(info.automaticTerminationSupportEnabled);
		info.automaticTerminationSupportEnabled = NO;
		CHECK(!info.automaticTerminationSupportEnabled);
	}
	if (failures == 0)
		printf("PASS: NSProcessInfo activities and termination calls\n");
	return failures != 0;
}
