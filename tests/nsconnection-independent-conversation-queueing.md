# NSConnection independentConversationQueueing

Build nsconnection-independent-conversation-queueing.m against Foundation and run it under Darling. It checks the documented BOOL property pair `-independentConversationQueueing` / `-setIndependentConversationQueueing:` on connections made with `-initWithReceivePort:sendPort:`, `-init` and `+defaultConnection`: both selectors are answered, the default is NO, setting YES reads back YES and setting NO reads back NO (message and dot syntax), changing one connection does not change another, a connection made with the parent's receive port as both ports (documented as its parent, whose configuration settings are applied to the new connection) copies the flag, and one with no parent starts at NO. No server or second process is needed.

Baseline: the test does not build against the headers of the base commit (property not found on NSConnection), and a build that skips the header check raises `unrecognized selector` at the first call and every `respondsToSelector:` check fails; candidate: zero failures.

Only the stored value and its copy from a parent are tested. The flag is documented as making a connection forward incoming remote messages only when no other is being handled in its thread; Foundation here has no such queue, so that effect is neither implemented nor tested.

The check that changing the parent afterwards leaves the child unchanged is marked GUESS in the source: the page says only that the parent's settings are applied to the new connection, so copying once at creation (as the timeouts already are) is an inference.
