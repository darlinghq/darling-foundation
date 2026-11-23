# NSConnection enableMultipleThreads

Build nsconnection-enable-multiple-threads.m against Foundation and run it under Darling. It checks the documented pair `-multipleThreadsEnabled` (readonly BOOL, default YES) and `-enableMultipleThreads` (documented to do nothing on macOS 10.5 and later, because multiple-thread support is already on) on connections made with `-initWithReceivePort:sendPort:`, `-init` and `+defaultConnection`: both selectors are answered, the getter reads YES before and after the call, the call does not raise, there is no `-setMultipleThreadsEnabled:`, a connection that never received the call also reads YES, and a child connection reads YES. No server or second process is needed.

Baseline: against the headers of the previous commit the test does not build (property `multipleThreadsEnabled` not found on NSConnection); a build that skips the header check raises `unrecognized selector` on the first `-enableMultipleThreads` call and the `respondsToSelector:` checks fail. Candidate: zero failures.

Only the reported value and the absence of an exception are tested. That several threads can actually share one connection (a request waits for its reply on the calling thread's run loop) is what the implementation relies on; it is not exercised here because it needs a served object.

The checks that a repeated `-enableMultipleThreads` call does not raise and leaves the getter at YES, and that the getter reads YES after `-invalidate`, are marked GUESS in the source: the pages say only that the method does nothing and give YES as the default.
