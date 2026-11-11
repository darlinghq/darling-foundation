#import <Foundation/Foundation.h>
#include <stdio.h>

@interface LoadingToken : NSObject <NSSecureCoding>
@end

@implementation LoadingToken
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (id)initWithCoder:(NSCoder *)coder { return [super init]; }
@end

int main(void)
{
    int failures = 0;
    /* class property syntax must compile alongside the method call syntax */
    BOOL viaProperty = LoadingToken.supportsSecureCoding;
    BOOL viaMessage = [LoadingToken supportsSecureCoding];
    BOOL viaProtocol = [(Class<NSSecureCoding>)[LoadingToken class] supportsSecureCoding];
    BOOL ok = viaProperty && viaMessage && viaProtocol;
    printf("%s NSSecureCoding.supportsSecureCoding class property\n", ok ? "PASS" : "FAIL");
    failures += !ok;
    return failures;
}
