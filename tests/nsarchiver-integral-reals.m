// Copyright (C) 2026 Lubos Dolezel
//
// QUIRK test: NSArchiver writes whole-number floats and doubles as integers,
// other values as reals (expected bytes observed on macOS 26.7.3), and
// NSUnarchiver reads both forms back.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static int failures;
#define CHECK(c, msg) do { if (!(c)) { printf("FAIL %s\n", msg); failures++; } } while (0)

int main(void) {
    @autoreleasepool {
        float f[] = {0, 1, 2, -1, 100000.0f, 0.5f, -0.0f};
        double d[] = {0, 1, -3, 1e10};
        NSMutableData *data = [NSMutableData data];
        NSArchiver *archiver = [[NSArchiver alloc] initForWritingWithMutableData: data];
        for (int i = 0; i < 6; i++)
            [archiver encodeValueOfObjCType: "f" at: &f[i]];
        for (int i = 0; i < 3; i++)
            [archiver encodeValueOfObjCType: "d" at: &d[i]];
        // After the header: type string "f" (label 0), then values; later uses of the type are label references.
        static const unsigned char expected[] = {
            0x84, 0x01, 'f', 0x00, 0x92, 0x01, 0x92, 0x02, 0x92, 0xff,
            0x92, 0x82, 0xa0, 0x86, 0x01, 0x00, 0x92, 0x83, 0x00, 0x00, 0x00, 0x3f,
            0x84, 0x01, 'd', 0x00, 0x93, 0x01, 0x93, 0xfd };
        CHECK([data length] >= sizeof(expected) &&
              memcmp((const char *)[data bytes] + [data length] - sizeof(expected), expected, sizeof(expected)) == 0,
              "whole numbers are written as integers");

        NSUnarchiver *reader = [[NSUnarchiver alloc] initForReadingWithData: data];
        float rf[6];
        double rd[3];
        for (int i = 0; i < 6; i++)
            [reader decodeValueOfObjCType: "f" at: &rf[i]];
        for (int i = 0; i < 3; i++)
            [reader decodeValueOfObjCType: "d" at: &rd[i]];
        CHECK(rf[0] == 0 && rf[1] == 1 && rf[2] == 2 && rf[3] == -1 && rf[4] == 100000.0f && rf[5] == 0.5f,
              "floats read back");
        CHECK(rd[0] == 0 && rd[1] == 1 && rd[2] == -3, "doubles read back");

        // Values outside the int range stay reals.
        NSMutableData *big = [NSMutableData data];
        NSArchiver *bigArchiver = [[NSArchiver alloc] initForWritingWithMutableData: big];
        [bigArchiver encodeValueOfObjCType: "d" at: &d[3]];
        NSUnarchiver *bigReader = [[NSUnarchiver alloc] initForReadingWithData: big];
        double back = 0;
        [bigReader decodeValueOfObjCType: "d" at: &back];
        CHECK(back == 1e10, "a whole number beyond the int range round trips");
        printf(failures ? "FAILED\n" : "PASSED\n");
    }
    return failures != 0;
}
