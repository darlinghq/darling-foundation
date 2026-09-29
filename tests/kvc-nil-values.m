#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

@interface NilValueFixture : NSObject
- (id)present;
- (id)absent;
@end
@implementation NilValueFixture
- (id)present { return @"value"; }
- (id)absent { return nil; }
@end

int main(void)
{
    @autoreleasepool {
        NilValueFixture *fixture = [[[NilValueFixture alloc] init] autorelease];
        NSDictionary *values = [fixture dictionaryWithValuesForKeys:@[@"present", @"absent"]];
        assert([values count] == 2);
        assert([[values objectForKey:@"present"] isEqual:@"value"]);
        assert([values objectForKey:@"absent"] == [NSNull null]);
        assert([[fixture dictionaryWithValuesForKeys:@[]] count] == 0);
        values = [fixture dictionaryWithValuesForKeys:@[@"absent", @"absent"]];
        assert([values count] == 1);
        assert([values objectForKey:@"absent"] == [NSNull null]);
        BOOL raised = NO;
        @try { [fixture dictionaryWithValuesForKeys:@[@"undefined"]]; }
        @catch (NSException *exception) { raised = [[exception name] isEqual:NSUndefinedKeyException]; }
        assert(raised);
    }
    puts("PASS: KVC dictionary nil substitution and undefined-key behavior");
    return 0;
}
