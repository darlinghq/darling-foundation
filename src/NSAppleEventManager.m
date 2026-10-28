#import <Foundation/NSAppleEventManager.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#include <stdlib.h>

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
    return [NSMethodSignature signatureWithObjCTypes: "@@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);

    // The caller reads the return register whatever the method's type, so answer nil/0/NO, not stale stack.
    NSUInteger length = [[anInvocation methodSignature] methodReturnLength];
    if (length > 0) {
        void *zero = calloc(1, length);
        [anInvocation setReturnValue: zero];
        free(zero);
    }
}

- (void) setEventHandler: (id) handler
             andSelector: (SEL) selector
           forEventClass: (AEEventClass) eventClass
              andEventID: (AEEventID) eventID
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
}

@end
