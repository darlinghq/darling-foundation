// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: Foundation's private NSURLError class.
// Observed on macOS 26.7.3 (x86_64) with the same calls: the class exists,
// is a direct subclass of NSError and supports secure coding; an instance
// keeps its domain and survives a secure keyed archive round trip as
// NSURLError; errors made in NSURLErrorDomain are plain NSErrors.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

int main(void)
{
    @autoreleasepool {
        Class urlError = objc_getClass("NSURLError");
        report("class exists", urlError != Nil);
        report("subclass of NSError", class_getSuperclass(urlError) == [NSError class]);
        report("supports secure coding", [urlError supportsSecureCoding]);

        NSError *error = [[[urlError alloc] initWithDomain: NSURLErrorDomain code: NSURLErrorTimedOut userInfo: @{ @"a": @1 }] autorelease];
        report("instance", [error isKindOfClass: urlError] && [error.domain isEqualToString: NSURLErrorDomain] && error.code == NSURLErrorTimedOut);

        NSData *data = [NSKeyedArchiver archivedDataWithRootObject: error requiringSecureCoding: YES error: NULL];
        NSSet *classes = [NSSet setWithObjects: urlError, [NSError class], [NSDictionary class], [NSString class], [NSNumber class], nil];
        NSError *decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses: classes fromData: data error: NULL];
        report("secure coding round trip", [decoded isKindOfClass: urlError] && decoded.code == NSURLErrorTimedOut
               && [decoded.userInfo[@"a"] isEqual: @1]);

        report("errors in the domain are plain NSErrors",
               [[NSError errorWithDomain: NSURLErrorDomain code: -1009 userInfo: nil] class] == [NSError class]);
    }
    return failures != 0;
}
