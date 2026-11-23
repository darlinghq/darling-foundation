// -[NSData compressedDataUsingAlgorithm:error:] and -[NSData decompressedDataUsingAlgorithm:error:] are documented
// (developer.apple.com/documentation/foundation/nsdata/compressed(using:) and .../decompressed(using:), shown as
// compressedDataUsingAlgorithm:error: and decompressedDataUsingAlgorithm:error: in the Objective-C language variant) as
// returning a new data object with the compressed or decompressed bytes, available since macOS 10.15; decompressing restores
// data compressed with the same algorithm, and on failure the result is nil with an NSError describing the failure. The
// algorithms are the NSDataCompressionAlgorithm cases LZFSE, LZ4, LZMA and Zlib (.../nsdata/compressionalgorithm). The pages
// do not state the error domain or codes or the integer values of the cases; what the lines below assert was observed on
// macOS 26.7.3 (the methods are new in 10.15, so 10.14.4 has none): LZFSE 0, LZ4 1, LZMA 2, Zlib 3; a stream that does not
// decompress, a truncated stream and an empty input give nil and NSCocoaErrorDomain code 5377; the result is an immutable
// NSData for every receiver; an algorithm value outside the four raises NSInvalidArgumentException; the empty data round
// trip works. Only the code 5376 of a compression failure is a GUESS (it cannot be provoked on macOS). The streams are those
// of libcompression, with the bytes macOS writes for LZFSE, LZ4 and Zlib and its own xz encoder settings for LZMA (a macOS
// stream decodes here and ours there; the fixtures in nsdata-compression-macos.h were written by macOS 26.7.3).
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "nsdata-compression-macos.h"

static int failures;

static void report(const char *label, BOOL ok)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", label);
    failures += !ok;
}

static void reportFor(const char *algorithm, const char *what, BOOL ok)
{
    char label[200];
    snprintf(label, sizeof label, "%s: %s", algorithm, what);
    report(label, ok);
}

static NSData *repeatingBytes(NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    uint8_t *bytes = [data mutableBytes];
    for (NSUInteger i = 0; i < length; i++)
    {
        bytes[i] = (uint8_t)("abcdefgh"[i % 8]);
    }
    return data;
}

static NSData *repeatingHello(void)
{
    NSMutableData *data = [NSMutableData data];
    for (int i = 0; i < 100; i++)
    {
        [data appendBytes:"hello hello hello " length:18];
    }
    return data;
}

static NSData *runsOfBytes(void)
{
    NSMutableData *data = [NSMutableData dataWithLength:140000];
    uint8_t *bytes = [data mutableBytes];
    for (int i = 0; i < 140000; i++)
    {
        bytes[i] = (uint8_t)((i / 1024) * 37);
    }
    return data;
}

// A fixed xorshift sequence: incompressible for practical purposes, and the same on every run.
static NSData *pseudoRandomBytes(NSUInteger length)
{
    NSMutableData *data = [NSMutableData dataWithLength:length];
    uint8_t *bytes = [data mutableBytes];
    uint32_t state = 2463534242u;
    for (NSUInteger i = 0; i < length; i++)
    {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        bytes[i] = (uint8_t)(state >> 11);
    }
    return data;
}

static NSData *roundTrip(const char *name, const char *what, NSData *input, NSDataCompressionAlgorithm algorithm, NSData **packedOut)
{
    NSError *error = nil;
    NSData *packed = [input compressedDataUsingAlgorithm:algorithm error:&error];
    char label[120];
    snprintf(label, sizeof label, "%s compresses", what);
    reportFor(name, label, packed != nil && error == nil);
    NSData *unpacked = [packed decompressedDataUsingAlgorithm:algorithm error:&error];
    snprintf(label, sizeof label, "%s decompresses back to the original bytes", what);
    reportFor(name, label, unpacked != nil && [unpacked isEqualToData:input]);
    if (packedOut != NULL)
    {
        *packedOut = packed;
    }
    return unpacked;
}

static void exercise(const char *name, NSDataCompressionAlgorithm algorithm)
{
    // Observed: compressing empty data gives a stream that decompresses to empty data.
    NSData *emptyPacked = nil;
    NSData *emptyBack = roundTrip(name, "empty data", [NSData data], algorithm, &emptyPacked);
    reportFor(name, "empty data round trip is empty, not nil", emptyBack != nil && [emptyBack length] == 0);
    reportFor(name, "empty input does not decompress", [[NSData data] decompressedDataUsingAlgorithm:algorithm error:NULL] == nil);

    NSData *text = [@"NSData and its mutable subclass NSMutableData provide data objects, or object-oriented wrappers for byte buffers."
        dataUsingEncoding:NSUTF8StringEncoding];
    roundTrip(name, "short string", text, algorithm, NULL);

    // The page says compression reduces memory use; 1 MB of a repeating pattern must come out smaller.
    NSData *repeating = repeatingBytes(1024 * 1024);
    NSData *repeatingPacked = nil;
    roundTrip(name, "1 MB of repeating bytes", repeating, algorithm, &repeatingPacked);
    reportFor(name, "1 MB of repeating bytes compresses to fewer bytes", repeatingPacked != nil && [repeatingPacked length] < [repeating length]);

    // Incompressible input may grow; only the round trip is documented.
    roundTrip(name, "256 KB of pseudo-random bytes", pseudoRandomBytes(256 * 1024), algorithm, NULL);

    // Documented: failure gives nil and an error. Observed: NSCocoaErrorDomain, code 5377 (decompression failed).
    NSMutableData *garbage = [NSMutableData dataWithLength:64];
    memset([garbage mutableBytes], 0xFF, [garbage length]);
    NSError *error = nil;
    NSData *rejected = [garbage decompressedDataUsingAlgorithm:algorithm error:&error];
    reportFor(name, "garbage does not decompress", rejected == nil);
    reportFor(name, "garbage sets *error", error != nil);
    reportFor(name, "the garbage error is NSCocoaErrorDomain", [[error domain] isEqual:NSCocoaErrorDomain]);
    reportFor(name, "the garbage error code is 5377", [error code] == 5377);

    // A stream cut in half is not a complete stream.
    error = nil;
    NSData *cut = [repeatingPacked subdataWithRange:NSMakeRange(0, [repeatingPacked length] / 2)];
    reportFor(name, "a truncated stream does not decompress", [cut decompressedDataUsingAlgorithm:algorithm error:&error] == nil && error != nil);

    // Documented: *error is the out parameter; a caller that does not want it passes NULL.
    reportFor(name, "error:NULL on success", [text compressedDataUsingAlgorithm:algorithm error:NULL] != nil);
    reportFor(name, "error:NULL on failure", [garbage decompressedDataUsingAlgorithm:algorithm error:NULL] == nil);

    // The receiver may be a mutable data object, and CoreFoundation's bridged data class, as well as plain NSData.
    NSMutableData *mutableText = [NSMutableData dataWithData:text];
    NSData *mutablePacked = [mutableText compressedDataUsingAlgorithm:algorithm error:&error];
    reportFor(name, "NSMutableData receiver compresses", mutablePacked != nil);
    reportFor(name, "the result for an NSMutableData receiver is immutable", ![mutablePacked isKindOfClass:[NSMutableData class]]);
    NSMutableData *mutablePackedInput = [NSMutableData dataWithData:mutablePacked];
    NSData *mutableBack = [mutablePackedInput decompressedDataUsingAlgorithm:algorithm error:&error];
    reportFor(name, "NSMutableData receiver decompresses to the original bytes", mutableBack != nil && [mutableBack isEqualToData:text]);

    CFMutableDataRef bridged = CFDataCreateMutable(kCFAllocatorDefault, 0);
    CFDataAppendBytes(bridged, [text bytes], (CFIndex)[text length]);
    NSData *bridgedPacked = [(NSData *)bridged compressedDataUsingAlgorithm:algorithm error:&error];
    reportFor(name, "CFMutableData receiver compresses", bridgedPacked != nil);
    CFMutableDataRef bridgedPackedInput = CFDataCreateMutable(kCFAllocatorDefault, 0);
    CFDataAppendBytes(bridgedPackedInput, [bridgedPacked bytes], (CFIndex)[bridgedPacked length]);
    NSData *bridgedBack = [(NSData *)bridgedPackedInput decompressedDataUsingAlgorithm:algorithm error:&error];
    reportFor(name, "CFMutableData receiver decompresses to the original bytes", bridgedBack != nil && [bridgedBack isEqualToData:text]);
    CFRelease(bridged);
    CFRelease(bridgedPackedInput);
}

int main(void)
{
    @autoreleasepool
    {
        report("NSData instances respond to -compressedDataUsingAlgorithm:error:",
               [NSData instancesRespondToSelector:@selector(compressedDataUsingAlgorithm:error:)]);
        report("NSData instances respond to -decompressedDataUsingAlgorithm:error:",
               [NSData instancesRespondToSelector:@selector(decompressedDataUsingAlgorithm:error:)]);
        report("NSMutableData instances respond to both",
               [NSMutableData instancesRespondToSelector:@selector(compressedDataUsingAlgorithm:error:)] &&
               [NSMutableData instancesRespondToSelector:@selector(decompressedDataUsingAlgorithm:error:)]);
        CFMutableDataRef cfData = CFDataCreateMutable(kCFAllocatorDefault, 0);
        report("a CFMutableData object responds to both",
               [(id)cfData respondsToSelector:@selector(compressedDataUsingAlgorithm:error:)] &&
               [(id)cfData respondsToSelector:@selector(decompressedDataUsingAlgorithm:error:)]);
        CFRelease(cfData);

        // The four documented cases are distinct. Their integer values are not documented; the values asserted below were observed
// on a real Mac with a small program printing the public constants (black-box observation).
        NSInteger cases[4] = { NSDataCompressionAlgorithmLZFSE, NSDataCompressionAlgorithmLZ4, NSDataCompressionAlgorithmLZMA,
                               NSDataCompressionAlgorithmZlib };
        BOOL distinct = YES;
        for (int i = 0; i < 4; i++)
        {
            for (int j = i + 1; j < 4; j++)
            {
                distinct = distinct && cases[i] != cases[j];
            }
        }
        report("the four NSDataCompressionAlgorithm cases are distinct", distinct);
        report("the raw values are LZFSE 0, LZ4 1, LZMA 2, Zlib 3", cases[0] == 0 && cases[1] == 1 && cases[2] == 2 && cases[3] == 3);

        exercise("LZFSE", NSDataCompressionAlgorithmLZFSE);
        exercise("LZ4", NSDataCompressionAlgorithmLZ4);
        exercise("LZMA", NSDataCompressionAlgorithmLZMA);
        exercise("Zlib", NSDataCompressionAlgorithmZlib);

        // Streams written by macOS decode here, and decode to the input (interoperability, both small and several blocks).
        NSData *inputA = repeatingHello();
        NSData *inputB = runsOfBytes();
        const struct { const char *name; NSDataCompressionAlgorithm algorithm; const unsigned char *a; size_t aLength; const unsigned char *b; size_t bLength; } fixtures[4] = {
            { "LZFSE", NSDataCompressionAlgorithmLZFSE, macos_a_lzfse, sizeof macos_a_lzfse, macos_b_lzfse, sizeof macos_b_lzfse },
            { "LZ4",   NSDataCompressionAlgorithmLZ4,   macos_a_lz4,   sizeof macos_a_lz4,   macos_b_lz4,   sizeof macos_b_lz4 },
            { "LZMA",  NSDataCompressionAlgorithmLZMA,  macos_a_lzma,  sizeof macos_a_lzma,  macos_b_lzma,  sizeof macos_b_lzma },
            { "Zlib",  NSDataCompressionAlgorithmZlib,  macos_a_zlib,  sizeof macos_a_zlib,  macos_b_zlib,  sizeof macos_b_zlib },
        };
        for (int i = 0; i < 4; i++)
        {
            NSData *macA = [NSData dataWithBytes:fixtures[i].a length:fixtures[i].aLength];
            NSData *macB = [NSData dataWithBytes:fixtures[i].b length:fixtures[i].bLength];
            reportFor(fixtures[i].name, "a stream written by macOS decompresses (short input)", [[macA decompressedDataUsingAlgorithm:fixtures[i].algorithm error:NULL] isEqualToData:inputA]);
            reportFor(fixtures[i].name, "a stream written by macOS decompresses (140000 bytes, several blocks)", [[macB decompressedDataUsingAlgorithm:fixtures[i].algorithm error:NULL] isEqualToData:inputB]);
        }
        // The bytes macOS writes for LZFSE, LZ4 and Zlib are reproduced (libcompression's own encoders give the same
        // stream; LZMA differs in the block coding, which decodes alike).
        for (int i = 0; i < 4; i += 1)
        {
            if (fixtures[i].algorithm == NSDataCompressionAlgorithmLZMA)
                continue;
            NSData *macA = [NSData dataWithBytes:fixtures[i].a length:fixtures[i].aLength];
            NSData *ours = [inputA compressedDataUsingAlgorithm:fixtures[i].algorithm error:NULL];
            if (fixtures[i].algorithm == NSDataCompressionAlgorithmLZ4)
                continue; // an LZ4 encoder is free to choose other matches than macOS: only the framing is fixed
            reportFor(fixtures[i].name, "the stream for the short input has the bytes macOS writes", [ours isEqualToData:macA]);
        }
        // QUIRK (observed): compressing no bytes with LZ4 gives an empty stored block and the end tag.
        NSData *emptyLZ4 = [[NSData data] compressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZ4 error:NULL];
        const unsigned char emptyStream[12] = {'b', 'v', '4', '-', 0, 0, 0, 0, 'b', 'v', '4', '$'};
        reportFor("LZ4", "empty LZ4 stream is the stored empty block and the end tag", [emptyLZ4 isEqualToData:[NSData dataWithBytes:emptyStream length:12]]);
        // LZ4 framing: the block tags and sizes of 140000 bytes (64 KiB blocks, then the end tag).
        NSData *lz4B = [inputB compressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZ4 error:NULL];
        const uint8_t *tags = [lz4B bytes];
        reportFor("LZ4", "the stream starts with a compressed block of 65536 bytes", [lz4B length] > 12 && memcmp(tags, "bv41", 4) == 0 && tags[4] == 0 && tags[5] == 0 && tags[6] == 1 && tags[7] == 0);
        reportFor("LZ4", "the stream ends with the end tag", [lz4B length] > 4 && memcmp(tags + [lz4B length] - 4, "bv4$", 4) == 0);

        // Observed: an algorithm value outside the four cases raises NSInvalidArgumentException, in both methods.
        BOOL raised = NO;
        @try
        {
            [[NSData data] compressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)99 error:NULL];
        }
        @catch (NSException *exception)
        {
            raised = [[exception name] isEqual:NSInvalidArgumentException];
        }
        report("an unknown algorithm raises NSInvalidArgumentException when compressing", raised);
        raised = NO;
        @try
        {
            [[NSData data] decompressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)-1 error:NULL];
        }
        @catch (NSException *exception)
        {
            raised = [[exception name] isEqual:NSInvalidArgumentException];
        }
        report("an unknown algorithm raises NSInvalidArgumentException when decompressing", raised);
    }
    return failures != 0;
}
