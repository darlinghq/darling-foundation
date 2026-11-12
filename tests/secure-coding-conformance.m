// Copyright (C) 2026 Lubos Dolezel
//
// NSSecureCoding for the Foundation classes that macOS marks as secure coding:
// +supportsSecureCoding, a secure NSKeyedArchiver round trip, and refusal of
// archives whose stored values have the wrong class when the unarchiver
// requires secure coding. Expected values were observed on macOS 27 (the same
// file builds and passes there).
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

// Archives with arbitrary stored fields under a chosen class name, so that
// malformed archives of Foundation classes can be produced.
@interface Spoof : NSObject <NSSecureCoding> {
@public
    NSDictionary *ints;
    NSDictionary *objects;
}
@end
@implementation Spoof
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {
    for (NSString *key in ints) [coder encodeInt64:[ints[key] longLongValue] forKey:key];
    for (NSString *key in objects) [coder encodeObject:objects[key] forKey:key];
}
- (id)initWithCoder:(NSCoder *)coder { return nil; }
@end

static NSData *spoofArchive(NSString *className, NSDictionary *ints, NSDictionary *objects) {
    Spoof *spoof = [[Spoof alloc] init];
    spoof->ints = ints;
    spoof->objects = objects;
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
    [archiver setClassName:className forClass:[Spoof class]];
    [archiver encodeObject:spoof forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    NSData *data = [[[archiver encodedData] retain] autorelease]; // the archiver owns its data
    [archiver release];
    [spoof release];
    return data;
}

static id secureDecode(Class cls, NSData *data, NSError **error) {
    id result = nil;
    @try {
        result = [NSKeyedUnarchiver unarchivedObjectOfClass:cls fromData:data error:error];
    } @catch (NSException *exception) {
        result = nil;
    }
    return result;
}

static void expectRefused(NSString *label, Class cls, NSString *className, NSDictionary *ints, NSDictionary *objects) {
    NSError *error = nil;
    id decoded = secureDecode(cls, spoofArchive(className, ints, objects), &error);
    if (decoded != nil) {
        printf("FAIL: %s decoded despite a stored value of the wrong class\n", label.UTF8String);
        failures++;
    }
}

static id roundTrip(NSString *label, id object, Class publicClass) {
    CHECK([publicClass supportsSecureCoding]);
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error];
    if (data == nil) {
        printf("FAIL: %s does not archive with secure coding: %s\n", label.UTF8String, [[error description] UTF8String]);
        failures++;
        return nil;
    }
    id back = secureDecode(publicClass, data, &error);
    if (back == nil) {
        printf("FAIL: %s does not decode with secure coding: %s\n", label.UTF8String, [[error description] UTF8String]);
        failures++;
        return nil;
    }
    CHECK([back isKindOfClass:publicClass]);

    // Asking for an unrelated class must fail.
    Class other = publicClass == [NSURL class] ? [NSData class] : [NSURL class];
    error = nil;
    if (secureDecode(other, data, &error) != nil) {
        printf("FAIL: %s decoded as the wrong class\n", label.UTF8String);
        failures++;
    }
    CHECK(error != nil);

    // Without the opt-in the archiver and unarchiver are unchanged.
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [archiver encodeObject:object forKey:NSKeyedArchiveRootObjectKey];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:[archiver encodedData] error:NULL];
    [unarchiver setRequiresSecureCoding:NO];
    id plain = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    CHECK([plain isKindOfClass:publicClass]);
    [unarchiver finishDecoding];
    [unarchiver release];
    [archiver release];
    return back;
}

// Archive without letting an exception escape (some objects raise when archived).
static NSData *tryArchive(id object) {
    @try {
        return [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:NULL];
    } @catch (NSException *exception) {
        return nil;
    }
}

// The first archived object that has the given key: the dictionary of its fields.
static NSDictionary *objectWithKey(NSData *data, NSString *key) {
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    for (id object in plist[@"$objects"]) {
        if ([object isKindOfClass:[NSDictionary class]] && object[key] != nil && object[@"$class"] != nil) return object;
    }
    return nil;
}

// Whether the archive holds a string object "$null" besides the entry at index 0 that stands for nil.
static BOOL hasNullStringObject(NSData *archive) {
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:archive options:0 format:NULL error:NULL];
    NSArray *objects = plist[@"$objects"];
    return [objects count] > 1 && [objects indexOfObject:@"$null" inRange:NSMakeRange(1, [objects count] - 1)] != NSNotFound;
}

static NSArray *sortedKeys(NSDictionary *dictionary) {
    return [[dictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];
}

static BOOL keysAre(NSDictionary *dictionary, NSString *joined) {
    return dictionary != nil && [[sortedKeys(dictionary) componentsJoinedByString:@","] isEqual:joined];
}

static NSData *bytes(const uint8_t *p, size_t n) { return [NSData dataWithBytes:p length:n]; }

// Whether an archived data object holds the given bytes; the archiver stores NSData either as a plain
// property list data value or as an object with an NS.data field.
static BOOL archiveHasDataPrefix(NSData *archive, NSData *expected) {
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:archive options:0 format:NULL error:NULL];
    for (id object in plist[@"$objects"]) {
        NSData *data = [object isKindOfClass:[NSData class]] ? object : [object isKindOfClass:[NSDictionary class]] ? object[@"NS.data"] : nil;
        if ([data isKindOfClass:[NSData class]] && [data length] >= [expected length] && [[data subdataWithRange:NSMakeRange(0, [expected length])] isEqual:expected]) return YES;
    }
    return NO;
}

static BOOL archiveHasData(NSData *archive, NSData *expected) {
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:archive options:0 format:NULL error:NULL];
    for (id object in plist[@"$objects"]) {
        NSData *data = [object isKindOfClass:[NSData class]] ? object : [object isKindOfClass:[NSDictionary class]] ? object[@"NS.data"] : nil;
        if ([data isEqual:expected]) return YES;
    }
    return NO;
}


int main(void) {
    @autoreleasepool {
        // NSException
        {
            NSException *exception = [NSException exceptionWithName:@"Name" reason:@"Reason"
                userInfo:@{@"s": @"v", @"n": @3, @"a": @[@"x", @1], @"u": [NSURL URLWithString:@"http://example.com/"]}];
            NSException *back = roundTrip(@"NSException", exception, [NSException class]);
            CHECK([back.name isEqual:@"Name"] && [back.reason isEqual:@"Reason"]);
            CHECK([back.userInfo isEqual:exception.userInfo]);
            back = roundTrip(@"NSException without reason", [NSException exceptionWithName:@"N" reason:nil userInfo:nil], [NSException class]);
            CHECK([back.name isEqual:@"N"] && back.reason == nil && back.userInfo == nil);
            expectRefused(@"NSException reason", [NSException class], @"NSException", @{}, @{@"NS.name": @"N", @"NS.reason": @42});
            expectRefused(@"NSException userInfo", [NSException class], @"NSException", @{}, @{@"NS.name": @"N", @"NS.userinfo": @{@"k": [NSSet setWithObject:@1]}});
        }
        // NSIndexPath
        {
            NSUInteger values[] = {1, 300, 70000, 0};
            for (NSUInteger length = 0; length <= 4; length++) {
                NSIndexPath *path = [NSIndexPath indexPathWithIndexes:values length:length];
                NSIndexPath *back = roundTrip(@"NSIndexPath", path, [NSIndexPath class]);
                CHECK(back != nil && [back length] == length && [back isEqual:path]);
                for (NSUInteger i = 0; i < length && back != nil; i++) CHECK([back indexAtPosition:i] == values[i]);
            }
            NSUInteger big = (NSUInteger)-1;
            NSIndexPath *back = roundTrip(@"NSIndexPath max", [NSIndexPath indexPathWithIndexes:(NSUInteger[]){big, 0, big - 1} length:3], [NSIndexPath class]);
            CHECK([back indexAtPosition:0] == big && [back indexAtPosition:2] == big - 1);
            // The layout archived by macOS: indexes 1, 2, 3 as one data blob of varints.
            const uint8_t varints[] = {1, 2, 3};
            NSData *archive = spoofArchive(@"NSIndexPath", @{@"NSIndexPathLength": @3}, @{@"NSIndexPathData": bytes(varints, 3)});
            NSIndexPath *fromMac = secureDecode([NSIndexPath class], archive, NULL);
            CHECK(fromMac != nil && [fromMac length] == 3 && [fromMac indexAtPosition:2] == 3);
            const uint8_t truncated[] = {1, 2};
            CHECK(secureDecode([NSIndexPath class], spoofArchive(@"NSIndexPath", @{@"NSIndexPathLength": @3}, @{@"NSIndexPathData": bytes(truncated, 2)}), NULL) == nil);
            const uint8_t trailing[] = {1, 2, 3, 4};
            CHECK(secureDecode([NSIndexPath class], spoofArchive(@"NSIndexPath", @{@"NSIndexPathLength": @3}, @{@"NSIndexPathData": bytes(trailing, 4)}), NULL) == nil);
            const uint8_t unterminated[] = {1, 2, 0x80};
            CHECK(secureDecode([NSIndexPath class], spoofArchive(@"NSIndexPath", @{@"NSIndexPathLength": @3}, @{@"NSIndexPathData": bytes(unterminated, 3)}), NULL) == nil);
            expectRefused(@"NSIndexPath data", [NSIndexPath class], @"NSIndexPath", @{@"NSIndexPathLength": @3}, @{@"NSIndexPathData": @"str"});
        }
        // NSIndexSet
        {
            NSIndexSet *empty = [NSIndexSet indexSet];
            NSIndexSet *back = roundTrip(@"empty NSIndexSet", empty, [NSIndexSet class]);
            CHECK(back != nil && [back count] == 0);
            NSIndexSet *single = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(2, 5)];
            back = roundTrip(@"single range", single, [NSIndexSet class]);
            CHECK([back isEqualToIndexSet:single]);
            NSMutableIndexSet *multi = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(2, 5)];
            [multi addIndex:100];
            [multi addIndex:200];
            [multi addIndexesInRange:NSMakeRange(1000, 300)];
            back = roundTrip(@"multiple ranges", multi, [NSIndexSet class]);
            CHECK([back isEqualToIndexSet:multi] && [back count] == 5 + 1 + 1 + 300);
            CHECK([back containsIndex:100] && [back containsIndex:200] && [back containsIndex:1299] && ![back containsIndex:1300]);
            back = roundTrip(@"mutable", multi, [NSMutableIndexSet class]);
            CHECK([back isKindOfClass:[NSMutableIndexSet class]] && [back isEqualToIndexSet:multi]);
            // Layout archived by macOS: ranges {2,5} {100,1} {200,1} as varint pairs.
            const uint8_t ranges[] = {0x02, 0x05, 0x64, 0x01, 0xc8, 0x01, 0x01};
            NSIndexSet *fromMac = secureDecode([NSIndexSet class], spoofArchive(@"NSMutableIndexSet", @{@"NSRangeCount": @3}, @{@"NSRangeData": bytes(ranges, 7)}), NULL);
            CHECK(fromMac != nil && [fromMac count] == 7 && [fromMac containsIndex:200] && [fromMac containsIndex:6] && ![fromMac containsIndex:7]);
            const uint8_t cut[] = {0x02, 0x05, 0x64};
            CHECK(secureDecode([NSIndexSet class], spoofArchive(@"NSIndexSet", @{@"NSRangeCount": @2}, @{@"NSRangeData": bytes(cut, 3)}), NULL) == nil);
            CHECK(secureDecode([NSIndexSet class], spoofArchive(@"NSIndexSet", @{@"NSRangeCount": @(1000000)}, @{@"NSRangeData": bytes(ranges, 7)}), NULL) == nil);
            expectRefused(@"NSIndexSet data", [NSIndexSet class], @"NSIndexSet", @{@"NSRangeCount": @2}, @{@"NSRangeData": @"str"});
        }
        // NSSortDescriptor
        {
            NSSortDescriptor *descriptor = [NSSortDescriptor sortDescriptorWithKey:@"length" ascending:NO selector:@selector(compare:)];
            NSSortDescriptor *back = roundTrip(@"NSSortDescriptor", descriptor, [NSSortDescriptor class]);
            CHECK([back.key isEqual:@"length"] && !back.ascending && back.selector == @selector(compare:));
            // macOS refuses to evaluate a descriptor decoded from a secure archive until it is allowed to.
            if ([back respondsToSelector:@selector(allowEvaluation)]) [back performSelector:@selector(allowEvaluation)];
            NSArray *sorted = [@[@"bb", @"a", @"ccc"] sortedArrayUsingDescriptors:@[back]];
            CHECK([sorted isEqual:(@[@"ccc", @"bb", @"a"])]);
            back = roundTrip(@"selector descriptor", [NSSortDescriptor sortDescriptorWithKey:@"k" ascending:YES selector:@selector(caseInsensitiveCompare:)], [NSSortDescriptor class]);
            CHECK(back.ascending && back.selector == @selector(caseInsensitiveCompare:));
            back = roundTrip(@"default selector", [NSSortDescriptor sortDescriptorWithKey:@"k" ascending:YES], [NSSortDescriptor class]);
            CHECK(back.selector == @selector(compare:));
            back = roundTrip(@"nil key", [NSSortDescriptor sortDescriptorWithKey:nil ascending:YES], [NSSortDescriptor class]);
            CHECK(back.key == nil);
            NSSortDescriptor *block = [NSSortDescriptor sortDescriptorWithKey:@"x" ascending:YES comparator:^NSComparisonResult(id a, id b) { return NSOrderedSame; }];
            NSError *error = nil;
            CHECK([NSKeyedArchiver archivedDataWithRootObject:block requiringSecureCoding:YES error:&error] == nil && error != nil);
            expectRefused(@"NSSortDescriptor key", [NSSortDescriptor class], @"NSSortDescriptor", @{}, @{@"NSKey": @42, @"NSSelector": @"compare:"});
        }
        // NSRegularExpression
        {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"a(b+)c" options:NSRegularExpressionCaseInsensitive error:NULL];
            NSRegularExpression *back = roundTrip(@"NSRegularExpression", regex, [NSRegularExpression class]);
            CHECK([back.pattern isEqual:@"a(b+)c"] && back.options == NSRegularExpressionCaseInsensitive);
            CHECK([back numberOfMatchesInString:@"xABBBCx" options:0 range:NSMakeRange(0, 7)] == 1);
            regex = [NSRegularExpression regularExpressionWithPattern:@"a.b" options:NSRegularExpressionIgnoreMetacharacters error:NULL];
            CHECK([regex.pattern isEqual:@"a.b"] && regex.options == NSRegularExpressionIgnoreMetacharacters);
            back = roundTrip(@"literal pattern", regex, [NSRegularExpression class]);
            CHECK([back.pattern isEqual:@"a.b"] && back.options == NSRegularExpressionIgnoreMetacharacters);
            CHECK([back numberOfMatchesInString:@"axb" options:0 range:NSMakeRange(0, 3)] == 0);
            CHECK([back numberOfMatchesInString:@"a.b" options:0 range:NSMakeRange(0, 3)] == 1);
            expectRefused(@"NSRegularExpression pattern", [NSRegularExpression class], @"NSRegularExpression", @{@"NSOptions": @0}, @{@"NSPattern": @42});
        }
        // NSAffineTransform
        {
            NSAffineTransform *transform = [NSAffineTransform transform];
            [transform translateXBy:3 yBy:4];
            [transform scaleBy:2];
            NSAffineTransform *back = roundTrip(@"NSAffineTransform", transform, [NSAffineTransform class]);
            NSAffineTransformStruct a = transform.transformStruct, b = back.transformStruct;
            CHECK(a.m11 == b.m11 && a.m12 == b.m12 && a.m21 == b.m21 && a.m22 == b.m22 && a.tX == b.tX && a.tY == b.tY);
            back = roundTrip(@"identity transform", [NSAffineTransform transform], [NSAffineTransform class]);
            CHECK(back.transformStruct.m11 == 1 && back.transformStruct.tX == 0);
        }
        // NSError
        {
            NSError *underlying = [NSError errorWithDomain:@"under" code:1 userInfo:nil];
            NSError *error = [NSError errorWithDomain:@"domain" code:-7 userInfo:@{
                NSUnderlyingErrorKey: underlying, NSURLErrorKey: [NSURL URLWithString:@"http://example.com/x"],
                @"s": @"v", @"n": @1, @"d": [NSDate dateWithTimeIntervalSince1970:5], @"data": [NSData dataWithBytes:"ab" length:2],
                @"a": @[@"x"], @"dict": @{@"k": @"v"}}];
            NSError *back = roundTrip(@"NSError", error, [NSError class]);
            CHECK([back.domain isEqual:@"domain"] && back.code == -7);
            CHECK([back.userInfo isEqual:error.userInfo]);
            CHECK([[back.userInfo[NSUnderlyingErrorKey] domain] isEqual:@"under"]);
            back = roundTrip(@"plain NSError", [NSError errorWithDomain:@"d" code:0 userInfo:nil], [NSError class]);
            CHECK([back.domain isEqual:@"d"] && back.code == 0 && [back.userInfo count] == 0);
            expectRefused(@"NSError user info class", [NSError class], @"NSError", @{@"NSCode": @1}, @{@"NSDomain": @"d", @"NSUserInfo": @{@"k": [NSSet setWithObject:@1]}});
        }
        // NSURL
        {
            NSURL *absolute = [NSURL URLWithString:@"http://example.com/a?b#c"];
            NSURL *back = roundTrip(@"absolute NSURL", absolute, [NSURL class]);
            CHECK([back isEqual:absolute] && [back baseURL] == nil);
            NSURL *relative = [NSURL URLWithString:@"x/y" relativeToURL:[NSURL URLWithString:@"http://example.com/a/"]];
            back = roundTrip(@"relative NSURL", relative, [NSURL class]);
            CHECK([[back absoluteString] isEqual:@"http://example.com/a/x/y"] && [[[back baseURL] absoluteString] isEqual:@"http://example.com/a/"]);
            expectRefused(@"NSURL relative", [NSURL class], @"NSURL", @{}, @{@"NS.relative": @42});
            expectRefused(@"NSURL base", [NSURL class], @"NSURL", @{}, @{@"NS.relative": @"x", @"NS.base": @"http://example.com/"});
        }
        // NSNull
        {
            id back = roundTrip(@"NSNull", [NSNull null], [NSNull class]);
            CHECK(back == [NSNull null]);
        }
        // NSLocale, NSTimeZone
        {
            NSLocale *back = roundTrip(@"NSLocale", [NSLocale localeWithLocaleIdentifier:@"fr_FR"], [NSLocale class]);
            CHECK([[back localeIdentifier] isEqual:@"fr_FR"]);
            expectRefused(@"NSLocale identifier", [NSLocale class], @"NSLocale", @{}, @{@"NS.identifier": @42});
            NSTimeZone *zone = roundTrip(@"NSTimeZone", [NSTimeZone timeZoneWithName:@"Asia/Tokyo"], [NSTimeZone class]);
            CHECK([[zone name] isEqual:@"Asia/Tokyo"] && [zone secondsFromGMT] == 9 * 3600);
            expectRefused(@"NSTimeZone name", [NSTimeZone class], @"NSTimeZone", @{}, @{@"NS.name": @42});
        }
        // NSCalendar
        {
            NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierBuddhist] autorelease];
            calendar.firstWeekday = 2;
            calendar.minimumDaysInFirstWeek = 4;
            calendar.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Tokyo"];
            calendar.locale = [NSLocale localeWithLocaleIdentifier:@"fr_FR"];
            NSCalendar *back = roundTrip(@"NSCalendar", calendar, [NSCalendar class]);
            CHECK([back.calendarIdentifier isEqual:NSCalendarIdentifierBuddhist]);
            CHECK(back.firstWeekday == 2 && back.minimumDaysInFirstWeek == 4);
            CHECK([back.timeZone.name isEqual:@"Asia/Tokyo"] && [back.locale.localeIdentifier isEqual:@"fr_FR"]);
            back = roundTrip(@"gregorian NSCalendar", [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease], [NSCalendar class]);
            CHECK([back.calendarIdentifier isEqual:NSCalendarIdentifierGregorian]);
            expectRefused(@"NSCalendar identifier", [NSCalendar class], @"NSCalendar", @{}, @{@"NS.identifier": @42});
        }
        // NSDateComponents
        {
            NSDateComponents *components = [[[NSDateComponents alloc] init] autorelease];
            components.year = 2020;
            components.hour = 5;
            components.nanosecond = 9;
            components.weekOfYear = 3;
            components.weekday = 2;
            [components setLeapMonth:YES];
            components.calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] autorelease];
            components.timeZone = [NSTimeZone timeZoneWithName:@"Asia/Tokyo"];
            NSDateComponents *back = roundTrip(@"NSDateComponents", components, [NSDateComponents class]);
            CHECK(back.year == 2020 && back.hour == 5 && back.nanosecond == 9 && back.weekOfYear == 3 && back.weekday == 2);
            CHECK(back.month == NSDateComponentUndefined && back.day == NSDateComponentUndefined && back.era == NSDateComponentUndefined);
            CHECK(back.minute == NSDateComponentUndefined && back.quarter == NSDateComponentUndefined);
            CHECK([back isLeapMonth] && [back.calendar.calendarIdentifier isEqual:NSCalendarIdentifierGregorian]);
            CHECK([back.timeZone.name isEqual:@"Asia/Tokyo"]);
            back = roundTrip(@"empty NSDateComponents", [[[NSDateComponents alloc] init] autorelease], [NSDateComponents class]);
            CHECK(back.year == NSDateComponentUndefined && ![back isLeapMonth] && back.calendar == nil && back.timeZone == nil);
            expectRefused(@"NSDateComponents calendar", [NSDateComponents class], @"NSDateComponents", @{}, @{@"NS.calendar": @"str"});
        }

        // NSPointerArray, NSHashTable, NSMapTable: the options, the members and a nil terminator are archived
        // as unkeyed values ($0, $1, ...), the member count of the tables as NS.count.
        {
            NSString *p1 = [NSString stringWithFormat:@"p%d", 1], *p2 = [NSString stringWithFormat:@"p%d", 2];
            NSPointerArray *array = [NSPointerArray strongObjectsPointerArray];
            [array addPointer:(void *)p1];
            [array addPointer:NULL];
            [array addPointer:(void *)p2];
            NSPointerArray *arrayBack = roundTrip(@"NSPointerArray", array, [NSPointerArray class]);
            CHECK([arrayBack count] == 3);
            CHECK([(id)[arrayBack pointerAtIndex:0] isEqual:@"p1"] && [arrayBack pointerAtIndex:1] == NULL && [(id)[arrayBack pointerAtIndex:2] isEqual:@"p2"]);
            NSDictionary *fields = objectWithKey(tryArchive(array), @"$1");
            CHECK(keysAre(fields, @"$0,$1,$2,$3,$4,$5,$class"));
            CHECK([fields[@"$0"] intValue] == 0 && [fields[@"$1"] intValue] == 3);
            arrayBack = roundTrip(@"empty NSPointerArray", [NSPointerArray strongObjectsPointerArray], [NSPointerArray class]);
            CHECK([arrayBack count] == 0);
            NSPointerArray *weakArray = [NSPointerArray weakObjectsPointerArray];
            [weakArray addPointer:(void *)p1];
            fields = objectWithKey(tryArchive(weakArray), @"$1");
            CHECK([fields[@"$0"] intValue] == NSPointerFunctionsWeakMemory && [fields[@"$1"] intValue] == 1);
            roundTrip(@"weak NSPointerArray", weakArray, [NSPointerArray class]);
            // test_quirk_weak_members_are_not_archived: a weak member is a separate "$null" string object.
            CHECK(hasNullStringObject(tryArchive(weakArray)));
            CHECK(!hasNullStringObject(tryArchive(array)));
            // test_quirk_collection_options_must_be_object_options: only object collections archive.
            CHECK(tryArchive([NSPointerArray pointerArrayWithOptions:NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality]) == nil);

            NSHashTable *table = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPersonality];
            [table addObject:@"a"];
            [table addObject:@3];
            NSHashTable *tableBack = roundTrip(@"NSHashTable", table, [NSHashTable class]);
            CHECK([tableBack count] == 2 && [tableBack containsObject:@"a"] && [tableBack containsObject:@3]);
            fields = objectWithKey(tryArchive(table), @"NS.count");
            CHECK(keysAre(fields, @"$0,$1,$2,$3,$class,NS.count"));
            CHECK([fields[@"$0"] intValue] == 0 && [fields[@"NS.count"] intValue] == 2);
            tableBack = roundTrip(@"empty NSHashTable", [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPersonality | NSPointerFunctionsCopyIn], [NSHashTable class]);
            CHECK([tableBack count] == 0);
            fields = objectWithKey(tryArchive([NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPersonality | NSPointerFunctionsCopyIn]), @"NS.count");
            CHECK(keysAre(fields, @"$0,$1,$class,NS.count") && [fields[@"$0"] intValue] == NSPointerFunctionsCopyIn);
            NSHashTable *pointerTable = [NSHashTable hashTableWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
            [pointerTable addObject:p1];
            tableBack = roundTrip(@"NSHashTable with object pointer personality", pointerTable, [NSHashTable class]);
            CHECK([tableBack count] == 1);
            fields = objectWithKey(tryArchive(pointerTable), @"NS.count");
            CHECK([fields[@"$0"] intValue] == NSPointerFunctionsObjectPointerPersonality);
            // test_quirk_weak_members_are_not_archived: the count stays in NS.count, nothing is restored.
            NSHashTable *weakTable = [NSHashTable weakObjectsHashTable];
            [weakTable addObject:p1];
            [weakTable addObject:p2];
            fields = objectWithKey(tryArchive(weakTable), @"NS.count");
            CHECK([fields[@"$0"] intValue] == NSPointerFunctionsWeakMemory && [fields[@"NS.count"] intValue] == 2);
            CHECK(hasNullStringObject(tryArchive(weakTable)));
            tableBack = roundTrip(@"weak NSHashTable", weakTable, [NSHashTable class]);
            CHECK([tableBack count] == 0);
            // test_quirk_collection_options_must_be_object_options
            CHECK(tryArchive([NSHashTable hashTableWithOptions:NSPointerFunctionsOpaquePersonality]) == nil);

            NSMapTable *map = [NSMapTable strongToStrongObjectsMapTable];
            [map setObject:@"v1" forKey:@"k1"];
            [map setObject:@"v2" forKey:@"k2"];
            NSMapTable *mapBack = roundTrip(@"NSMapTable", map, [NSMapTable class]);
            CHECK([mapBack count] == 2 && [[mapBack objectForKey:@"k1"] isEqual:@"v1"] && [[mapBack objectForKey:@"k2"] isEqual:@"v2"]);
            fields = objectWithKey(tryArchive(map), @"NS.count");
            CHECK(keysAre(fields, @"$0,$1,$2,$3,$4,$5,$6,$class,NS.count"));
            CHECK([fields[@"$0"] intValue] == 0 && [fields[@"$1"] intValue] == 0 && [fields[@"NS.count"] intValue] == 2);
            mapBack = roundTrip(@"empty NSMapTable", [NSMapTable strongToStrongObjectsMapTable], [NSMapTable class]);
            CHECK([mapBack count] == 0);
            NSMapTable *weakKeys = [NSMapTable weakToStrongObjectsMapTable];
            [weakKeys setObject:@"v" forKey:p1];
            fields = objectWithKey(tryArchive(weakKeys), @"NS.count");
            CHECK([fields[@"$0"] intValue] == NSPointerFunctionsWeakMemory && [fields[@"$1"] intValue] == 0 && [fields[@"NS.count"] intValue] == 1);
            CHECK(hasNullStringObject(tryArchive(weakKeys)));
            roundTrip(@"weak-to-strong NSMapTable", weakKeys, [NSMapTable class]);
            CHECK(tryArchive([NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaquePersonality valueOptions:NSPointerFunctionsOpaquePersonality]) == nil);
        }
        // test_quirk_set_error_policy_returns_nil (MC26.13, macOS 26.7.3): an unarchiver made with
        // -initForReadingFromData:error: does not raise for a refused class; it returns nil and sets -error.
        {
            NSData *urlArchive = [NSKeyedArchiver archivedDataWithRootObject:[NSURL URLWithString:@"http://example.com/"] requiringSecureCoding:YES error:NULL];
            NSError *initError = nil;
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:urlArchive error:&initError];
            CHECK(unarchiver != nil && initError == nil);
            CHECK([unarchiver decodingFailurePolicy] == NSDecodingFailurePolicySetErrorAndReturn);
            [unarchiver setRequiresSecureCoding:YES];
            id refused = nil;
            BOOL raised = NO;
            @try {
                refused = [unarchiver decodeObjectOfClasses:[NSSet setWithObject:[NSString class]] forKey:NSKeyedArchiveRootObjectKey];
            } @catch (NSException *exception) {
                raised = YES;
            }
            CHECK(!raised && refused == nil);
            CHECK([[unarchiver error] code] == 4864);
            [unarchiver release];
            // Data that is not an archive fails the initializer with an error.
            NSError *badError = nil;
            CHECK([[NSKeyedUnarchiver alloc] initForReadingFromData:[NSData dataWithBytes:"xyz" length:3] error:&badError] == nil);
            CHECK(badError != nil);
        }
        // NSValue ranges: the members are archived as references to NSNumber objects.
        // test_quirk_nsvalue_range_references (MC26.13, macOS 26.7.3)
        {
            NSValue *range = [NSValue valueWithRange:NSMakeRange(NSNotFound, 0)];
            NSValue *rangeBack = roundTrip(@"NSValue range", range, [NSValue class]);
            CHECK(rangeBack != nil && NSEqualRanges([rangeBack rangeValue], NSMakeRange(NSNotFound, 0)));
            NSDictionary *fields = objectWithKey(tryArchive(range), @"NS.rangeval.location");
            CHECK(keysAre(fields, @"$class,NS.rangeval.length,NS.rangeval.location,NS.special"));
            CHECK(fields != nil && ![fields[@"NS.rangeval.location"] isKindOfClass:[NSNumber class]]);
            CHECK(fields != nil && ![fields[@"NS.rangeval.length"] isKindOfClass:[NSNumber class]]);
            CHECK([fields[@"NS.special"] intValue] == 4);
            // Archives with inline integers (written by earlier versions) still decode.
            NSValue *old = secureDecode([NSValue class], spoofArchive(@"NSValue", @{@"NS.special": @4, @"NS.rangeval.location": @3, @"NS.rangeval.length": @9}, @{}), NULL);
            CHECK(old != nil && NSEqualRanges([old rangeValue], NSMakeRange(3, 9)));
        }
        // NSOrthography
        {
            NSDictionary *languageMap = @{@"Latn": @[@"en", @"fr"], @"Cyrl": @[@"ru"]};
            NSOrthography *orthography = [NSOrthography orthographyWithDominantScript:@"Latn" languageMap:languageMap];
            NSOrthography *back = roundTrip(@"NSOrthography", orthography, [NSOrthography class]);
            CHECK([back.dominantScript isEqual:@"Latn"] && [back.languageMap isEqual:languageMap]);
            CHECK([back isEqual:orthography]);
            CHECK([[back languagesForScript:@"Cyrl"] isEqual:@[@"ru"]] && [back.dominantLanguage isEqual:@"en"]);
            NSDictionary *fields = objectWithKey(tryArchive(orthography), @"NSDominantScript");
            CHECK(keysAre(fields, @"$class,NSDominantScript,NSLanguageMap"));
            expectRefused(@"NSOrthography script", [NSOrthography class], @"NSOrthography", @{}, @{@"NSDominantScript": @42, @"NSLanguageMap": languageMap});
            expectRefused(@"NSOrthography map", [NSOrthography class], @"NSOrthography", @{}, @{@"NSDominantScript": @"Latn", @"NSLanguageMap": @{@"Latn": @[@42]}});
        }
        // NSTextCheckingResult: the range (NSRangeLocation, NSRangeLength) and the fields of each kind.
        {
            NSTextCheckingResult *r = [NSTextCheckingResult replacementCheckingResultWithRange:NSMakeRange(1, 3) replacementString:@"fix"];
            NSTextCheckingResult *back = roundTrip(@"replacement result", r, [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeReplacement && NSEqualRanges(back.range, NSMakeRange(1, 3)) && [back.replacementString isEqual:@"fix"]);
            NSDictionary *fields = objectWithKey(tryArchive(r), @"NSReplacementString");
            CHECK(keysAre(fields, @"$class,NSRangeLength,NSRangeLocation,NSReplacementString"));
            CHECK([NSStringFromClass([back class]) isEqual:@"NSReplacementCheckingResult"]);
            back = roundTrip(@"correction result", [NSTextCheckingResult correctionCheckingResultWithRange:NSMakeRange(0, 5) replacementString:@"x"], [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeCorrection && [back.replacementString isEqual:@"x"]);
            back = roundTrip(@"quote result", [NSTextCheckingResult quoteCheckingResultWithRange:NSMakeRange(0, 1) replacementString:@"\""], [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeQuote && [back.replacementString isEqual:@"\""]);
            back = roundTrip(@"dash result", [NSTextCheckingResult dashCheckingResultWithRange:NSMakeRange(0, 2) replacementString:@"-"], [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeDash && [back.replacementString isEqual:@"-"]);
            back = roundTrip(@"spelling result", [NSTextCheckingResult spellCheckingResultWithRange:NSMakeRange(2, 4)], [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeSpelling && NSEqualRanges(back.range, NSMakeRange(2, 4)));
            fields = objectWithKey(tryArchive([NSTextCheckingResult spellCheckingResultWithRange:NSMakeRange(2, 4)]), @"NSRangeLocation");
            CHECK(keysAre(fields, @"$class,NSRangeLength,NSRangeLocation"));
            NSOrthography *orthography = [NSOrthography orthographyWithDominantScript:@"Latn" languageMap:@{@"Latn": @[@"en"]}];
            back = roundTrip(@"orthography result", [NSTextCheckingResult orthographyCheckingResultWithRange:NSMakeRange(0, 5) orthography:orthography], [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeOrthography && NSEqualRanges(back.range, NSMakeRange(0, 5)) && [back.orthography isEqual:orthography]);
            back = roundTrip(@"link result", [NSTextCheckingResult linkCheckingResultWithRange:NSMakeRange(2, 3) URL:[NSURL URLWithString:@"http://example.com/b"]], [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeLink && NSEqualRanges(back.range, NSMakeRange(2, 3)) && [back.URL isEqual:[NSURL URLWithString:@"http://example.com/b"]]);
            NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:99];
            back = roundTrip(@"date result", [NSTextCheckingResult dateCheckingResultWithRange:NSMakeRange(0, 5) date:date timeZone:[NSTimeZone timeZoneWithName:@"Asia/Tokyo"] duration:60], [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeDate && [back.date isEqual:date] && [back.timeZone.name isEqual:@"Asia/Tokyo"] && back.duration == 60);
            back = roundTrip(@"date result without time zone", [NSTextCheckingResult dateCheckingResultWithRange:NSMakeRange(0, 5) date:date], [NSTextCheckingResult class]);
            CHECK([back.date isEqual:date] && back.timeZone == nil && back.duration == 0);
            fields = objectWithKey(tryArchive([NSTextCheckingResult dateCheckingResultWithRange:NSMakeRange(0, 5) date:date]), @"NSDate");
            CHECK(keysAre(fields, @"$class,NSDate,NSDuration,NSRangeLength,NSRangeLocation,NSReferenceDate,NSTimeZone") || keysAre(fields, @"$class,NSDate,NSDuration,NSRangeLength,NSRangeLocation"));
            NSDictionary *components = @{NSTextCheckingCityKey: @"Prague", NSTextCheckingCountryKey: @"CZ"};
            back = roundTrip(@"address result", [NSTextCheckingResult addressCheckingResultWithRange:NSMakeRange(0, 5) components:components], [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeAddress && [back.addressComponents isEqual:components]);
            back = roundTrip(@"phone number result", [NSTextCheckingResult phoneNumberCheckingResultWithRange:NSMakeRange(0, 5) phoneNumber:@"123 456"], [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypePhoneNumber && [back.phoneNumber isEqual:@"123 456"]);
            back = roundTrip(@"transit result", [NSTextCheckingResult transitInformationCheckingResultWithRange:NSMakeRange(0, 5) components:@{NSTextCheckingAirlineKey: @"A"}], [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeTransitInformation && [back.components isEqual:@{NSTextCheckingAirlineKey: @"A"}]);
            NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"a(b)" options:0 error:NULL];
            NSTextCheckingResult *match = [expression firstMatchInString:@"xab" options:0 range:NSMakeRange(0, 3)];
            back = roundTrip(@"regular expression result", match, [NSTextCheckingResult class]);
            CHECK(back.resultType == NSTextCheckingTypeRegularExpression && back.numberOfRanges == 2);
            CHECK(NSEqualRanges([back rangeAtIndex:0], NSMakeRange(1, 2)) && NSEqualRanges([back rangeAtIndex:1], NSMakeRange(2, 1)));
            CHECK([[back.regularExpression pattern] isEqual:@"a(b)"]);
            fields = objectWithKey(tryArchive(match), @"NSRangeArray");
            CHECK(keysAre(fields, @"$class,NSRangeArray,NSRangeLength,NSRangeLocation,NSRegularExpression"));
            NSRange five[5] = {{0, 5}, {1, 1}, {2, 1}, {3, 1}, {NSNotFound, 0}};
            back = roundTrip(@"five-range regular expression result", [NSTextCheckingResult regularExpressionCheckingResultWithRanges:five count:5 regularExpression:expression], [NSTextCheckingResult class]);
            CHECK(back.numberOfRanges == 5 && NSEqualRanges([back rangeAtIndex:4], NSMakeRange(NSNotFound, 0)) && NSEqualRanges([back rangeAtIndex:0], NSMakeRange(0, 5)));
            NSRange nine[9] = {{0, 9}, {1, 1}, {2, 1}, {3, 1}, {4, 1}, {5, 1}, {6, 1}, {7, 1}, {8, 1}};
            back = roundTrip(@"nine-range regular expression result", [NSTextCheckingResult regularExpressionCheckingResultWithRanges:nine count:9 regularExpression:expression], [NSTextCheckingResult class]);
            CHECK(back.numberOfRanges == 9 && NSEqualRanges([back rangeAtIndex:8], NSMakeRange(8, 1)));
        }
        // NSAttributedString and NSMutableAttributedString: the string, the attribute runs
        // (NSAttributes, and for several runs NSAttributeInfo as varint length/index pairs).
        {
            NSDictionary *A = @{@"a": @1}, *B = @{@"b": @"two"};
            NSDictionary *A2 = [NSDictionary dictionaryWithObject:@1 forKey:@"a"]; // equal to A, a different object
            NSMutableAttributedString *mutableString = [[[NSMutableAttributedString alloc] initWithString:@"AAAAABBBBBAAAAA"] autorelease];
            [mutableString setAttributes:A range:NSMakeRange(0, 5)];
            [mutableString setAttributes:B range:NSMakeRange(5, 5)];
            [mutableString setAttributes:A2 range:NSMakeRange(10, 5)];
            NSAttributedString *immutableString = [[mutableString copy] autorelease];

            NSMutableAttributedString *mutableBack = roundTrip(@"NSMutableAttributedString", mutableString, [NSMutableAttributedString class]);
            CHECK([mutableBack isKindOfClass:[NSMutableAttributedString class]] && [mutableBack isEqualToAttributedString:mutableString]);
            [mutableBack appendAttributedString:[[[NSAttributedString alloc] initWithString:@"!"] autorelease]]; // really mutable
            CHECK([mutableBack length] == 16);
            NSAttributedString *immutableBack = roundTrip(@"NSAttributedString", immutableString, [NSAttributedString class]);
            CHECK([immutableBack isEqualToAttributedString:immutableString] && [immutableBack length] == 15);
            NSRange run;
            CHECK([[immutableBack attributesAtIndex:7 effectiveRange:&run] isEqual:B] && NSEqualRanges(run, NSMakeRange(5, 5)));

            NSDictionary *fields = objectWithKey(tryArchive(mutableString), @"NSAttributeInfo");
            CHECK(keysAre(fields, @"$class,NSAttributeInfo,NSAttributes,NSString"));
            // macOS shares an attribute dictionary between runs only when it is the same object
            // (MC26.13): the third run uses an equal but distinct dictionary and gets its own index.
            const uint8_t expectedInfo[] = {5, 0, 5, 1, 5, 2};
            CHECK(archiveHasData(tryArchive(mutableString), bytes(expectedInfo, sizeof expectedInfo)));

            NSAttributedString *single = [[[NSAttributedString alloc] initWithString:@"abc" attributes:A] autorelease];
            NSAttributedString *singleBack = roundTrip(@"single-run NSAttributedString", single, [NSAttributedString class]);
            CHECK([singleBack isEqualToAttributedString:single]);
            fields = objectWithKey(tryArchive(single), @"NSAttributes");
            CHECK(keysAre(fields, @"$class,NSAttributes,NSString"));
            NSAttributedString *empty = [[[NSAttributedString alloc] initWithString:@""] autorelease];
            NSAttributedString *emptyBack = roundTrip(@"empty NSAttributedString", empty, [NSAttributedString class]);
            CHECK([emptyBack length] == 0);
            fields = objectWithKey(tryArchive(empty), @"NSString");
            CHECK(keysAre(fields, @"$class,NSString"));
            NSMutableString *longString = [NSMutableString string];
            for (int i = 0; i < 300; i++) [longString appendString:@"x"];
            NSMutableAttributedString *longRuns = [[[NSMutableAttributedString alloc] initWithString:longString attributes:A] autorelease];
            [longRuns addAttributes:B range:NSMakeRange(130, 1)]; // run lengths above 127 take two varint bytes
            NSAttributedString *longBack = roundTrip(@"NSMutableAttributedString with long runs", longRuns, [NSMutableAttributedString class]);
            CHECK([longBack isEqualToAttributedString:longRuns]);
            // macOS reuses the dictionary of the split run for the third run (index 0); ours writes one dictionary
            // per run, so only the run lengths and the first indexes are compared.
            const uint8_t expectedLongInfo[] = {0x82, 0x01, 0, 1, 1, 0xa9, 0x01};
            CHECK(archiveHasDataPrefix(tryArchive(longRuns), bytes(expectedLongInfo, sizeof expectedLongInfo)));

            // Attribute values: strings, numbers, URLs, data, arrays, dictionaries and attributed strings are
            // accepted; others make the secure decoding fail.
            NSURL *url = [NSURL URLWithString:@"http://example.com/"];
            NSAttributedString *rich = [[[NSAttributedString alloc] initWithString:@"x" attributes:@{@"u": url, @"d": [NSData dataWithBytes:"ab" length:2], @"l": @[@1, @"s"], @"m": @{@"k": @2}, @"n": @1.5}] autorelease];
            NSAttributedString *richBack = roundTrip(@"NSAttributedString with attribute values", rich, [NSAttributedString class]);
            CHECK([richBack isEqualToAttributedString:rich]);
            NSAttributedString *refused[] = {
                [[[NSAttributedString alloc] initWithString:@"x" attributes:@{@"w": [NSSet setWithObject:@1]}] autorelease],
                [[[NSAttributedString alloc] initWithString:@"x" attributes:@{@"w": [NSDate dateWithTimeIntervalSinceReferenceDate:5]}] autorelease],
                [[[NSAttributedString alloc] initWithString:@"x" attributes:@{@"w": [NSNull null]}] autorelease],
            };
            for (size_t i = 0; i < sizeof refused / sizeof refused[0]; i++) {
                NSError *error = nil;
                CHECK(secureDecode([NSAttributedString class], tryArchive(refused[i]), &error) == nil);
            }
            // An attribute value the archiver cannot encode makes the archiving fail.
            CHECK(tryArchive([[[NSAttributedString alloc] initWithString:@"x" attributes:@{@"o": [[[NSObject alloc] init] autorelease]}] autorelease]) == nil);
            expectRefused(@"attributed string text", [NSAttributedString class], @"NSAttributedString", @{}, @{@"NSString": @42});
        }
    }
    if (failures != 0) {
        printf("%d failures\n", failures);
        return 1;
    }
    printf("PASS: secure coding conformance\n");
    return 0;
}
