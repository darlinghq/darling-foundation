# Symbolic-link argument order

Compile `symlink-order.m` as an Objective-C executable linked to Foundation and
run it with the candidate framework. It uses an isolated temporary directory
and removes its fixtures after success. Assertions remain enabled with NDEBUG.

The test covers an existing absolute target, an existing-link error, a relative
dangling destination stored verbatim, and preservation of the target's data.
Success prints `PASS: symbolic-link location, destination text and target preservation`.

Validation on ARM64 Darling: the unmodified staged framework fails the first
link-creation assertion; all 240 candidate Foundation units compile and link,
and the same guest test passes with the candidate Foundation and refreshed
CoreFoundation. The latter supplies symbols required by current Foundation
that the old staged CoreFoundation lacks. Other dependencies remain staged;
duplicate layout-class warnings from staged AppKit are present. No clean
whole-system rebuild or x86/macOS runtime validation is claimed.
