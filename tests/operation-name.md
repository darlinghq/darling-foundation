# Operation names

Compile `operation-name.m` against this branch's Foundation headers and run
with its framework. The regression checks initial nil, copy ownership from a
mutable string, per-object isolation, replacement, clearing, and exactly one
KVO notification per setter call. Assertions remain enabled with NDEBUG.

Success: `PASS: operation name copy ownership, isolation, clearing and KVO`.

ARM64 validation rebuilds all 240 Foundation units, using refreshed
CoreFoundation and otherwise staged dependencies. The baseline fails with an
unrecognized name selector; the candidate passes. Existing duplicate AppKit
layout-class warnings remain. No concurrent getter/setter stress, x86 runtime,
or clean whole-system build result is claimed.
