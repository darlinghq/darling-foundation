# NSURLQueryItem

`url-query-item.m` exercises the public factory and initializer: input strings
are copied, nil and empty values differ, copies are the same object, equality
and hash are by value, keyed secure archiving round trips, and invalid strings
or unkeyed coders raise NSInvalidArgumentException. It prints a `PASS` line and
exits 0. Before the implementation the factory is an unrecognized selector.
