# NSString nil format raises

Build nsstring-nil-format-raises.m against Foundation/CoreFoundation and run it under Darling. Each format-taking method that the public documentation says raises `NSInvalidArgumentException` for a nil format (`+stringWithFormat:`, `+localizedStringWithFormat:`, `-initWithFormat:`, `-initWithFormat:arguments:`, `-initWithFormat:locale:`, `-initWithFormat:locale:arguments:`, `-stringByAppendingFormat:` and `-[NSMutableString appendFormat:]`) is called with a nil format and must raise that exception with a non-empty reason; a non-nil format must still format as before.

Baseline: a nil format reaches `CFStringGetLength(NULL)` inside CoreFoundation and the process crashes instead of raising; candidate: zero failures.
