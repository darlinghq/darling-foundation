/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSAffineTransform archives: a transform whose matrix part is the identity
 * but that carries a translation (or any other non-identity value) must be
 * archived, the keyed NSTransformStruct data must use the forms macOS writes
 * (big-endian floats; no value for the identity, 9 bytes for a pure
 * translation or scale, 16 bytes without shear, else 24), sequential
 * archives hold six floats, and equal transforms hash equally. The fixtures
 * below were written by macOS 26.7.3 and read back on Mac OS X 10.14.4
 * (same data on both).
 */
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static int failures;
#define CHECK(c) do { if (!(c)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

typedef struct { double v[6]; } M6;

static NSAffineTransform *make(M6 m) {
    NSAffineTransform *t = [NSAffineTransform transform];
    NSAffineTransformStruct s = { m.v[0], m.v[1], m.v[2], m.v[3], m.v[4], m.v[5] };
    [t setTransformStruct: s];
    return t;
}

static BOOL sameStruct(NSAffineTransform *t, M6 m) {
    NSAffineTransformStruct s = [t transformStruct];
    return s.m11 == m.v[0] && s.m12 == m.v[1] && s.m21 == m.v[2]
        && s.m22 == m.v[3] && s.tX == m.v[4] && s.tY == m.v[5];
}

static NSData *fromHex(const char *h) {
    NSMutableData *d = [NSMutableData data];
    for (; h[0] && h[1]; h += 2) {
        unsigned int b;
        sscanf(h, "%2x", &b);
        uint8_t c = b;
        [d appendBytes: &c length: 1];
    }
    return d;
}

static NSString *hexOf(NSData *d) {
    NSMutableString *s = [NSMutableString string];
    const uint8_t *b = [d bytes];
    for (NSUInteger i = 0; i < [d length]; i++) [s appendFormat: @"%02x", b[i]];
    return s;
}

/* The NSTransformStruct value stored in a keyed archive, nil if absent. */
static NSData *storedStruct(NSData *archive) {
    NSDictionary *pl = [NSPropertyListSerialization propertyListWithData: archive options: 0 format: NULL error: NULL];
    for (id o in pl[@"$objects"])
        if ([o isKindOfClass: [NSDictionary class]] && o[@"NSTransformStruct"]) return o[@"NSTransformStruct"];
    return nil;
}

static NSAffineTransform *roundTripKeyed(NSAffineTransform *t, BOOL secure) {
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *a = [[NSKeyedArchiver alloc] initForWritingWithMutableData: data];
    [a setRequiresSecureCoding: secure];
    [a encodeObject: t forKey: @"root"];
    [a finishEncoding];
    [a release];
    NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingWithData: data];
    [u setRequiresSecureCoding: secure];
    NSAffineTransform *r = [u decodeObjectOfClass: [NSAffineTransform class] forKey: @"root"];
    [u finishDecoding];
    [u release];
    return r;
}

static void checkArchive(const char *name, M6 m, const char *expectHex) {
    NSAffineTransform *t = make(m);
    NSData *arc = [NSKeyedArchiver archivedDataWithRootObject: t];
    NSData *stored = storedStruct(arc);
    if (expectHex == NULL) {
        if (stored) fprintf(stderr, "FAIL %s: identity wrote %s\n", name, [hexOf(stored) UTF8String]);
        CHECK(stored == nil);
    } else {
        if (!stored || ![hexOf(stored) isEqualToString: [NSString stringWithUTF8String: expectHex]])
            fprintf(stderr, "FAIL %s: stored %s expected %s\n", name, stored ? [hexOf(stored) UTF8String] : "(none)", expectHex);
        CHECK(stored && [hexOf(stored) isEqualToString: [NSString stringWithUTF8String: expectHex]]);
    }
    for (int secure = 0; secure < 2; secure++) {
        NSAffineTransform *back = roundTripKeyed(t, secure);
        if (!back || !sameStruct(back, m)) fprintf(stderr, "FAIL %s: keyed round trip (secure %d) lost the matrix\n", name, secure);
        CHECK(back && sameStruct(back, m));
    }
    NSAffineTransform *seq = [NSUnarchiver unarchiveObjectWithData: [NSArchiver archivedDataWithRootObject: t]];
    if (!seq || !sameStruct(seq, m)) fprintf(stderr, "FAIL %s: NSArchiver round trip lost the matrix\n", name);
    CHECK(seq && sameStruct(seq, m));
}

static void mutators(void) {
    /* Every way to get a translation-only matrix must be archived. */
    NSAffineTransform *t;
    M6 trans = {{1,0,0,1,5,7}};
    const char *hex = "0140a0000040e00000";

    t = [NSAffineTransform transform];
    [t translateXBy: 5 yBy: 7];
    CHECK(sameStruct(t, trans));
    CHECK([storedStruct([NSKeyedArchiver archivedDataWithRootObject: t]) isEqual: fromHex(hex)]);

    t = [NSAffineTransform transform];
    NSAffineTransform *tr = [NSAffineTransform transform];
    [tr translateXBy: 5 yBy: 7];
    [t appendTransform: tr];
    CHECK([storedStruct([NSKeyedArchiver archivedDataWithRootObject: t]) isEqual: fromHex(hex)]);

    t = [NSAffineTransform transform];
    [t prependTransform: tr];
    CHECK([storedStruct([NSKeyedArchiver archivedDataWithRootObject: t]) isEqual: fromHex(hex)]);

    t = [[tr copy] autorelease];
    CHECK([storedStruct([NSKeyedArchiver archivedDataWithRootObject: t]) isEqual: fromHex(hex)]);
    t = [[[NSAffineTransform alloc] initWithTransform: tr] autorelease];
    CHECK([storedStruct([NSKeyedArchiver archivedDataWithRootObject: t]) isEqual: fromHex(hex)]);

    /* invert of a translation is a translation */
    t = [[tr copy] autorelease];
    [t invert];
    CHECK(sameStruct(t, ((M6){{1,0,0,1,-5,-7}})));
    CHECK(storedStruct([NSKeyedArchiver archivedDataWithRootObject: t]) != nil);

    /* a translation that cancels out is the identity again */
    t = [[tr copy] autorelease];
    [t translateXBy: -5 yBy: -7];
    CHECK(storedStruct([NSKeyedArchiver archivedDataWithRootObject: t]) == nil);

    /* scaleBy: 1 and a full set of no-ops keep the identity unarchived */
    t = [NSAffineTransform transform];
    [t scaleBy: 1];
    CHECK(storedStruct([NSKeyedArchiver archivedDataWithRootObject: t]) == nil);
}

static void equality(void) {
    NSAffineTransform *a = make((M6){{1,0,0,1,5,7}});
    NSAffineTransform *b = [NSAffineTransform transform];
    [b translateXBy: 5 yBy: 7];
    CHECK([a isEqual: b]);
    CHECK([a hash] == [b hash]);
    CHECK(![a isEqual: make((M6){{1,0,0,1,6,7}})]);
    CHECK(![a isEqual: nil]);
    CHECK(![a isEqual: @"x"]);
    CHECK([a isEqual: [[a copy] autorelease]]);
    /* -0 equals 0 and hashes the same */
    NSAffineTransform *z = make((M6){{1,0,0,1,0,0}});
    NSAffineTransform *nz = make((M6){{1,-0.0,-0.0,1,-0.0,0}});
    CHECK([z isEqual: nz]);
    CHECK([z hash] == [nz hash]);
    /* a flip applied twice is the identity */
    NSAffineTransform *f = [NSAffineTransform transform];
    [f scaleXBy: 1 yBy: -1];
    [f scaleXBy: 1 yBy: -1];
    CHECK([f isEqual: [NSAffineTransform transform]]);
    CHECK([f hash] == [[NSAffineTransform transform] hash]);
    /* NaN compares unequal to a different object holding NaN */
    NSAffineTransform *n1 = make((M6){{1,0,0,1,0.0/0.0,0}});
    CHECK(![n1 isEqual: make((M6){{1,0,0,1,0.0/0.0,0}})]);
}

static const struct { const char *name; M6 m; const char *hex; } keyedFixtures[] = {
    { "translation (5,7)", {1,0,0,1,5,7},
    "62706c6973743030d4010203040506070a582476657273696f6e592461726368"
    "697665725424746f7058246f626a6563747312000186a05f100f4e534b657965"
    "644172636869766572d1080954726f6f748001a30b0c1155246e756c6cd20d0e"
    "0f105f10114e535472616e73666f726d5374727563745624636c617373490140"
    "a0000040e000008002d2121314155a24636c6173736e616d655824636c617373"
    "65735f10114e53416666696e655472616e73666f726da216175f10114e534166"
    "66696e655472616e73666f726d584e534f626a65637408111a24293237494c51"
    "53575d62767d87898e99a2b6b9cd000000000000010100000000000000180000"
    "00000000000000000000000000d6" },
    { "scale (2,3)", {2,0,0,3,0,0},
    "62706c6973743030d4010203040506070a582476657273696f6e592461726368"
    "697665725424746f7058246f626a6563747312000186a05f100f4e534b657965"
    "644172636869766572d1080954726f6f748001a30b0c1155246e756c6cd20d0e"
    "0f105f10114e535472616e73666f726d5374727563745624636c617373490240"
    "000000404000008002d2121314155a24636c6173736e616d655824636c617373"
    "65735f10114e53416666696e655472616e73666f726da216175f10114e534166"
    "66696e655472616e73666f726d584e534f626a65637408111a24293237494c51"
    "53575d62767d87898e99a2b6b9cd000000000000010100000000000000180000"
    "00000000000000000000000000d6" },
    { "scale and translation", {2,0,0,3,10,21},
    "62706c6973743030d4010203040506070a582476657273696f6e592461726368"
    "697665725424746f7058246f626a6563747312000186a05f100f4e534b657965"
    "644172636869766572d1080954726f6f748001a30b0c1155246e756c6cd20d0e"
    "0f105f10114e535472616e73666f726d5374727563745624636c6173734f1010"
    "40000000404000004120000041a800008002d2121314155a24636c6173736e61"
    "6d655824636c61737365735f10114e53416666696e655472616e73666f726da2"
    "16175f10114e53416666696e655472616e73666f726d584e534f626a65637408"
    "111a24293237494c5153575d62767d909297a2abbfc2d6000000000000010100"
    "00000000000018000000000000000000000000000000df" },
    { "flip and translation", {1,0,0,-1,5,-7},
    "62706c6973743030d4010203040506070a582476657273696f6e592461726368"
    "697665725424746f7058246f626a6563747312000186a05f100f4e534b657965"
    "644172636869766572d1080954726f6f748001a30b0c1155246e756c6cd20d0e"
    "0f105f10114e535472616e73666f726d5374727563745624636c6173734f1010"
    "3f800000bf80000040a00000c0e000008002d2121314155a24636c6173736e61"
    "6d655824636c61737365735f10114e53416666696e655472616e73666f726da2"
    "16175f10114e53416666696e655472616e73666f726d584e534f626a65637408"
    "111a24293237494c5153575d62767d909297a2abbfc2d6000000000000010100"
    "00000000000018000000000000000000000000000000df" },
    { "shear", {1,0.5,0.25,1,0,0},
    "62706c6973743030d4010203040506070a582476657273696f6e592461726368"
    "697665725424746f7058246f626a6563747312000186a05f100f4e534b657965"
    "644172636869766572d1080954726f6f748001a30b0c1155246e756c6cd20d0e"
    "0f105f10114e535472616e73666f726d5374727563745624636c6173734f1018"
    "3f8000003f0000003e8000003f80000000000000000000008002d2121314155a"
    "24636c6173736e616d655824636c61737365735f10114e53416666696e655472"
    "616e73666f726da216175f10114e53416666696e655472616e73666f726d584e"
    "534f626a65637408111a24293237494c5153575d62767d989a9faab3c7cade00"
    "000000000001010000000000000018000000000000000000000000000000e7" }
};
static const struct { const char *name; M6 m; const char *hex; } streamFixtures[] = {
    { "translation (5,7)", {1,0,0,1,5,7},
    "040b73747265616d747970656481e803840140848484114e53416666696e6554"
    "72616e73666f726d018484084e534f626a656374008584045b36665d01000001"
    "050786" },
    { "shear", {1,0.5,0.25,1,0,0},
    "040b73747265616d747970656481e803840140848484114e53416666696e6554"
    "72616e73666f726d018484084e534f626a656374008584045b36665d01830000"
    "003f830000803e01000086" }
};

static void fixtures(void) {
    for (size_t i = 0; i < sizeof(keyedFixtures) / sizeof(keyedFixtures[0]); i++) {
        NSAffineTransform *t = nil;
        @try { t = [NSKeyedUnarchiver unarchiveObjectWithData: fromHex(keyedFixtures[i].hex)]; } @catch (id e) { }
        if (!t || !sameStruct(t, keyedFixtures[i].m)) fprintf(stderr, "FAIL macOS keyed archive: %s\n", keyedFixtures[i].name);
        CHECK(t && sameStruct(t, keyedFixtures[i].m));
        /* and writing the same transform reproduces the same value */
        NSData *mine = storedStruct([NSKeyedArchiver archivedDataWithRootObject: make(keyedFixtures[i].m)]);
        NSData *theirs = storedStruct(fromHex(keyedFixtures[i].hex));
        if (![mine isEqual: theirs]) fprintf(stderr, "FAIL keyed bytes differ from macOS: %s\n", keyedFixtures[i].name);
        CHECK([mine isEqual: theirs]);
    }
    for (size_t i = 0; i < sizeof(streamFixtures) / sizeof(streamFixtures[0]); i++) {
        NSAffineTransform *t = nil;
        @try { t = [NSUnarchiver unarchiveObjectWithData: fromHex(streamFixtures[i].hex)]; } @catch (id e) { }
        if (!t || !sameStruct(t, streamFixtures[i].m)) fprintf(stderr, "FAIL macOS NSArchiver stream: %s\n", streamFixtures[i].name);
        CHECK(t && sameStruct(t, streamFixtures[i].m));
        NSData *mine = [NSArchiver archivedDataWithRootObject: make(streamFixtures[i].m)];
        if (![hexOf(mine) isEqualToString: [NSString stringWithUTF8String: streamFixtures[i].hex]])
            fprintf(stderr, "FAIL NSArchiver bytes differ from macOS: %s\n  %s\n", streamFixtures[i].name, [hexOf(mine) UTF8String]);
        CHECK([hexOf(mine) isEqualToString: [NSString stringWithUTF8String: streamFixtures[i].hex]]);
    }
}

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    checkArchive("identity", (M6){{1,0,0,1,0,0}}, NULL);
    checkArchive("translation", (M6){{1,0,0,1,5,7}}, "0140a0000040e00000");
    checkArchive("scale", (M6){{2,0,0,3,0,0}}, "024000000040400000");
    checkArchive("flip", (M6){{1,0,0,-1,0,0}}, "023f800000bf800000");
    checkArchive("scale x only", (M6){{2,0,0,1,0,0}}, "02400000003f800000");
    checkArchive("scale and translation", (M6){{2,0,0,3,10,21}}, "40000000404000004120000041a80000");
    checkArchive("flip and translation", (M6){{1,0,0,-1,5,-7}}, "3f800000bf80000040a00000c0e00000");
    checkArchive("zero scale with translation", (M6){{0,0,0,0,1,1}}, "000000000000000" "03f8000003f800000");
    checkArchive("shear", (M6){{1,0.5,0.25,1,0,0}}, "3f8000003f0000003e8000003f800000" "0000000000000000");
    mutators();
    equality();
    fixtures();
    printf(failures ? "FAIL\n" : "PASS\n");
    [pool drain];
    return failures ? 1 : 0;
}
