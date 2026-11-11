/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSAppleEventDescriptor stores values in AE descriptors and reads them back:
 * integers, strings, booleans, type codes, raw data, lists and records,
 * and copies are independent of the original. NSScriptCoercionHandler has a
 * shared instance that returns a value unchanged when it already is of the
 * target class.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

int main(void)
{
	@autoreleasepool {
		NSAppleEventDescriptor *i = [NSAppleEventDescriptor descriptorWithInt32:-1234567];
		CHECK(i != nil);
		CHECK([i descriptorType] == typeSInt32);
		CHECK([i int32Value] == -1234567);

		NSAppleEventDescriptor *s = [NSAppleEventDescriptor descriptorWithString:@"héllo 世界"];
		CHECK(s != nil);
		CHECK([s descriptorType] == typeUnicodeText);
		CHECK([[s stringValue] isEqualToString:@"héllo 世界"]);

		NSAppleEventDescriptor *b = [NSAppleEventDescriptor descriptorWithBoolean:true];
		CHECK([b booleanValue]);
		NSAppleEventDescriptor *t = [NSAppleEventDescriptor descriptorWithTypeCode:'abcd'];
		CHECK([t typeCodeValue] == 'abcd');
		NSAppleEventDescriptor *e = [NSAppleEventDescriptor descriptorWithEnumCode:'wxyz'];
		CHECK([e enumCodeValue] == 'wxyz');

		const char raw[] = { 1, 2, 3, 4, 5 };
		NSAppleEventDescriptor *d = [NSAppleEventDescriptor descriptorWithDescriptorType:'blob' bytes:raw length:sizeof(raw)];
		CHECK([d descriptorType] == 'blob');
		CHECK([[d data] length] == sizeof(raw));
		CHECK(memcmp([[d data] bytes], raw, sizeof(raw)) == 0);

		// A list holds descriptors by one-based index.
		NSAppleEventDescriptor *list = [NSAppleEventDescriptor listDescriptor];
		CHECK([list descriptorType] == typeAEList);
		CHECK([list numberOfItems] == 0);
		[list insertDescriptor:i atIndex:1];
		[list insertDescriptor:s atIndex:2];
		[list insertDescriptor:b atIndex:3];
		CHECK([list numberOfItems] == 3);
		CHECK([[list descriptorAtIndex:1] int32Value] == -1234567);
		CHECK([[[list descriptorAtIndex:2] stringValue] isEqualToString:@"héllo 世界"]);
		CHECK([[list descriptorAtIndex:3] booleanValue]);
		CHECK([list descriptorAtIndex:4] == nil);
		[list removeDescriptorAtIndex:2];
		CHECK([list numberOfItems] == 2);
		CHECK([[list descriptorAtIndex:2] booleanValue]);

		// A record holds descriptors by keyword.
		NSAppleEventDescriptor *record = [NSAppleEventDescriptor recordDescriptor];
		CHECK([record descriptorType] == typeAERecord);
		[record setDescriptor:i forKeyword:'key1'];
		[record setDescriptor:s forKeyword:'key2'];
		CHECK([record numberOfItems] == 2);
		CHECK([[record descriptorForKeyword:'key1'] int32Value] == -1234567);
		CHECK([[[record descriptorForKeyword:'key2'] stringValue] isEqualToString:@"héllo 世界"]);
		CHECK([record descriptorForKeyword:'none'] == nil);
		[record removeDescriptorWithKeyword:'key1'];
		CHECK([record numberOfItems] == 1);
		CHECK([record descriptorForKeyword:'key1'] == nil);

		// Copies do not share storage.
		NSAppleEventDescriptor *copy = [[list copy] autorelease];
		CHECK([copy numberOfItems] == 2);
		[list removeDescriptorAtIndex:1];
		CHECK([list numberOfItems] == 1);
		CHECK([copy numberOfItems] == 2);

		// Coercion between numeric and text types.
		NSAppleEventDescriptor *asText = [i coerceToDescriptorType:typeUnicodeText];
		CHECK(asText != nil);
		CHECK([[asText stringValue] isEqualToString:@"-1234567"]);

		NSScriptCoercionHandler *handler = [NSScriptCoercionHandler sharedCoercionHandler];
		CHECK(handler != nil);
		CHECK(handler == [NSScriptCoercionHandler sharedCoercionHandler]);
		NSString *str = @"unchanged";
		CHECK([handler coerceValue:str toClass:[NSString class]] == str);
	}
	if (failures == 0)
		printf("PASS\n");
	return failures != 0;
}
