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

static NSData *bytes(const uint8_t *p, size_t n) { return [NSData dataWithBytes:p length:n]; }

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
    }
    if (failures != 0) {
        printf("%d failures\n", failures);
        return 1;
    }
    printf("PASS: secure coding conformance\n");
    return 0;
}
