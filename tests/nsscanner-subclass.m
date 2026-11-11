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

// An NSScanner subclass that overrides only the primitive methods, as
// Apple's subclassing notes describe, inherits every scanning method.
@interface PrimitiveScanner : NSScanner
{
    NSString *_string;
    NSUInteger _location;
}
@end

@implementation PrimitiveScanner

- (instancetype)initWithString:(NSString *)string
{
    if ((self = [super initWithString:string]))
    {
        _string = [string copy];
    }
    return self;
}

- (void)dealloc
{
    [_string release];
    [super dealloc];
}

- (NSString *)string { return _string; }
- (NSUInteger)scanLocation { return _location; }
- (void)setScanLocation:(NSUInteger)location { _location = location; }

@end

int main(void)
{
    @autoreleasepool
    {
        PrimitiveScanner *scanner =
            [[[PrimitiveScanner alloc] initWithString:@"  sin(x) 42 -7000000000 2.5 end"] autorelease];
        NSString *word = nil;
        expect([scanner scanCharactersFromSet:[NSCharacterSet letterCharacterSet] intoString:&word], @"scan letters");
        expect([word isEqualToString:@"sin"], @"letters value");
        expect([scanner scanString:@"(" intoString:NULL], @"scan string");
        expect([scanner scanUpToString:@")" intoString:&word], @"scan up to string");
        expect([word isEqualToString:@"x"], @"up to string value");
        expect([scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&word], @"scan up to digits");
        expect([word isEqualToString:@") "], @"up to digits value");

        int i = 0;
        expect([scanner scanInt:&i] && i == 42, @"scanInt");
        long long ll = 0;
        expect([scanner scanLongLong:&ll] && ll == -7000000000LL, @"scanLongLong");
        double d = 0;
        expect([scanner scanDouble:&d] && d == 2.5, @"scanDouble");
        expect(![scanner isAtEnd], @"not at end before the last word");
        expect([scanner scanString:@"end" intoString:NULL], @"scan last word");
        expect([scanner isAtEnd], @"at end");

        NSLog(@"PASS: nsscanner-subclass");
    }
    return 0;
}
