#import <Foundation/NSObject.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

// DUMMY

@interface NSAppleScript : NSObject
@end

@implementation NSAppleScript
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}
@end

