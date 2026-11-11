/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSUserActivity: initialisation, property storage, userInfo merging,
 * needsSave delivering a coalesced -userActivityWillSave: on the main queue
 * for the current activity, and the continuation streams error.
 *
 * Build: clang -target <arch>-apple-macos... -framework Foundation
 *        -lobjc nsuseractivity.m
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

@interface SaveCounter : NSObject <NSUserActivityDelegate>
@property (nonatomic, assign) int saves;
@end

@implementation SaveCounter
- (void)userActivityWillSave:(NSUserActivity*)activity
{
	self.saves++;
	[activity addUserInfoEntriesFromDictionary:@{@"saved": @YES}];
}
@end

static void spinMainQueue(void)
{
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
}

int main(void)
{
	@autoreleasepool {
		NSUserActivity* a = [[NSUserActivity alloc] initWithActivityType:@"org.example.view"];
		expect([a.activityType isEqualToString:@"org.example.view"], "activityType is stored");
		expect(a.keywords != nil && a.keywords.count == 0, "keywords default to an empty set");
		expect(a.title == nil && a.userInfo == nil && a.webpageURL == nil, "optional properties default to nil");

		a.title = @"T";
		a.userInfo = @{@"a": @1};
		[a addUserInfoEntriesFromDictionary:@{@"b": @2}];
		expect([a.title isEqualToString:@"T"], "title round trips");
		expect([a.userInfo isEqualToDictionary:(@{@"a": @1, @"b": @2})], "addUserInfoEntriesFromDictionary: merges");

		SaveCounter* counter = [[SaveCounter alloc] init];
		a.delegate = counter;
		[a becomeCurrent];
		a.needsSave = YES;
		a.needsSave = YES;
		spinMainQueue();
		expect(counter.saves == 1, "needsSave on the current activity saves once (coalesced)");
		expect(!a.needsSave, "needsSave is cleared after the save");
		expect([a.userInfo[@"saved"] boolValue], "delegate may update userInfo in userActivityWillSave:");

		[a invalidate];
		a.needsSave = YES;
		spinMainQueue();
		expect(counter.saves == 1, "an invalidated activity is not saved");

		NSUserActivity* b = [[NSUserActivity alloc] initWithActivityType:@"org.example.stream"];
		__block NSError* error = nil;
		__block BOOL called = NO;
		[b getContinuationStreamsWithCompletionHandler:^(NSInputStream* in, NSOutputStream* out, NSError* err) {
			called = YES;
			error = [err retain];
		}];
		expect(called && error != nil && [error.domain isEqualToString:NSCocoaErrorDomain], "continuation streams report an error");
	}
	printf("%s\n", failures ? "FAILED" : "ALL PASSED");
	return failures ? 1 : 0;
}
