// Copyright (C) 2026 Lubos Dolezel
//
// NSUnarchiver -decodeBytesWithReturnedLength: on the modern byte-run form and on the legacy NeXT form.
// The modern form is produced by NSArchiver -encodeBytes:length:. The legacy form is built by hand from the
// layout the typedstream reader documents for old archives: an "i" type label, the length as an int, a
// "[<length>c]" array type label, then the raw bytes. It is a synthetic stream, not a capture from an old system.
// Built without ARC.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static int failures;

static void expect(BOOL ok, const char *what)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok)
        failures++;
}

static NSData *streamWithBody(const char *body, size_t bodyLength)
{
    // typedstream header: version 4, "streamtyped", then the 0x81 0xe8 0x03 system version.
    static const unsigned char header[] = { 0x04, 0x0b, 's', 't', 'r', 'e', 'a', 'm', 't', 'y', 'p', 'e', 'd', 0x81, 0xe8, 0x03 };
    NSMutableData *data = [NSMutableData dataWithBytes:header length:sizeof(header)];
    [data appendBytes:body length:bodyLength];
    return data;
}

// A new label: 0x84, its length, its characters.
static void appendLabel(NSMutableData *data, const char *label)
{
    unsigned char marker[2] = { 0x84, (unsigned char)strlen(label) };
    [data appendBytes:marker length:2];
    [data appendBytes:label length:strlen(label)];
}

static NSData *legacyStream(const char *arrayLabel, unsigned char length, const char *bytes, size_t byteCount)
{
    NSMutableData *body = [NSMutableData data];
    appendLabel(body, "i");
    [body appendBytes:&length length:1];
    appendLabel(body, arrayLabel);
    [body appendBytes:bytes length:byteCount];
    return streamWithBody([body bytes], [body length]);
}

static BOOL decodes(NSData *stream, const char *expected, size_t expectedLength)
{
    NSUnarchiver *unarchiver = [[NSUnarchiver alloc] initForReadingWithData:stream];
    NSUInteger length = 0;
    void *bytes = [unarchiver decodeBytesWithReturnedLength:&length];
    BOOL ok = bytes != NULL && length == expectedLength && memcmp(bytes, expected, expectedLength) == 0;
    [unarchiver release];
    return ok;
}

static BOOL failsToDecode(NSData *stream)
{
    NSUnarchiver *unarchiver = [[NSUnarchiver alloc] initForReadingWithData:stream];
    NSUInteger length = 99;
    void *bytes = [unarchiver decodeBytesWithReturnedLength:&length];
    [unarchiver release];
    return bytes == NULL;
}

int main(void)
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    NSMutableData *modern = [NSMutableData data];
    NSArchiver *archiver = [[NSArchiver alloc] initForWritingWithMutableData:modern];
    [archiver encodeBytes:"ABC" length:3];
    [archiver release];
    expect(decodes(modern, "ABC", 3), "the modern byte run still decodes");

    expect(decodes(legacyStream("[3c]", 3, "ABC", 3), "ABC", 3), "a legacy byte array decodes");
    expect(decodes(legacyStream("[5c]", 5, "hello", 5), "hello", 5), "a legacy byte array of another length decodes");
    expect(failsToDecode(legacyStream("[4c]", 3, "ABC", 3)), "an array type that does not match the length is refused");
    expect(failsToDecode(legacyStream("[3i]", 3, "ABC", 3)), "an array type of another element is refused");
    expect(failsToDecode(legacyStream("[3c]", 3, "AB", 2)), "a legacy array cut short is refused");

    NSMutableData *other = [NSMutableData data];
    appendLabel(other, "q");
    expect(failsToDecode(streamWithBody([other bytes], [other length])), "a label that is neither form is refused");

    [pool drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
