#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSTimeZone *roundTrip(NSTimeZone *zone)
{
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:zone];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:archive];
    NSTimeZone *decoded = [unarchiver decodeObjectOfClass:[NSTimeZone class] forKey:NSKeyedArchiveRootObjectKey];
    [unarchiver release];
    return decoded;
}

int main(void)
{
    @autoreleasepool
    {
        NSDate *summer = [NSDate dateWithTimeIntervalSince1970:1626350400];
        NSTimeZone *berlin = [NSTimeZone timeZoneWithName:@"Europe/Berlin"];
        expect(berlin != nil, @"Europe/Berlin exists");
        NSTimeZone *decoded = roundTrip(berlin);
        expect([decoded isKindOfClass:[NSTimeZone class]], @"decodes an NSTimeZone");
        expect([decoded.name isEqualToString:@"Europe/Berlin"], @"named zone keeps its name");
        expect([decoded secondsFromGMTForDate:summer] == 7200, @"named zone keeps its rules");

        NSTimeZone *fixed = [NSTimeZone timeZoneForSecondsFromGMT:-18000];
        decoded = roundTrip(fixed);
        expect([decoded.name isEqualToString:fixed.name], @"fixed-offset zone keeps its name");
        expect(decoded.secondsFromGMT == -18000, @"fixed-offset zone keeps its offset");

        decoded = roundTrip([NSTimeZone timeZoneWithName:@"GMT"]);
        expect(decoded.secondsFromGMT == 0 && [decoded.name isEqualToString:@"GMT"], @"GMT round trip");
    }
    NSLog(@"PASS: NSTimeZone coding");
    return 0;
}
