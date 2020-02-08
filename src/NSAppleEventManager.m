#import <Foundation/NSAppleEventManager.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

static NSAppleEventManager* instance = nil;

@implementation NSAppleEventManager

+ (NSAppleEventManager *)sharedAppleEventManager
{
    @synchronized(self)
    {
        if (instance == nil)
            instance = [[NSAppleEventManager alloc] init];
    }
    return instance;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
