# Absolute truncation offset

Build `truncate-offset.m` as an Objective-C executable linked to Foundation
and run with the candidate framework. It creates and immediately unlinks a
temporary file; assertions stay enabled even when NDEBUG is defined.

The test starts at a nonzero position, truncates, verifies both the size and
position, writes another byte to detect an unintended gap, extends the file
and verifies zero fill, then truncates to zero. Expected success marker:

`PASS: truncation position, subsequent write, extension and zero length`

The expected position is specified by
[Apple's method documentation](https://developer.apple.com/documentation/foundation/nsfilehandle/1411716-truncatefileatoffset?language=objc).
The new offset is absolute, not relative to the position before truncation.
