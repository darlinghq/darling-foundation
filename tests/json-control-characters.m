// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: NSJSONSerialization escapes every character below U+0020 inside strings (RFC 8259
// section 7) and parsing the output gives the original string back.
#import <Foundation/Foundation.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableString *all = [NSMutableString string];
    for (unichar c = 0; c < 0x20; c++)
        [all appendFormat: @"%C", c];
    [all appendString: @"quote\" backslash\\ end"];

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject: [NSArray arrayWithObject: all] options: 0 error: &error];
    report("serializes a string holding every control character", data != nil);
    NSString *text = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];

    BOOL raw = NO;
    for (NSUInteger i = 0; i < [text length]; i++)
        raw = raw || [text characterAtIndex: i] < 0x20;
    report("output holds no raw control character", !raw);
    report("short escapes are used for \\n \\r \\t \\b \\f",
           [text rangeOfString: @"\\n"].length && [text rangeOfString: @"\\r"].length &&
           [text rangeOfString: @"\\t"].length && [text rangeOfString: @"\\b"].length &&
           [text rangeOfString: @"\\f"].length);
    report("other controls use \\u00XX", [text rangeOfString: @"\\u0001"].length && [text rangeOfString: @"\\u001f"].length);

    NSArray *back = [NSJSONSerialization JSONObjectWithData: data options: 0 error: &error];
    report("the output parses back to the original string", [back count] == 1 && [[back objectAtIndex: 0] isEqualToString: all]);

    [pool drain];
    puts(failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
