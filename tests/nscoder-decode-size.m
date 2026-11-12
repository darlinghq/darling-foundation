// Copyright (C) 2026 Lubos Dolezel
//
// -[NSCoder decodeValueOfObjCType:at:size:]: decodes like -decodeValueOfObjCType:at:
// and raises NSInvalidArgumentException when the buffer is smaller than the type.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

int main(void)
{
    @autoreleasepool
    {
        NSMutableData *buffer = [NSMutableData data];
        NSArchiver *archiver = [[NSArchiver alloc] initForWritingWithMutableData:buffer];
        int i = 42;
        double d = 2.5;
        const char *string = "str";
        NSRange range = NSMakeRange(3, 4);
        [archiver encodeValueOfObjCType:"i" at:&i];
        [archiver encodeValueOfObjCType:"d" at:&d];
        [archiver encodeValueOfObjCType:"*" at:&string];
        [archiver encodeValueOfObjCType:@encode(NSRange) at:&range];
        [archiver release];

        NSUnarchiver *unarchiver = [[NSUnarchiver alloc] initForReadingWithData:buffer];
        int i2 = 0;
        double d2 = 0;
        char *string2 = NULL;
        NSRange range2 = NSMakeRange(0, 0);
        @try {
            [unarchiver decodeValueOfObjCType:"i" at:&i2 size:sizeof i2];
            [unarchiver decodeValueOfObjCType:"d" at:&d2 size:sizeof d2];
            [unarchiver decodeValueOfObjCType:"*" at:&string2 size:sizeof string2];
            [unarchiver decodeValueOfObjCType:@encode(NSRange) at:&range2 size:sizeof range2];
        } @catch (NSException *e) {
            printf("FAIL: decoding raised %s\n", [[e name] UTF8String]);
            failures++;
        }
        CHECK(i2 == 42 && d2 == 2.5);
        CHECK(string2 != NULL && strcmp(string2, "str") == 0);
        CHECK(range2.location == 3 && range2.length == 4);
        [unarchiver release];

        // A buffer that is too small is refused.
        NSMutableData *buffer2 = [NSMutableData data];
        NSArchiver *archiver2 = [[NSArchiver alloc] initForWritingWithMutableData:buffer2];
        [archiver2 encodeValueOfObjCType:"d" at:&d];
        [archiver2 release];
        NSUnarchiver *unarchiver2 = [[NSUnarchiver alloc] initForReadingWithData:buffer2];
        double d3 = 0;
        BOOL raised = NO;
        @try { [unarchiver2 decodeValueOfObjCType:"d" at:&d3 size:4]; }
        @catch (NSException *e) { raised = [[e name] isEqualToString:NSInvalidArgumentException]; }
        CHECK(raised);
        [unarchiver2 release];

        // The base implementation also serves the keyed unarchiver and is reachable on any coder.
        NSMutableData *buffer3 = [NSMutableData data];
        NSArchiver *archiver3 = [[NSArchiver alloc] initForWritingWithMutableData:buffer3];
        long long big = 1LL << 40;
        [archiver3 encodeValueOfObjCType:"q" at:&big];
        [archiver3 release];
        NSUnarchiver *unarchiver3 = [[NSUnarchiver alloc] initForReadingWithData:buffer3];
        long long big2 = 0;
        [unarchiver3 decodeValueOfObjCType:"q" at:&big2 size:sizeof big2];
        CHECK(big2 == (1LL << 40));
        [unarchiver3 release];
    }
    if (failures != 0) { printf("%d failures\n", failures); return 1; }
    printf("PASS: NSCoder decodeValueOfObjCType:at:size:\n");
    return 0;
}
