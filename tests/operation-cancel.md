# Starting cancelled operations

Build `operation-cancel.m` as an Objective-C executable linked to Foundation
and libdispatch, then run with the candidate Foundation. Assertions remain
enabled with NDEBUG. The test covers direct pre-cancelled start, one finished
KVO notification and no executing notification, waitUntilFinished, a normal
operation control, and an operation cancelled while its queue is suspended.
The latter must skip main, invoke its completion block within five seconds,
and allow waitUntilAllOperationsAreFinished to return.

Expected marker: `PASS: cancelled operation skips main and reaches finished`.

ARM64 guest validation used 240 rebuilt Foundation units, refreshed
CoreFoundation, and otherwise staged dependencies. Existing duplicate AppKit
layout-class warnings remain. This is not a test of cancellation racing with
execution, custom asynchronous subclasses, or general queue synchronization.
