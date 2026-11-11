#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

@interface NameObserver : NSObject { @public NSUInteger changes; }
@end
@implementation NameObserver
- (void)observeValueForKeyPath:(NSString *)key ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    assert([key isEqual:@"name"]);
    ++changes;
}
@end

int main(void)
{
    @autoreleasepool {
        NSOperation *operation = [[NSOperation alloc] init];
        NSOperation *other = [[NSOperation alloc] init];
        NameObserver *observer = [[NameObserver alloc] init];
        assert([operation name] == nil);
        [operation addObserver:observer forKeyPath:@"name" options:0 context:NULL];
        NSMutableString *name = [NSMutableString stringWithString:@"first"];
        [operation setName:name];
        [name appendString:@" changed"];
        assert([[operation name] isEqual:@"first"]);
        assert(observer->changes == 1);
        assert([other name] == nil);
        [operation setName:@"second"];
        assert([[operation name] isEqual:@"second"]);
        assert(observer->changes == 2);
        [operation setName:nil];
        assert([operation name] == nil && observer->changes == 3);
        [operation removeObserver:observer forKeyPath:@"name"];
        [observer release];
        [operation release];
        [other release];
    }
    puts("PASS: operation name copy ownership, isolation, clearing and KVO");
    return 0;
}
