// Compile against the pre-error-handling public header, then run with the
// candidate Foundation to exercise non-fragile subclass ivar adjustment.
#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

@interface ParserSubclass : NSXMLParser {
    NSUInteger sentinel;
    id retainedSentinel;
}
- (void)setSentinels;
- (void)checkSentinels;
@end
@implementation ParserSubclass
- (void)setSentinels {
    sentinel = 0x12345678;
    retainedSentinel = [@"subclass-state" copy];
}
- (void)checkSentinels {
    assert(sentinel == 0x12345678);
    assert([retainedSentinel isEqual:@"subclass-state"]);
}
- (void)dealloc { [retainedSentinel release]; [super dealloc]; }
@end

int main(void) {
    @autoreleasepool {
        for (NSString *document in @[@"<root><child/></root>", @"<root></wrong>"]) {
            ParserSubclass *parser = [[ParserSubclass alloc] initWithData:
                [document dataUsingEncoding:NSUTF8StringEncoding]];
            [parser setSentinels];
            BOOL success = [parser parse];
            assert(success == [document isEqual:@"<root><child/></root>"]);
            [parser checkSentinels];
            [parser release];
        }
    }
    puts("PASS: pre-change XML subclass layout survives candidate framework");
    return 0;
}
