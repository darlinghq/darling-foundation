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
