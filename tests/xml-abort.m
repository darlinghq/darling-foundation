#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

@interface AbortDelegate : NSObject <NSXMLParserDelegate> {
@public
    NSUInteger phase, errors, callbacksAfterAbort, ended;
    BOOL aborted;
}
@end
@implementation AbortDelegate
- (void)event:(NSUInteger)event parser:(NSXMLParser *)parser {
    if (aborted) ++callbacksAfterAbort;
    if (event == phase) {
        aborted = YES;
        [parser abortParsing];
        [parser abortParsing]; // Repeated abort must not report a second error.
    }
}
- (void)parserDidStartDocument:(NSXMLParser *)parser { [self event:0 parser:parser]; }
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name namespaceURI:(NSString *)uri qualifiedName:(NSString *)qualified attributes:(NSDictionary *)attributes { [self event:1 parser:parser]; }
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)text { [self event:2 parser:parser]; }
- (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)text { [self event:3 parser:parser]; }
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)name namespaceURI:(NSString *)uri qualifiedName:(NSString *)qualified { [self event:4 parser:parser]; }
- (void)parserDidEndDocument:(NSXMLParser *)parser { ++ended; [self event:5 parser:parser]; }
- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)error {
    ++errors;
    assert([error code] == NSXMLParserDelegateAbortedParseError);
    assert(error == [parser parserError]);
    [parser abortParsing]; // Error notification itself can reenter abortParsing.
}
@end

int main(void) {
    @autoreleasepool {
        for (NSUInteger phase = 0; phase < 6; ++phase) {
            AbortDelegate *delegate = [[AbortDelegate alloc] init];
            delegate->phase = phase;
            NSXMLParser *parser = [[NSXMLParser alloc] initWithData:
                [@"<root>text\n<child/>more</root>" dataUsingEncoding:NSUTF8StringEncoding]];
            [parser setDelegate:delegate];
            BOOL success = [parser parse];
            if (success) fprintf(stderr, "Abort phase %lu not triggered\n", (unsigned long)phase);
            assert(!success);
            assert(delegate->aborted);
            assert(delegate->errors == 1);
            assert(delegate->callbacksAfterAbort == 0);
            assert(delegate->ended == (phase == 5 ? 1 : 0));
            assert([[parser parserError] code] == 512);
            [parser release];
            [delegate release];
        }
    }
    puts("PASS: XML callback abort stops events and reports one error");
    return 0;
}
