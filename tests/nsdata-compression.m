// -[NSData compressedDataUsingAlgorithm:error:] and -[NSData decompressedDataUsingAlgorithm:error:] are documented
// (developer.apple.com/documentation/foundation/nsdata/compressed(using:) and .../decompressed(using:), shown as
// compressedDataUsingAlgorithm:error: and decompressedDataUsingAlgorithm:error: in the Objective-C language variant) as
// returning a new data object with the compressed or decompressed bytes, available since macOS 10.15; decompressing restores
// data compressed with the same algorithm, and on failure the result is nil with an NSError describing the failure. The
// algorithms are the NSDataCompressionAlgorithm cases LZFSE, LZ4, LZMA and Zlib (.../nsdata/compressionalgorithm). The pages
// do not state the error domain or codes, or what empty data does; those checks are marked GUESS. They do not give the
// integer values of the cases either; those were observed on a real Mac (LZFSE 0, LZ4 1, LZMA 2, Zlib 3). Only LZFSE and Zlib are exercised: they are the algorithms the libcompression of this tree implements.
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

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
    // GUESS: the pages are silent about empty data. Compressing gives a stream that decompresses to empty data.
    NSData *emptyPacked = nil;
    NSData *emptyBack = roundTrip(name, "GUESS: empty data", [NSData data], algorithm, &emptyPacked);
    reportFor(name, "GUESS: empty data round trip is empty, not nil", emptyBack != nil && [emptyBack length] == 0);

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

    // Documented: failure gives nil and an error. GUESS: NSCocoaErrorDomain, code 5377 (decompression failed).
    NSMutableData *garbage = [NSMutableData dataWithLength:64];
    memset([garbage mutableBytes], 0xFF, [garbage length]);
    NSError *error = nil;
    NSData *rejected = [garbage decompressedDataUsingAlgorithm:algorithm error:&error];
    reportFor(name, "garbage does not decompress", rejected == nil);
    reportFor(name, "garbage sets *error", error != nil);
    reportFor(name, "GUESS: the garbage error is NSCocoaErrorDomain", [[error domain] isEqual:NSCocoaErrorDomain]);
    reportFor(name, "GUESS: the garbage error code is 5377", [error code] == 5377);

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
    reportFor(name, "the result for an NSMutableData receiver is mutable", [mutablePacked respondsToSelector:@selector(setLength:)]);
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
        exercise("Zlib", NSDataCompressionAlgorithmZlib);

        // GUESS: an algorithm value outside the four documented cases is a compression failure: nil and an NSError,
        // NSCocoaErrorDomain code 5376.
        NSError *error = nil;
        NSData *refused = [[NSData data] compressedDataUsingAlgorithm:(NSDataCompressionAlgorithm)99 error:&error];
        report("GUESS: an unknown algorithm does not compress", refused == nil);
        report("GUESS: the unknown-algorithm error is NSCocoaErrorDomain code 5376",
               [[error domain] isEqual:NSCocoaErrorDomain] && [error code] == 5376);
    }
    return failures != 0;
}
