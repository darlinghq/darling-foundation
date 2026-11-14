/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// NSURLComponents accessors, percent-encoded forms, ranges, setters and their
// validation, URL construction, NSCopying and equality, per the documented contract (RFC 3986
// components of the string).
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

static BOOL raises(void (^block)(void))
{
    @try { block(); } @catch (NSException *e) { return [[e name] isEqualToString: NSInvalidArgumentException]; }
    return NO;
}

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *text = @"https://user:pa%20ss@example.com:8080/a%20b/c?x=1&y=%32#frag%21";
    NSURLComponents *c = [NSURLComponents componentsWithString: text];
    expect(c != nil, @"parses a full URL string");
    expect([[c string] isEqualToString: text], @"string returns the input");
    expect([[c scheme] isEqualToString: @"https"], @"scheme");
    expect([[c user] isEqualToString: @"user"], @"user");
    expect([[c password] isEqualToString: @"pa ss"], @"password is decoded");
    expect([[c percentEncodedPassword] isEqualToString: @"pa%20ss"], @"percentEncodedPassword");
    expect([[c host] isEqualToString: @"example.com"], @"host");
    expect([[c port] isEqual: [NSNumber numberWithInt: 8080]], @"port");
    expect([[c path] isEqualToString: @"/a b/c"], @"path is decoded");
    expect([[c percentEncodedPath] isEqualToString: @"/a%20b/c"], @"percentEncodedPath");
    expect([[c query] isEqualToString: @"x=1&y=2"], @"query is decoded");
    expect([[c percentEncodedQuery] isEqualToString: @"x=1&y=%32"], @"percentEncodedQuery");
    expect([[c fragment] isEqualToString: @"frag!"], @"fragment is decoded");
    expect([[c percentEncodedFragment] isEqualToString: @"frag%21"], @"percentEncodedFragment");
    expect([[[c URL] absoluteString] isEqualToString: text], @"URL round trips");

    NSRange scheme = [c rangeOfScheme];
    expect(scheme.location == 0 && scheme.length == 5, @"rangeOfScheme");
    NSRange host = [c rangeOfHost];
    expect(host.location != NSNotFound && [[text substringWithRange: host] isEqualToString: @"example.com"], @"rangeOfHost");
    NSRange port = [c rangeOfPort];
    expect([[text substringWithRange: port] isEqualToString: @"8080"], @"rangeOfPort");
    NSRange path = [c rangeOfPath];
    expect([[text substringWithRange: path] isEqualToString: @"/a%20b/c"], @"rangeOfPath");
    NSRange query = [c rangeOfQuery];
    expect([[text substringWithRange: query] isEqualToString: @"x=1&y=%32"], @"rangeOfQuery");
    NSRange fragment = [c rangeOfFragment];
    expect([[text substringWithRange: fragment] isEqualToString: @"frag%21"], @"rangeOfFragment");

    NSURLComponents *simple = [NSURLComponents componentsWithString: @"http://example.com/p"];
    expect([simple rangeOfPort].location == NSNotFound, @"a missing component has no range");
    expect([simple rangeOfQuery].location == NSNotFound, @"missing query has no range");
    expect([simple user] == nil && [simple password] == nil && [simple port] == nil && [simple query] == nil && [simple fragment] == nil, @"missing components are nil");

    NSURLComponents *m = [[[NSURLComponents alloc] init] autorelease];
    [m setScheme: @"ftp"];
    [m setHost: @"files.example.org"];
    [m setUser: @"a b"];
    [m setPort: [NSNumber numberWithInt: 21]];
    [m setPath: @"/dir name/file"];
    [m setQuery: @"k=v w"];
    [m setFragment: @"f g"];
    expect([[m string] isEqualToString: @"ftp://a%20b@files.example.org:21/dir%20name/file?k=v%20w#f%20g"], @"setters encode their components");
    expect([[m percentEncodedUser] isEqualToString: @"a%20b"], @"percentEncodedUser after setUser");
    [m setPercentEncodedPath: @"/x%2Fy"];
    expect([[m path] isEqualToString: @"/x/y"], @"setPercentEncodedPath");
    [m setPercentEncodedQuery: @"a=%41"];
    expect([[m query] isEqualToString: @"a=A"], @"setPercentEncodedQuery");
    [m setPort: nil];
    expect([m port] == nil, @"a nil port clears it");
    expect(raises(^{ [m setScheme: @"1bad"]; }), @"an invalid scheme raises");
    expect(raises(^{ [m setPercentEncodedPath: @"/bad%zz"]; }), @"an invalid percent encoding raises");

    NSURL *base = [NSURL URLWithString: @"http://example.com/dir/"];
    NSURLComponents *rel = [NSURLComponents componentsWithString: @"x/y?q=1"];
    expect([[rel path] isEqualToString: @"x/y"], @"relative components keep a relative path");
    NSURL *resolved = [rel URLRelativeToURL: base];
    expect([[resolved absoluteString] isEqualToString: @"http://example.com/dir/x/y?q=1"], @"URLRelativeToURL: resolves against the base");

    NSURLComponents *fromURL = [NSURLComponents componentsWithURL: [NSURL URLWithString: @"y?z=1" relativeToURL: base] resolvingAgainstBaseURL: YES];
    expect([[fromURL string] isEqualToString: @"http://example.com/dir/y?z=1"], @"resolvingAgainstBaseURL: YES uses the absolute string");
    fromURL = [NSURLComponents componentsWithURL: [NSURL URLWithString: @"y?z=1" relativeToURL: base] resolvingAgainstBaseURL: NO];
    expect([[fromURL string] isEqualToString: @"y?z=1"], @"resolvingAgainstBaseURL: NO uses the relative string");
    expect(raises(^{ [[NSURLComponents alloc] initWithURL: nil resolvingAgainstBaseURL: NO]; }), @"a nil URL raises NSInvalidArgumentException");

    NSURLComponents *q = [NSURLComponents componentsWithString: @"http://e.com/?a=1&b=%26&c"];
    NSArray *items = [q queryItems];
    expect([items count] == 3 && [[[items objectAtIndex: 1] value] isEqualToString: @"&"] && [[items objectAtIndex: 2] value] == nil, @"queryItems decode values");
    NSArray *encoded = [q percentEncodedQueryItems];
    expect([[[encoded objectAtIndex: 1] value] isEqualToString: @"%26"], @"percentEncodedQueryItems keep the encoding");
    [q setQueryItems: [NSArray arrayWithObjects: [NSURLQueryItem queryItemWithName: @"k" value: @"a&b"], nil]];
    expect([[q percentEncodedQuery] isEqualToString: @"k=a%26b"], @"setQueryItems: encodes");
    [q setPercentEncodedQueryItems: [NSArray arrayWithObjects: [NSURLQueryItem queryItemWithName: @"k" value: @"a%26b"], nil]];
    expect([[q query] isEqualToString: @"k=a&b"], @"setPercentEncodedQueryItems:");
    [q setQueryItems: nil];
    expect([q query] == nil, @"nil queryItems removes the query");

    NSURLComponents *copy = [[c copy] autorelease];
    expect([copy isEqual: c] && [copy hash] == [c hash] && copy != c, @"copy is equal and distinct");
    [copy setHost: @"other.example"];
    expect([[c host] isEqualToString: @"example.com"] && ![copy isEqual: c], @"mutating the copy leaves the original");

    [pool drain];
    return failures ? 1 : 0;
}
