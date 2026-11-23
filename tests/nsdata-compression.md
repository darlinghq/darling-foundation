# NSData compression

Build nsdata-compression.m against Foundation/CoreFoundation and run it under Darling. It checks `-[NSData compressedDataUsingAlgorithm:error:]` and `-[NSData decompressedDataUsingAlgorithm:error:]` against the public documentation: instances of `NSData`, `NSMutableData` and CoreFoundation's bridged data class respond, LZFSE and Zlib round-trip a short string, 1 MB of repeating bytes (which compresses to fewer bytes) and 256 KB of pseudo-random bytes, garbage and a truncated stream do not decompress and set `*error`, and `error:NULL` is accepted on success and on failure.

Baseline: against the base commit the header has no `NSDataCompressionAlgorithm` and no declaration of either method (an error, then `-Wobjc-method-access` warnings), and the first call raises `unrecognized selector`; candidate: zero failures.

Only LZFSE and Zlib are exercised. They are the algorithms the libcompression of this tree implements; LZ4 and LZMA make both methods fail (nil with an error) until it does.

The error domain and codes (`NSCocoaErrorDomain`, 5376 for compression and 5377 for decompression), the empty-data round trip, and the failure for an algorithm value outside the four cases are not stated on the documentation pages; they are marked GUESS in the source. The raw values of the four enum cases (LZFSE 0, LZ4 1, LZMA 2, Zlib 3) are also not documented; they were observed on a real Mac with a small program printing the public constants, and the test asserts them.

The refusal of Zlib inputs of 4 GiB or more is not tested: it would need allocations of that size.
