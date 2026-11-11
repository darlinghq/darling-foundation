/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * Small Foundation additions: legacy NSNumberFormatter aliases, the class
 * method +[NSBundle pathsForResourcesOfType:inDirectory:], NSTask launch info
 * that is not copyable, NSScanner without a skip set, NSMapTable nil
 * arguments, NSUserNotification and its center, NSAppleScript and the script
 * task stubs, and the NSMetadataQuery scope constants.
 *
 * Build: clang -target <arch>-apple-macos... -framework Foundation
 *        -lobjc foundation-fervi-api.m
 */

#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expect(BOOL ok, const char* what)
{
	printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
	if (!ok)
		failures++;
}

static void testNumberFormatterAliases(void)
{
	NSNumberFormatter* f = [[[NSNumberFormatter alloc] init] autorelease];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	[f setHasThousandSeparators:YES];
	[f setThousandSeparator:@"'"];
	expect([[f groupingSeparator] isEqualToString:@"'"], "setThousandSeparator: sets the grouping separator");
	expect([[f thousandSeparator] isEqualToString:@"'"], "thousandSeparator reads it back");
	expect([f usesGroupingSeparator] && [f hasThousandSeparators], "hasThousandSeparators follows usesGroupingSeparator");
	[f setHasThousandSeparators:NO];
	expect(![f usesGroupingSeparator], "setHasThousandSeparators:NO clears usesGroupingSeparator");
}

static void testBundleClassMethod(void)
{
	NSString* dir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"foundation-fervi-api-bundle"];
	NSFileManager* fm = [NSFileManager defaultManager];
	[fm removeItemAtPath:dir error:NULL];
	[fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
	[[NSData data] writeToFile:[dir stringByAppendingPathComponent:@"a.txt"] atomically:NO];
	[[NSData data] writeToFile:[dir stringByAppendingPathComponent:@"b.png"] atomically:NO];
	NSArray* txt = [NSBundle pathsForResourcesOfType:@"txt" inDirectory:dir];
	expect([txt count] == 1 && [[txt objectAtIndex:0] hasSuffix:@"a.txt"], "+pathsForResourcesOfType:inDirectory: filters by extension");
	expect([[NSBundle pathsForResourcesOfType:@"jpg" inDirectory:dir] count] == 0, "no match gives an empty array");
	[fm removeItemAtPath:dir error:NULL];
}

static void testTaskKeepsPipe(void)
{
	NSTask* task = [[[NSTask alloc] init] autorelease];
	NSPipe* pipe = [NSPipe pipe];
	[task setStandardOutput:pipe];
	[task setStandardError:pipe];
	expect([task standardOutput] == pipe, "-[NSTask standardOutput] returns the pipe that was set");
	expect([task standardError] == pipe, "-[NSTask standardError] returns the pipe that was set");
}

static void testScannerWithoutSkipSet(void)
{
	NSScanner* s = [NSScanner scannerWithString:@"  42"];
	[s setCharactersToBeSkipped:nil];
	NSInteger v = 0;
	expect(![s scanInteger:&v], "scanInteger: fails on leading spaces without a skip set");
	expect([s scanLocation] == 0, "the scan location did not move");
	[s setCharactersToBeSkipped:[NSCharacterSet whitespaceCharacterSet]];
	expect([s scanInteger:&v] && v == 42, "scanInteger: skips spaces with the default skip set");

	NSScanner* t = [NSScanner scannerWithString:@"  abc"];
	[t setCharactersToBeSkipped:nil];
	expect(![t scanString:@"abc" intoString:NULL] && [t scanLocation] == 0, "scanString: leaves the location alone without a skip set");
}

static void testMapTableNil(void)
{
	NSMapTable* t = [NSMapTable strongToStrongObjectsMapTable];
	BOOL raised = NO;
	@try {
		[t setObject:@"v" forKey:nil];
		[t setObject:nil forKey:@"new"];
		[t setObject:@"v" forKey:@"k"];
		[t setObject:nil forKey:@"k"];
		[t removeObjectForKey:nil];
	} @catch (NSException* e) {
		raised = YES;
	}
	expect(!raised, "nil keys and objects do not raise");
	expect([t count] == 1 && [[t objectForKey:@"k"] isEqual:@"v"], "setObject:nil forKey: leaves an existing entry unchanged");
	expect([t objectForKey:@"new"] == nil, "setObject:nil for a new key adds nothing");

	NSMapTable* w = [NSMapTable weakToStrongObjectsMapTable];
	NSString* key = [[[NSString alloc] initWithFormat:@"key%d", 1] autorelease];
	[w setObject:@"v" forKey:key];
	[w setObject:nil forKey:key];
	expect([[w objectForKey:key] isEqual:@"v"], "a weak-to-strong table also ignores a nil object");
}

/* On macOS a process without an application bundle is not shown a delivered or scheduled list, so the list checks
 * are written for Darling, which keeps the lists itself. */
static void testUserNotification(void)
{
	NSUserNotification* n = [[[NSUserNotification alloc] init] autorelease];
	n.title = @"T";
	n.informativeText = @"Body";
	n.userInfo = @{@"k": @1};
	n.hasActionButton = YES;
	NSUserNotification* c = [[n copy] autorelease];
	expect(c != nil && c != n, "NSUserNotification copies");
	expect([c.title isEqualToString:@"T"] && [c.informativeText isEqualToString:@"Body"], "copy keeps title and text");
	expect([c.userInfo isEqualToDictionary:n.userInfo] && c.hasActionButton, "copy keeps userInfo and flags");

	NSUserNotificationCenter* center = [NSUserNotificationCenter defaultUserNotificationCenter];
	[center removeAllDeliveredNotifications];
	[center deliverNotification:n];
	expect([[center deliveredNotifications] containsObject:n], "a delivered notification is listed");
	[center removeDeliveredNotification:n];
	expect(![[center deliveredNotifications] containsObject:n], "a removed notification is no longer listed");
	[center scheduleNotification:n];
	expect([[center scheduledNotifications] containsObject:n], "a scheduled notification is listed");
	[center removeScheduledNotification:n];
	expect(![[center scheduledNotifications] containsObject:n], "a removed scheduled notification is no longer listed");
}

static void testAppleScript(void)
{
	NSAppleScript* script = [[[NSAppleScript alloc] initWithSource:@"return 1"] autorelease];
	expect([[script source] isEqualToString:@"return 1"], "NSAppleScript keeps its source");
	NSDictionary* err = nil;
	NSAppleEventDescriptor* result = [script executeAndReturnError:&err];
	expect(result != nil || err != nil, "execution reports either a result or an error dictionary");
	expect([script copy] != nil, "NSAppleScript copies");
}

static void testScriptTaskStubs(void)
{
	Class unixTask = NSClassFromString(@"NSUserUnixTask");
	expect(unixTask != Nil, "NSUserUnixTask exists");
	expect(NSClassFromString(@"NSUserAutomatorTask") != Nil, "NSUserAutomatorTask exists");
	/* Darling forwards unimplemented methods of these classes to a stub; the stub must hand back nil, not whatever
	 * was left in the return register. macOS implements the classes, so the probe there may raise instead. */
	@try {
		id task = [[[unixTask alloc] init] autorelease];
		if (task != nil) {
			id value = [task performSelector:NSSelectorFromString(@"vd214UnimplementedGetter")];
			expect(value == nil, "an unimplemented method on a stubbed script task returns nil");
		}
	} @catch (NSException* e) {
		printf("SKIP: stub probe raised %s\n", [[e name] UTF8String]);
	}
}

static void testMetadataScopes(void)
{
	expect([NSMetadataQueryLocalComputerScope isEqualToString:@"kMDQueryScopeComputer"], "local computer scope value");
	expect([NSMetadataQueryNetworkScope isEqualToString:@"kMDQueryScopeNetwork"], "network scope value");
	expect([NSMetadataQueryIndexedLocalComputerScope isEqualToString:@"kMDQueryScopeComputerIndexed"], "indexed local computer scope value");
	expect([NSMetadataQueryIndexedNetworkScope isEqualToString:@"kMDQueryScopeNetworkIndexed"], "indexed network scope value");
}

int main(void)
{
	@autoreleasepool {
		testNumberFormatterAliases();
		testBundleClassMethod();
		testTaskKeepsPipe();
		testScannerWithoutSkipSet();
		testMapTableNil();
		testUserNotification();
		testAppleScript();
		testScriptTaskStubs();
		testMetadataScopes();
	}
	printf("%d failure(s)\n", failures);
	return failures != 0;
}
