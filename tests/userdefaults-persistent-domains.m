#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <unistd.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void)
{
    @autoreleasepool
    {
        NSString *domain = [NSString stringWithFormat:
            @"org.darlinghq.Foundation.tests.persistent-domain.%d", getpid()];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] init];

        [defaults setPersistentDomain:@{ @"first": @1, @"stale": @2 }
                              forName:domain];
        expect([[defaults persistentDomainForName:domain][@"first"] isEqual:@1],
            @"setPersistentDomain: must store values in the named domain");

        [defaults setPersistentDomain:@{ @"replacement": @3 } forName:domain];
        NSDictionary *replacement = [defaults persistentDomainForName:domain];
        expect([replacement[@"replacement"] isEqual:@3],
            @"a replacement domain must contain the new values");
        expect(replacement[@"first"] == nil && replacement[@"stale"] == nil,
            @"setPersistentDomain: must replace rather than merge the old domain");

        [defaults removePersistentDomainForName:domain];
        NSDictionary *removed = [defaults persistentDomainForName:domain];
        expect(removed == nil || removed.count == 0,
            @"removePersistentDomainForName: must empty the requested domain");

        [defaults release];
        NSLog(@"PASS: userdefaults-persistent-domains");
    }
    return 0;
}
