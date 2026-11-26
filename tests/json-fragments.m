// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: NSJSONSerialization fragments, that is, a string, number or null
// at the top level (https://developer.apple.com/documentation/foundation/jsonserialization).
// They are read and written only with the FragmentsAllowed options; writing one
// without the option raises, as writing any object that is not valid JSON does.
// Reading invalid JSON, a fragment without the option included, fails with
// NSPropertyListReadCorruptError (3840) in the Cocoa domain.
// Expected values were observed on macOS 26.7.3 (x86_64) with the same inputs.
#import <Foundation/Foundation.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

static NSString *serialized(id object, NSJSONWritingOptions options)
{
    NSData *data = [NSJSONSerialization dataWithJSONObject: object options: options error: NULL];
    return [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
}

static NSString *raisedWriting(id object, NSJSONWritingOptions options)
{
    @try {
        [NSJSONSerialization dataWithJSONObject: object options: options error: NULL];
    } @catch (NSException *exception) {
        return [exception name];
    }
    return nil;
}

int main(void)
{
    @autoreleasepool {
        report("the reading options are the same", NSJSONReadingFragmentsAllowed == NSJSONReadingAllowFragments);

        report("isValidJSONObject: a string is not", ![NSJSONSerialization isValidJSONObject: @"a"]);
        report("isValidJSONObject: an array is", [NSJSONSerialization isValidJSONObject: @[ @"a" ]]);

        report("write: a string", [serialized(@"a\"b", NSJSONWritingFragmentsAllowed) isEqualToString: @"\"a\\\"b\""]);
        report("write: a number", [serialized(@12, NSJSONWritingFragmentsAllowed) isEqualToString: @"12"]);
        report("write: null", [serialized([NSNull null], NSJSONWritingFragmentsAllowed) isEqualToString: @"null"]);
        report("write: not allowed raises",
               [raisedWriting(@"a", 0) isEqualToString: NSInvalidArgumentException]);
        report("write: an array needs no option", raisedWriting(@[ @"a" ], 0) == nil
               && [serialized(@[ @"a" ], 0) isEqualToString: @"[\"a\"]"]);

        NSData *string = [@"\"x\"" dataUsingEncoding: NSUTF8StringEncoding];
        id object = [NSJSONSerialization JSONObjectWithData: string options: NSJSONReadingFragmentsAllowed error: NULL];
        report("read: a string", [object isEqual: @"x"]);
        NSError *error = nil;
        object = [NSJSONSerialization JSONObjectWithData: string options: 0 error: &error];
        report("read: not allowed fails", object == nil && [[error domain] isEqualToString: NSCocoaErrorDomain]
               && [error code] == NSPropertyListReadCorruptError);

        for (NSString *invalid in @[ @"[1,", @"{\"a\" 1}", @"[tru]", @"[\"\\u12\"]", @"[1] x", @"" ]) {
            error = nil;
            object = [NSJSONSerialization JSONObjectWithData: [invalid dataUsingEncoding: NSUTF8StringEncoding]
                                                     options: 0 error: &error];
            report([[NSString stringWithFormat: @"read: invalid %@", invalid] UTF8String], object == nil
                   && [[error domain] isEqualToString: NSCocoaErrorDomain] && [error code] == NSPropertyListReadCorruptError);
        }
    }
    return failures != 0;
}
