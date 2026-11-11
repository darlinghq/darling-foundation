#import <Foundation/NSURL.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumber.h>
#include <stdio.h>

#define CHECK(condition) do { if (!(condition)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); return 2; \
} } while (0)

static BOOL rejectsName(id name, id value)
{
    @try {
        [[[NSURLQueryItem alloc] initWithName:name value:value] release];
    } @catch (NSException *exception) {
        return [[exception name] isEqual:NSInvalidArgumentException];
    }
    return NO;
}

int main(void)
{
    @autoreleasepool {
        @try {
            NSURLQueryItem *flag = [NSURLQueryItem queryItemWithName:@"flag" value:nil];
            CHECK([[flag name] isEqual:@"flag"] && [flag value] == nil);
            NSURLQueryItem *empty = [NSURLQueryItem queryItemWithName:@"flag" value:@""];
            CHECK([[empty value] isEqual:@""] && ![empty isEqual:flag]);
            NSMutableString *name = [NSMutableString stringWithString:@"a%&=é"];
            NSMutableString *value = [NSMutableString stringWithString:@"b+%20"];
            NSURLQueryItem *item = [[NSURLQueryItem alloc] initWithName:name value:value];
            [name appendString:@"changed"];
            [value appendString:@"changed"];
            CHECK([[item name] isEqual:@"a%&=é"] && [[item value] isEqual:@"b+%20"]);
            NSURLQueryItem *copy = [item copy];
            CHECK(copy == item);
            [item release];
            CHECK([[copy name] isEqual:@"a%&=é"]);
            NSURLQueryItem *equal = [NSURLQueryItem queryItemWithName:@"a%&=é" value:@"b+%20"];
            CHECK([copy isEqual:equal] && [copy hash] == [equal hash]);
            CHECK(![copy isEqual:@"a%&=é"] && ![copy isEqual:nil]);
            [copy release];
            CHECK([[NSURLQueryItem queryItemWithName:@"" value:nil] name] != nil);
            CHECK(rejectsName(nil, nil));
            CHECK(rejectsName([NSNumber numberWithInt:1], nil));
            CHECK(rejectsName(@"name", [NSNumber numberWithInt:1]));
            CHECK([NSURLQueryItem supportsSecureCoding]);
            NSURLQueryItem *items[] = {flag, empty, equal};
            for (unsigned i = 0; i < 3; i++) {
                NSError *error = nil;
                NSData *data = [NSKeyedArchiver archivedDataWithRootObject:items[i] requiringSecureCoding:YES error:&error];
                CHECK(data != nil && error == nil);
                NSURLQueryItem *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSURLQueryItem class] fromData:data error:&error];
                CHECK(error == nil);
                CHECK([decoded isEqual:items[i]]);
                CHECK((i != 0 || [decoded value] == nil) && (i != 1 || [[decoded value] isEqual:@""]));
            }
            NSCoder *unkeyed = [[NSCoder alloc] init];
            BOOL rejectedEncode = NO, rejectedDecode = NO;
            @try { [flag encodeWithCoder:unkeyed]; }
            @catch (NSException *exception) { rejectedEncode = [[exception name] isEqual:NSInvalidArgumentException]; }
            @try { [[[NSURLQueryItem alloc] initWithCoder:unkeyed] release]; }
            @catch (NSException *exception) { rejectedDecode = [[exception name] isEqual:NSInvalidArgumentException]; }
            [unkeyed release];
            CHECK(rejectedEncode && rejectedDecode);
            puts("PASS query item factory, ownership, nil/empty, copy, equality, secure archive and unkeyed rejection");
            return 0;
        } @catch (NSException *exception) {
            fprintf(stderr, "FAIL query item: %s\n", [[exception reason] UTF8String]);
            return 1;
        }
    }
}
