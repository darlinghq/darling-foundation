#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>
@interface EmptyDelegate : NSObject <NSXMLParserDelegate>
@end
@implementation EmptyDelegate
@end
@interface EndDelegate : NSObject <NSXMLParserDelegate> { @public NSUInteger count; BOOL throws; }
@end
@implementation EndDelegate
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)element namespaceURI:(NSString *)uri qualifiedName:(NSString *)qualified
{
    ++count;
    if (throws) [NSException raise:@"DelegateSentinel" format:@"delegate exception"];
}
@end
static BOOL parse(id delegate)
{
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[@"<root><child/></root>" dataUsingEncoding:NSUTF8StringEncoding]];
    [parser setDelegate:delegate];
    @try { return [parser parse]; }
    @finally { [parser release]; }
}
int main(void)
{
    @autoreleasepool {
        EmptyDelegate *empty = [[[EmptyDelegate alloc] init] autorelease];
        assert(parse(nil));
        assert(parse(empty));
        EndDelegate *end = [[[EndDelegate alloc] init] autorelease];
        assert(parse(end));
        assert(end->count == 2);
        end->throws = YES;
        BOOL raised = NO;
        @try { parse(end); }
        @catch (NSException *exception) { raised = [[exception name] isEqual:@"DelegateSentinel"]; }
        assert(raised);
    }
    puts("PASS: optional XML delegate callbacks and exception propagation");
    return 0;
}
