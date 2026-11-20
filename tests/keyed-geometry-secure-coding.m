/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * The keyed geometry coders (rect, size, point) work with secure coding on:
 * a keyed unarchiver that requires secure coding decodes values that were
 * written with -encodeRect:forKey: and its siblings, as it does without
 * secure coding. (Same on macOS 26.7.3 and Mac OS X 10.14.4.)
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static void roundTrip(BOOL secure) {
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData: data];
    [archiver setRequiresSecureCoding: secure];
    [archiver encodeRect: NSMakeRect(1, 2, 3, 4) forKey: @"rect"];
    [archiver encodeSize: NSMakeSize(5, 6) forKey: @"size"];
    [archiver encodePoint: NSMakePoint(7, 8) forKey: @"point"];
    [archiver finishEncoding];
    [archiver release];

    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData: data];
    [unarchiver setRequiresSecureCoding: secure];
    NSRect rect = NSZeroRect;
    NSSize size = NSZeroSize;
    NSPoint point = NSZeroPoint;
    @try {
        rect = [unarchiver decodeRectForKey: @"rect"];
        size = [unarchiver decodeSizeForKey: @"size"];
        point = [unarchiver decodePointForKey: @"point"];
    } @catch (id exception) {
        fprintf(stderr, "FAIL: secure=%d raised %s\n", secure, [[exception description] UTF8String]);
        failures++;
    }
    CHECK(NSEqualRects(rect, NSMakeRect(1, 2, 3, 4)));
    CHECK(NSEqualSizes(size, NSMakeSize(5, 6)));
    CHECK(NSEqualPoints(point, NSMakePoint(7, 8)));
    [unarchiver release];
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    roundTrip(NO);
    roundTrip(YES);
    printf(failures ? "FAIL\n" : "PASS\n");
    [pool drain];
    return failures ? 1 : 0;
}
