// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: decoding a point, size or rect for a key that is not in a keyed archive returns the zero
// value and does not log anything (NSCoder's geometry decoding methods, documented as returning the zero
// value for a missing key). Values observed on macOS 10.14.4 and 26.7.3, see vd-upstream
// mac-probes/ua6-coder-missing-geometry.m.
#import <Foundation/Foundation.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
        [archiver encodeSize:NSMakeSize(3, 4) forKey:@"size"];
        [archiver encodePoint:NSMakePoint(5, 6) forKey:@"point"];
        [archiver encodeRect:NSMakeRect(1, 2, 3, 4) forKey:@"rect"];
        [archiver finishEncoding];
        NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingFromData:[archiver encodedData] error:NULL];

        // Anything logged while decoding goes to a file instead of the real standard error.
        fflush(stderr);
        int saved = dup(2);
        FILE *log = tmpfile();
        dup2(fileno(log), 2);

        NSSize size = [u decodeSizeForKey:@"size"];
        NSPoint point = [u decodePointForKey:@"point"];
        NSRect rect = [u decodeRectForKey:@"rect"];
        NSSize missingSize = [u decodeSizeForKey:@"no-size"];
        NSPoint missingPoint = [u decodePointForKey:@"no-point"];
        NSRect missingRect = [u decodeRectForKey:@"no-rect"];

        fflush(stderr);
        long logged = ftell(log);
        dup2(saved, 2);
        close(saved);

        CHECK(NSEqualSizes(size, NSMakeSize(3, 4)));
        CHECK(NSEqualPoints(point, NSMakePoint(5, 6)));
        CHECK(NSEqualRects(rect, NSMakeRect(1, 2, 3, 4)));
        CHECK(NSEqualSizes(missingSize, NSZeroSize));
        CHECK(NSEqualPoints(missingPoint, NSZeroPoint));
        CHECK(NSEqualRects(missingRect, NSZeroRect));
        CHECK(logged == 0);
    }
    if (failures) return 1;
    printf("PASS\n");
    return 0;
}
