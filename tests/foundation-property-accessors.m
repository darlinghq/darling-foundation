#import <Foundation/Foundation.h>
#include <stdlib.h>
#include <string.h>

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
        NSData *data = [NSData dataWithBytes:"abc" length:3];
        expect(data.bytes != NULL, @"NSData.bytes should be readable as a property");
        expect(((const char *)data.bytes)[0] == 'a', @"NSData.bytes should point at the backing storage");

        NSString *string = @"hi";
        expect(string.UTF8String != NULL, @"NSString.UTF8String should be readable as a property");
        expect(strcmp(string.UTF8String, "hi") == 0, @"NSString.UTF8String should round-trip the contents");

        NSDictionary<NSString *, NSString *> *environment = [NSProcessInfo processInfo].environment;
        expect(environment != nil, @"NSProcessInfo.environment should be readable as a property");

        NSArray<NSString *> *preferred = [NSBundle mainBundle].preferredLocalizations;
        expect(preferred != nil, @"NSBundle.preferredLocalizations should be readable as a property");

        NSLog(@"PASS: NSData.bytes/NSString.UTF8String/NSProcessInfo.environment/NSBundle.preferredLocalizations");
    }
    return 0;
}
