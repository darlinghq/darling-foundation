/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// NSCoder top-level decoding with an error (decodeTopLevelObjectForKey:error: and the class
// variants) and the collection decoders (decodeArrayOfObjectsOfClass:forKey:,
// decodeDictionaryWithKeysOfClass:objectsOfClass:forKey:), with secure keyed archives.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

static NSKeyedUnarchiver *reader(id root)
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject: root requiringSecureCoding: YES error: NULL];
    NSKeyedUnarchiver *u = [[[NSKeyedUnarchiver alloc] initForReadingFromData: data error: NULL] autorelease];
    [u setRequiresSecureCoding: YES];
    return u;
}

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSArray *strings = [NSArray arrayWithObjects: @"a", @"b", nil];
        NSError *error = nil;

    NSDate *date = [NSDate dateWithTimeIntervalSince1970: 0];
    NSArray *dates = [NSArray arrayWithObject: date];
    NSDictionary *dateMap = [NSDictionary dictionaryWithObject: date forKey: @"k"];

    id result = [reader(strings) decodeTopLevelObjectOfClasses: [NSSet setWithObjects: [NSArray class], [NSString class], nil] forKey: NSKeyedArchiveRootObjectKey error: &error];
    expect([result isEqual: strings] && error == nil, @"decodeTopLevelObjectOfClasses: returns the object without an error");
    error = nil;
    result = [reader(@"text") decodeTopLevelObjectOfClass: [NSString class] forKey: NSKeyedArchiveRootObjectKey error: &error];
    expect([result isEqual: @"text"] && error == nil, @"decodeTopLevelObjectOfClass: returns the object");
    error = nil;
    result = [reader(date) decodeTopLevelObjectOfClass: [NSNumber class] forKey: NSKeyedArchiveRootObjectKey error: &error];
    expect(result == nil && error != nil && [[error domain] isEqualToString: NSCocoaErrorDomain] && [error code] == NSCoderReadCorruptError, @"a disallowed class gives nil and NSCoderReadCorruptError");
    result = [reader(date) decodeTopLevelObjectOfClass: [NSNumber class] forKey: NSKeyedArchiveRootObjectKey error: NULL];
    expect(result == nil, @"a NULL error pointer is accepted");
    error = nil;
    result = [reader(strings) decodeTopLevelObjectForKey: NSKeyedArchiveRootObjectKey error: &error];
    expect(result == nil && [error code] == NSCoderReadCorruptError, @"the unrestricted variant under secure coding refuses the object");
    error = nil;
    result = [reader(strings) decodeTopLevelObjectOfClass: [NSArray class] forKey: @"nokey" error: &error];
    expect(result == nil && [[error domain] isEqualToString: NSCocoaErrorDomain] && [error code] == NSCoderValueNotFoundError, @"a missing key gives NSCoderValueNotFoundError");

    NSArray *decoded = [reader(strings) decodeArrayOfObjectsOfClass: [NSString class] forKey: NSKeyedArchiveRootObjectKey];
    expect([decoded isEqual: strings], @"decodeArrayOfObjectsOfClass: decodes an array of the class");
    decoded = [reader(dates) decodeArrayOfObjectsOfClass: [NSString class] forKey: NSKeyedArchiveRootObjectKey];
    expect(decoded == nil, @"elements of another class are not decoded");
    decoded = [reader(dates) decodeArrayOfObjectsOfClasses: [NSSet setWithObjects: [NSString class], [NSDate class], nil] forKey: NSKeyedArchiveRootObjectKey];
    expect([decoded isEqual: dates], @"decodeArrayOfObjectsOfClasses:");

    NSDictionary *dictionary = [reader(dateMap) decodeDictionaryWithKeysOfClass: [NSString class] objectsOfClass: [NSDate class] forKey: NSKeyedArchiveRootObjectKey];
    expect([dictionary isEqual: dateMap], @"decodeDictionaryWithKeysOfClass:objectsOfClass:");
    dictionary = [reader(dateMap) decodeDictionaryWithKeysOfClass: [NSString class] objectsOfClass: [NSString class] forKey: NSKeyedArchiveRootObjectKey];
    expect(dictionary == nil, @"values of another class are not decoded");
    dictionary = [reader(strings) decodeDictionaryWithKeysOfClass: [NSString class] objectsOfClass: [NSString class] forKey: NSKeyedArchiveRootObjectKey];
    expect(dictionary == nil, @"an array is not allowed when decoding a dictionary");
    dictionary = [reader(dateMap) decodeDictionaryWithKeysOfClasses: [NSSet setWithObject: [NSString class]] objectsOfClasses: [NSSet setWithObject: [NSDate class]] forKey: NSKeyedArchiveRootObjectKey];
    expect([dictionary isEqual: dateMap], @"decodeDictionaryWithKeysOfClasses:objectsOfClasses:");

    [pool drain];
    return failures ? 1 : 0;
}
