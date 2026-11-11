# NSURLComponents query items

`urlcomponents-query.m` builds NSURLComponents from URLs and strings and checks
that query items keep their order, are percent-decoded, keep a valueless item
distinct from an empty value, and keep an absent query distinct from an empty
one. It also checks the queryItems setter round trip, the scheme and host
getters, and relative URL resolution. It prints a `PASS` line and exits 0.
Before the implementation the class has no URL factory.
