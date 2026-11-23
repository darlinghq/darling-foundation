# NSScriptCommand currentCommand

Build nsscriptcommand-currentcommand.m against Foundation/CoreFoundation and run it under Darling. It checks `+[NSScriptCommand currentCommand]` against the public documentation, which says the method returns the command being executed on the current thread by Cocoa scripting's Apple event handling and nil otherwise. Nothing in this Foundation executes a script command, so every call is outside execution and must return nil without raising: from the main thread, from a pthread, and from a block dispatched to the main queue (the failing call pattern). It also checks `respondsToSelector:` on the class.

Baseline: against the base headers the call builds only with an undeclared-method warning, and it raises `unrecognized selector` (the class has instance-side message forwarding only), so every nil check and the `respondsToSelector:` check fail; candidate: zero failures. Not run under Darling.

The subclass checks (`NSCreateCommand`, `NSCloneCommand`, `NSDeleteCommand` and `NSMoveCommand` inherit the class method) are not stated on the documentation page and are marked GUESS in the source. The test cannot cover the documented non-nil case (a command executing) because no code here can execute one.
