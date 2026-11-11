# Allowed-character percent encoding

Build `percent-encoding.m` as an Objective-C executable using this branch's
Foundation headers and run with the candidate Foundation. The URL-component
integration cases also require the character-set methods from CoreFoundation
PR #27. Custom-set cases do not depend on those methods.

Tests cover ASCII passthrough/escaping, combining marks next to allowed ASCII,
non-ASCII members ignored in the allowed set, supplementary characters, empty
strings, embedded NUL, existing percent escapes, malformed UTF-16 returning nil,
and path/query set differences. Assertions remain enabled with NDEBUG.

Expected marker: `PASS: percent encoding ASCII, combining marks, non-ASCII and embedded NUL`.

The [documented contract](https://developer.apple.com/documentation/foundation/nsstring/addingpercentencoding%28withallowedcharacters%3A%29?language=objc)
requires UTF-8 percent encoding and ignores non-ASCII allowed-set members.
Do not process whole grapheme clusters as all-or-nothing: an allowed ASCII
base character must remain unescaped even beside a non-ASCII combining mark.

Validation uses 240 rebuilt ARM64 Foundation units, refreshed CoreFoundation
and otherwise staged dependencies. Existing AppKit duplicate layout-class
warnings remain. This is not a clean whole-system rebuild or native macOS/x86
runtime validation.
