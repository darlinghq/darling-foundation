#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
@interface ErrorDelegate : NSObject <NSXMLParserDelegate> {
@public NSUInteger errors; NSUInteger ended; BOOL abortOnStart;
}
@end
@implementation ErrorDelegate
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)error { ++errors; }
- (void)parserDidEndDocument:(NSXMLParser *)parser { ++ended; }
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)element namespaceURI:(NSString *)uri qualifiedName:(NSString *)qualified attributes:(NSDictionary *)attributes {
    if (abortOnStart) [parser abortParsing];
}
@end
int main(void) {
    @autoreleasepool {
        NSArray *good = @[@"<a/>", @"<a></a>", @"<a><b/></a>",
            @" \n<a/>\t\n", @"<?xml version='1.0'?><a/>",
            @"<!-- before --><a/><!-- after -->",
            @"<a key='value'>text &amp; more</a>",
            @"<a><![CDATA[text]]></a>"];
        for (NSString *document in good) {
            ErrorDelegate *delegate = [[ErrorDelegate alloc] init];
            NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[document dataUsingEncoding:NSUTF8StringEncoding]];
            [parser setDelegate:delegate];
            BOOL success = [parser parse];
            if (!success) fprintf(stderr, "Valid XML rejected: %s\n", [document UTF8String]);
            assert(success);
            assert([parser parserError] == nil);
            assert(delegate->errors == 0 && delegate->ended == 1);
            [parser release]; [delegate release];
        }
        NSArray *bad = @[@"", @"  ", @"<?xml version='1.0'?>", @"<a>", @"<a></b>",
            @"</a>", @"<a/><b/>", @"text<a/>", @"<a/>text", @"<a/>"];
        for (NSUInteger i = 0; i < [bad count]; ++i) {
            ErrorDelegate *delegate = [[ErrorDelegate alloc] init];
            delegate->abortOnStart = i == [bad count] - 1;
            NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[bad[i] dataUsingEncoding:NSUTF8StringEncoding]];
            [parser setDelegate:delegate];
            assert(![parser parse]);
            assert([parser parserError] != nil);
            assert([[[parser parserError] domain] isEqual:@"NSXMLParserErrorDomain"]);
            assert(delegate->errors == 1 && delegate->ended == 0);
            [parser release]; [delegate release];
        }
    }
    puts("PASS: XML root, tag, EOF and abort failures");
    return 0;
}
