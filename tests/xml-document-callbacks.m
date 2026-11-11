/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSXMLParser sends -parserDidStartDocument: exactly once and
 * -parserDidEndDocument: exactly once on success, and no end-of-document
 * message when parsing fails (the failure goes to
 * -parser:parseErrorOccurred: instead).
 *
 * Build: clang -target <arch>-apple-macos... -framework Foundation
 *        -lobjc xml_document_callbacks.m
 */

#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

static void expect(int ok, const char* what)
{
	printf("%s: %s\n", ok ? "PASS" : "FAIL", what);
	if (!ok)
		failures++;
}

@interface DocDelegate : NSObject <NSXMLParserDelegate>
@property (nonatomic, assign) int starts;
@property (nonatomic, assign) int ends;
@property (nonatomic, assign) int errors;
@end

@implementation DocDelegate
- (void)parserDidStartDocument:(NSXMLParser*)parser { self.starts++; }
- (void)parserDidEndDocument:(NSXMLParser*)parser { self.ends++; }
- (void)parser:(NSXMLParser*)parser parseErrorOccurred:(NSError*)error { self.errors++; }
@end

static DocDelegate* parse(NSString* xml, BOOL* result, NSXMLParser** outParser)
{
	DocDelegate* d = [[[DocDelegate alloc] init] autorelease];
	NSXMLParser* p = [[[NSXMLParser alloc] initWithData:[xml dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
	p.delegate = d;
	*result = [p parse];
	if (outParser)
		*outParser = p;
	return d;
}

int main(void)
{
	@autoreleasepool {
		BOOL ok;
		DocDelegate* d = parse(@"<root><a/></root>", &ok, NULL);
		expect(ok, "well-formed document parses");
		expect(d.starts == 1, "parserDidStartDocument: sent once");
		expect(d.ends == 1, "parserDidEndDocument: sent once");
		expect(d.errors == 0, "no error reported");

		NSXMLParser* p = nil;
		d = parse(@"<root><a></root>", &ok, &p);
		expect(!ok, "mismatched tag fails");
		expect(d.starts == 1, "parserDidStartDocument: sent once on failure");
		expect(d.ends == 0, "parserDidEndDocument: not sent on failure");
		expect(d.errors == 1, "parseErrorOccurred: sent once");
		expect([p.parserError.domain isEqualToString:NSXMLParserErrorDomain], "error is in NSXMLParserErrorDomain");
		expect(p.parserError.code == NSXMLParserTagNameMismatchError, "mismatched tag reports its code");
	}
	printf("%s\n", failures ? "FAILED" : "ALL PASSED");
	return failures ? 1 : 0;
}
