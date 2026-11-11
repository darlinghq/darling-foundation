#import "Foundation/NSRegularExpression.h"

@implementation NSDataDetector

@synthesize checkingTypes = _checkingTypes;

+ (NSDataDetector *)dataDetectorWithTypes:(NSTextCheckingTypes)checkingTypes error:(NSError **)error
{
    return [[[self alloc] initWithTypes:checkingTypes error:error] autorelease];
}

// The pattern coding inherited from NSRegularExpression does not carry the
// checking types, so a detector cannot be archived securely yet.
+ (BOOL)supportsSecureCoding
{
    return NO;
}

- (id)initWithTypes:(NSTextCheckingTypes)checkingTypes error:(NSError **)error
{
    self = [super initWithPattern:@".*" options:0 error:error];

    if (self)
    {
        _checkingTypes = checkingTypes;
    }

    return self;
}

@end
