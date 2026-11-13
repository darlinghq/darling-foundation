/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSURLSession.sharedSession is a class property, and the NSURLResponse /
 * NSHTTPURLResponse accessors are properties; the selectors are unchanged.
 * Also checks that NSURLResponse still conforms to NSSecureCoding.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void)
{
	@autoreleasepool {
		int failures = 0;
		if (NSURLSession.sharedSession == nil || NSURLSession.sharedSession != [NSURLSession sharedSession]) {
			printf("FAIL: sharedSession\n");
			failures++;
		}
		NSURL *u = [NSURL URLWithString:@"http://example.invalid/a.txt"];
		NSHTTPURLResponse *r = [[NSHTTPURLResponse alloc] initWithURL:u statusCode:200 HTTPVersion:@"HTTP/1.1"
		                                                  headerFields:@{@"Content-Type": @"text/plain"}];
		if (![r.URL isEqual:u] || r.statusCode != 200 || ![r.MIMEType isEqual:@"text/plain"]
		    || ![r conformsToProtocol:@protocol(NSSecureCoding)]) {
			printf("FAIL: response properties\n");
			failures++;
		}
		if (failures == 0)
			printf("PASS: URLSession/URLResponse properties\n");
		return failures != 0;
	}
}
