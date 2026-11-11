# Optional XML callbacks

Compile `xml-delegate.m` with this branch's Foundation headers and run with
the candidate framework. It parses nested valid XML with no delegate, an empty
delegate and an end-element-only delegate. The last receives both end events.
A sentinel exception thrown by a delegate must propagate, not become a parser
error. Assertions remain enabled with NDEBUG.

Success: `PASS: optional XML delegate callbacks and exception propagation`.

This does not validate malformed-document detection, namespace behavior or
abortParsing. Those existing parser issues are outside this callback fix.
