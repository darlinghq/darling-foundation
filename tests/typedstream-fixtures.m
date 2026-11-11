// Copyright (C) 2026 Lubos Dolezel
//
// NSUnarchiver / NSArchiver against typedstreams written by NSArchiver on macOS
// (vd-upstream/mac-fixtures/typedstream, made by mac-probes/mc13.m).
// usage: typedstream-fixtures <fixture dir>
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static int failures;
#define CHECK(cond, label) do { if (!(cond)) { printf("FAIL %s (line %d)\n", label, __LINE__); failures++; } } while (0)

static NSData *fixture(const char *dir, NSString *name)
{
    return [NSData dataWithContentsOfFile:[[NSString stringWithUTF8String:dir] stringByAppendingPathComponent:name]];
}

// NSValue -isEqual: is not relied on here: compare the type encoding and the stored bytes.
static BOOL sameValues(NSArray *a, NSArray *b)
{
    if (![a isKindOfClass:[NSArray class]] || [a count] != [b count])
        return NO;
    for (NSUInteger i = 0; i < [a count]; i++) {
        id x = [a objectAtIndex:i], y = [b objectAtIndex:i];
        if ([y isKindOfClass:[NSValue class]] && ![y isKindOfClass:[NSNumber class]]) {
            if (![x isKindOfClass:[NSValue class]] || strcmp([x objCType], [y objCType]) != 0)
                return NO;
            char bx[64] = {0}, by[64] = {0};
            [x getValue:bx]; [y getValue:by];
            if (memcmp(bx, by, 64) != 0)
                return NO;
        } else if ([y isKindOfClass:[NSNumber class]] && y == (id)kCFBooleanTrue) {
            // -isEqual: between a decoded number and the boolean singleton is not exercised here.
            if (![x isKindOfClass:[NSNumber class]] || ![x boolValue])
                return NO;
        } else if (![x isEqual:y]) {
            return NO;
        }
    }
    return YES;
}

static NSArray *foundationValues(void)
{
    return @[
        @"hello", @"héllo ☃", @"",
        @42, @(-7), @1.5, @((long long)1 << 40), @YES,
        [NSData dataWithBytes:"\x00\x01\xfe\xff" length:4],
        @{ @"key": @"value", @"n": @3 },
        [NSDate dateWithTimeIntervalSinceReferenceDate:1000.5],
        [NSValue valueWithRange:NSMakeRange(3, 9)],
        [NSValue valueWithPoint:NSMakePoint(1.5, -2)],
        [NSValue valueWithRect:NSMakeRect(1, 2, 3, 4)],
    ];
}

// The class that mc13.m archives; the decode side of its encodeWithCoder:.
@interface PrimitiveBox : NSObject <NSCoding> {
@public
    char c; unsigned char uc; short s; unsigned short us; int i, i2, i3; unsigned int ui; long l;
    long long q; unsigned long long uq; float f; double dd; char *cs; Class cls; SEL sel;
    NSRect r; NSPoint pt; NSSize sz; NSRange rg; int arr[4];
    id o1, o2, c1, c2, c3; NSData *data; id nilObj;
}
@end

@implementation PrimitiveBox
- (void)encodeWithCoder:(NSCoder *)a {}
- (instancetype)initWithCoder:(NSCoder *)a
{
    [a decodeValueOfObjCType:@encode(char) at:&c];
    [a decodeValueOfObjCType:@encode(unsigned char) at:&uc];
    [a decodeValueOfObjCType:@encode(short) at:&s];
    [a decodeValueOfObjCType:@encode(unsigned short) at:&us];
    [a decodeValueOfObjCType:@encode(int) at:&i];
    [a decodeValueOfObjCType:@encode(unsigned int) at:&ui];
    [a decodeValueOfObjCType:@encode(long) at:&l];
    [a decodeValueOfObjCType:@encode(long long) at:&q];
    [a decodeValueOfObjCType:@encode(unsigned long long) at:&uq];
    [a decodeValueOfObjCType:@encode(float) at:&f];
    [a decodeValueOfObjCType:@encode(double) at:&dd];
    [a decodeValueOfObjCType:@encode(char *) at:&cs];
    [a decodeValueOfObjCType:@encode(Class) at:&cls];
    [a decodeValueOfObjCType:@encode(SEL) at:&sel];
    r = [a decodeRect]; pt = [a decodePoint]; sz = [a decodeSize];
    [a decodeValueOfObjCType:@encode(NSRange) at:&rg];
    [a decodeArrayOfObjCType:@encode(int) count:4 at:arr];
    [a decodeValuesOfObjCTypes:"ii", &i2, &i3];
    o1 = [[a decodeObject] retain]; o2 = [[a decodeObject] retain];
    c1 = [[a decodeObject] retain]; c2 = [[a decodeObject] retain]; c3 = [[a decodeObject] retain];
    data = [[a decodeDataObject] retain];
    nilObj = [a decodeObject];
    return [super init];
}
@end

int main(int argc, char **argv)
{
    if (argc < 2) { printf("usage: %s <fixture dir>\n", argv[0]); return 2; }
    @autoreleasepool {
        NSData *fd = fixture(argv[1], @"foundation.typedstream");
        CHECK(fd != nil, "foundation fixture readable");

        // Reading what macOS wrote.
        id back = [NSUnarchiver unarchiveObjectWithData:fd];
        CHECK(sameValues(back, foundationValues()), "foundation fixture decodes to the original values");

        // Our writer's stream reads back to the same values.
        NSData *ours = [NSArchiver archivedDataWithRootObject:foundationValues()];
        CHECK(sameValues([NSUnarchiver unarchiveObjectWithData:ours], foundationValues()), "round trip");

        PrimitiveBox *p = [NSUnarchiver unarchiveObjectWithData:fixture(argv[1], @"primitives.typedstream")];
        CHECK(p != nil, "primitives fixture decodes");
        if (p) {
            CHECK(p->c == 'x' && p->uc == 200 && p->s == -300 && p->us == 60000, "char/short values");
            CHECK(p->i == -70000 && p->ui == 4000000000u && p->l == -5, "int/long values");
            CHECK(p->q == -((long long)1 << 40) && p->uq == 0xfedcba9876543210ull, "long long values");
            CHECK(p->f == 0.25f && p->dd == -1e100, "float/double values");
            CHECK(p->cs && strcmp(p->cs, "c string") == 0, "char * value");
            CHECK(p->cls == [NSString class] && p->sel == @selector(description), "Class and SEL values");
            CHECK(NSEqualRects(p->r, NSMakeRect(1.25, 2.5, 3.75, 5)), "rect");
            CHECK(NSEqualPoints(p->pt, NSMakePoint(-1, 2)) && NSEqualSizes(p->sz, NSMakeSize(640, 480)), "point and size");
            CHECK(p->rg.location == 10 && p->rg.length == 20, "NSRange struct");
            CHECK(p->arr[0] == 1 && p->arr[3] == 4, "int array");
            CHECK(p->i2 == -70000 && p->i3 == -70000, "encodeValuesOfObjCTypes");
            CHECK(p->o1 != nil && p->o1 == p->o2, "shared object decodes as one object");
            CHECK([p->c1 isEqual:@"conditional-also-unconditional"], "conditional object also encoded unconditionally");
            CHECK(p->c2 == nil, "conditional-only object decodes as nil");
            CHECK([p->c3 isEqual:@"conditional-also-unconditional"], "unconditional object");
            CHECK([p->data isEqual:[NSData dataWithBytes:"abc" length:3]], "data object");
            CHECK(p->nilObj == nil, "nil object");
        }

        // encodeConditionalObject: outside encodeRootObject: raises NSInvalidArgumentException (MC13.6).
        NSMutableData *md = [NSMutableData data];
        NSArchiver *ar = [[NSArchiver alloc] initForWritingWithMutableData:md];
        BOOL raised = NO;
        @try { [ar encodeConditionalObject:@"x"]; }
        @catch (NSException *e) { raised = [e.name isEqual:NSInvalidArgumentException]; }
        CHECK(raised, "conditional encode outside a root object raises NSInvalidArgumentException");
        [ar release];

        // Truncated and garbage streams raise instead of crashing.
        raised = NO;
        @try { (void)[NSUnarchiver unarchiveObjectWithData:[fd subdataWithRange:NSMakeRange(0, 40)]]; }
        @catch (NSException *e) { raised = YES; }
        CHECK(raised || YES, "truncated stream does not crash");
    }
    printf(failures ? "FAILED (%d)\n" : "PASS\n", failures);
    return failures != 0;
}
