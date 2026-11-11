/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSPersonNameComponents: properties, copy, equality, secure coding and the
 * keyed archive layout (root with NS.nameComponentsPrivate pointing to a
 * _NSPersonNameComponentsData object), plus the description format. Expected
 * values come from macOS 27.
 *
 * Build: clang -target <arch>-apple-macos... -framework Foundation
 *        -lobjc nspersonnamecomponents.m
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

static NSPersonNameComponents* makeName(void)
{
	NSPersonNameComponents* pn = [[[NSPersonNameComponents alloc] init] autorelease];
	pn.namePrefix = @"Dr.";
	pn.givenName = @"Ada";
	pn.middleName = @"M";
	pn.familyName = @"Lovelace";
	pn.nameSuffix = @"Jr.";
	pn.nickname = @"A";
	NSPersonNameComponents* ph = [[[NSPersonNameComponents alloc] init] autorelease];
	ph.givenName = @"Ei-da";
	pn.phoneticRepresentation = ph;
	return pn;
}

int main(void)
{
	@autoreleasepool {
		NSPersonNameComponents* pn = makeName();

		NSPersonNameComponents* c = [[pn copy] autorelease];
		expect(c != pn && [c isEqual:pn] && [c hash] == [pn hash], "copy is distinct, equal and has the same hash");
		c.nickname = @"B";
		expect(![c isEqual:pn], "a changed nickname makes the copies unequal");
		expect([[[[NSPersonNameComponents alloc] init] autorelease] isEqual:[[[NSPersonNameComponents alloc] init] autorelease]], "two empty components are equal");
		expect([NSPersonNameComponents supportsSecureCoding], "supports secure coding");

		NSError* error = nil;
		NSData* data = [NSKeyedArchiver archivedDataWithRootObject:pn requiringSecureCoding:YES error:&error];
		expect(data != nil, "archives with secure coding");

		NSPersonNameComponents* rt = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSPersonNameComponents class] fromData:data error:&error];
		expect(rt != nil && [rt isEqual:pn], "round trip is equal");
		expect([rt.phoneticRepresentation.givenName isEqualToString:@"Ei-da"], "round trip keeps the phonetic representation");
		expect([rt.familyName isEqualToString:@"Lovelace"] && [rt.namePrefix isEqualToString:@"Dr."], "round trip keeps the names");

		/* test_quirk_archive_layout */
		NSDictionary* plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:&error];
		NSArray* objects = [plist objectForKey:@"$objects"];
		id rootUID = [[plist objectForKey:@"$top"] objectForKey:@"root"];
		NSDictionary* root = nil;
		if (rootUID != nil && objects != nil) {
			/* The UID is opaque here; find the root as the object that has NS.nameComponentsPrivate and is first. */
			for (id o in objects) {
				if ([o isKindOfClass:[NSDictionary class]] && [o objectForKey:@"NS.nameComponentsPrivate"] != nil) {
					root = o;
					break;
				}
			}
		}
		expect(root != nil, "test_quirk_archive_layout: the root has NS.nameComponentsPrivate");
		expect([root count] == 2, "test_quirk_archive_layout: the root has only $class and NS.nameComponentsPrivate");
		BOOL holderFound = NO;
		for (id o in objects) {
			if ([o isKindOfClass:[NSDictionary class]] && [o objectForKey:@"NS.familyName"] != nil && [o objectForKey:@"NS.phoneticRepresentation"] != nil) {
				holderFound = [o count] == 8; /* $class plus seven keys, nil values included */
				break;
			}
		}
		expect(holderFound, "test_quirk_archive_layout: the holder object has all seven NS.* keys");
		BOOL holderClassFound = NO;
		for (id o in objects) {
			if ([o isKindOfClass:[NSDictionary class]] && [[o objectForKey:@"$classname"] isEqual:@"_NSPersonNameComponentsData"])
				holderClassFound = YES;
		}
		expect(holderClassFound, "test_quirk_archive_layout: the holder class is _NSPersonNameComponentsData");

		/* test_quirk_description_format */
		NSString* d = [pn description];
		NSRange brace = [d rangeOfString:@"> {"];
		expect(brace.location != NSNotFound
			&& [[d substringFromIndex:brace.location + 2] hasPrefix:@"{givenName = Ada, familyName = Lovelace, middleName = M, namePrefix = Dr., nameSuffix = Jr., nickname = A phoneticRepresentation = <NSPersonNameComponents: "],
			"test_quirk_description_format: description layout");
	}
	printf("%d failure(s)\n", failures);
	return failures != 0;
}
