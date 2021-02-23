#import <Foundation/NSUnitDuration.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

@implementation NSUnitDuration

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
