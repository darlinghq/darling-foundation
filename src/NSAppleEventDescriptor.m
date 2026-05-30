#import <Foundation/NSObject.h>

#import <Foundation/NSInvocation.h>

// DUMMY

@interface NSAppleEventDescriptor : NSObject
@end

@implementation NSAppleEventDescriptor
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}
@end

