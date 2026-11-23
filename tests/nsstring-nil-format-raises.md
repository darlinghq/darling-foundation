# NSString nil format raises

Build nsstring-nil-format-raises.m against Foundation/CoreFoundation and run it under Darling. Each format-taking method that the public documentation says raises `NSInvalidArgumentException` for a nil format (`+stringWithFormat:`, `+localizedStringWithFormat:`, `-initWithFormat:`, `-initWithFormat:arguments:`, `-initWithFormat:locale:`, `-initWithFormat:locale:arguments:`, and `-stringByAppendingFormat:`) is called with a nil format and must raise that exception with the reason macOS gives (`*** -[<placeholder class> initWithFormat:locale:arguments:]: nil argument`, same on 10.14.4 and 26.7.3); a non-nil format must still format as before.

Baseline: a nil format reaches `CFStringGetLength(NULL)` inside CoreFoundation and the process crashes instead of raising; candidate: zero failures.

`-[NSMutableString appendFormat:]` is not covered by default: macOS 10.14.4 and 26.7.3 crash with a nil format (instead of raising as documented), and so does Darling for a CoreFoundation-backed mutable string, which does not go through the placeholder. Build with `-DCHECK_APPEND_FORMAT_NIL` to check it. The tests run unchanged on a Mac.
