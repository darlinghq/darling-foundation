/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// NSURL data representation: the URL string as UTF-8 data, the initializers
// and class methods that read it back (relative and absolute forms), and the
// documented behaviour of a nil base URL and of a subclass.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

static NSData *utf8(NSString *s) { return [s dataUsingEncoding: NSUTF8StringEncoding]; }

@interface URLSubclass : NSURL
@end
@implementation URLSubclass
@end

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSURL *url = [NSURL URLWithString: @"http://example.com/a%20b/%C3%A9?q=1#f"];
    expect([[url dataRepresentation] isEqualToData: utf8(@"http://example.com/a%20b/%C3%A9?q=1#f")], @"dataRepresentation is the URL string in UTF-8");

    NSURL *base = [NSURL URLWithString: @"http://example.com/base/"];
    NSURL *relative = [NSURL URLWithString: @"sub/x.html" relativeToURL: base];
    expect([[relative dataRepresentation] isEqualToData: utf8(@"sub/x.html")], @"a relative URL's data is its relative string");

    NSURL *plain = [NSURL URLWithDataRepresentation: utf8(@"http://x.org/p") relativeToURL: nil];
    expect([[plain absoluteString] isEqualToString: @"http://x.org/p"], @"URLWithDataRepresentation without a base");
    expect([plain baseURL] == nil, @"no base URL");

    NSURL *rel = [NSURL URLWithDataRepresentation: utf8(@"../p") relativeToURL: [NSURL URLWithString: @"http://x.org/a/b/"]];
    expect([[rel absoluteString] isEqualToString: @"http://x.org/a/p"], @"relative data resolves against the base");
    expect([[rel baseURL] isEqual: [NSURL URLWithString: @"http://x.org/a/b/"]], @"relative form keeps the base URL");
    expect([[rel relativeString] isEqualToString: @"../p"], @"relative form keeps the relative string");

    NSURL *abs = [NSURL absoluteURLWithDataRepresentation: utf8(@"../p") relativeToURL: [NSURL URLWithString: @"http://x.org/a/b/"]];
    expect([[abs absoluteString] isEqualToString: @"http://x.org/a/p"], @"absolute form resolves against the base");
    expect([abs baseURL] == nil, @"absolute form has no base URL");

    NSURL *round = [NSURL URLWithDataRepresentation: [url dataRepresentation] relativeToURL: nil];
    expect([round isEqual: url], @"round trip gives an equal URL");

    NSURL *fileURL = [NSURL fileURLWithPath: @"/tmp/some file.txt"];
    NSURL *fileRound = [NSURL URLWithDataRepresentation: [fileURL dataRepresentation] relativeToURL: nil];
    expect([fileRound isFileURL] && [[fileRound path] isEqualToString: @"/tmp/some file.txt"], @"file URL round trip");

    NSURL *init = [[NSURL alloc] initWithDataRepresentation: utf8(@"http://x.org/i") relativeToURL: nil];
    expect([[init absoluteString] isEqualToString: @"http://x.org/i"], @"initWithDataRepresentation:relativeToURL:");
    [init release];
    init = [[NSURL alloc] initAbsoluteURLWithDataRepresentation: utf8(@"http://x.org/j") relativeToURL: nil];
    expect([[init absoluteString] isEqualToString: @"http://x.org/j"], @"initAbsoluteURLWithDataRepresentation:relativeToURL:");
    [init release];

    NSURL *sub = [URLSubclass URLWithDataRepresentation: utf8(@"http://x.org/s") relativeToURL: nil];
    expect([sub isKindOfClass: [URLSubclass class]] && [[sub absoluteString] isEqualToString: @"http://x.org/s"], @"subclass instance is created");
    expect([[sub dataRepresentation] isEqualToData: utf8(@"http://x.org/s")], @"subclass dataRepresentation");

    (void)[NSURL URLWithDataRepresentation: nil relativeToURL: nil]; // must not crash; the result is not specified
    expect(YES, @"nil data is tolerated");

    [pool drain];
    return failures ? 1 : 0;
}
