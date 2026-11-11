/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSUnarchiver decodeValueOfObjCType:at: and struct tags in the type string.
 * test_quirk_struct_tag_anonymous_matches_named: the anonymous tag "?" is
 * compatible with a named tag on either side. Two different names are not.
 * Expected values come from macOS 27.
 *
 * Build: clang -target <arch>-apple-macos... -framework Foundation
 *        -lobjc unarchiver-struct-tags.m
 */

#import <Foundation/Foundation.h>
#include <stdio.h>

typedef struct { double a; double b; } Pair;

static int failures;

static void expectDecode(const char* encoded, const char* requested, BOOL shouldDecode, const char* what)
{
	BOOL decoded = NO;
	Pair q = {0, 0};
	@try {
		NSArchiver* a = [[[NSArchiver alloc] initForWritingWithMutableData:[NSMutableData data]] autorelease];
		Pair p = {1.5, 2.5};
		[a encodeValueOfObjCType:encoded at:&p];
		NSUnarchiver* u = [[[NSUnarchiver alloc] initForReadingWithData:[a archiverData]] autorelease];
		[u decodeValueOfObjCType:requested at:&q];
		decoded = YES;
	} @catch (NSException* e) {
	}
	BOOL ok = decoded == shouldDecode && (!decoded || (q.a == 1.5 && q.b == 2.5));
	printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
	if (!ok)
		failures++;
}

int main(void)
{
	@autoreleasepool {
		expectDecode("{Foo=dd}", "{Foo=dd}", YES, "same tag");
		expectDecode("{Foo=dd}", "{?=dd}", YES, "named archive, anonymous request (test_quirk_struct_tag_anonymous_matches_named)");
		expectDecode("{?=dd}", "{Foo=dd}", YES, "anonymous archive, named request (test_quirk_struct_tag_anonymous_matches_named)");
		expectDecode("{Foo={In=d}d}", "{?={?=d}d}", YES, "nested tags");
		expectDecode("{Foo=dd}", "{Bar=dd}", NO, "different tags do not match");
		expectDecode("{Foo=dd}", "{foo=dd}", NO, "tags are case sensitive");
		expectDecode("{Foo=dd}", "{Foo=dq}", NO, "member types must match");
		expectDecode("{Foo=dd}", "{Foo=ddd}", NO, "member count must match");
		{
			char longTag[600];
			memset(longTag, 'x', sizeof(longTag));
			longTag[sizeof(longTag) - 1] = 0;
			char enc1[700], enc2[700];
			snprintf(enc1, sizeof(enc1), "{%s=dd}", longTag);
			snprintf(enc2, sizeof(enc2), "{%sy=dd}", longTag);
			expectDecode(enc1, enc1, YES, "a tag longer than 256 bytes matches itself");
			expectDecode(enc1, enc2, NO, "tags that differ after 256 bytes do not match");
		}
	}
	printf("%d failure(s)\n", failures);
	return failures != 0;
}
