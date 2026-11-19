#import <Foundation/NSScriptSuiteRegistry.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#import <objc/runtime.h>

static NSScriptSuiteRegistry *sSharedScriptSuiteRegistry = nil;

@implementation NSScriptSuiteRegistry

+ (void) setSharedScriptSuiteRegistry:(NSScriptSuiteRegistry *) registry {
    @synchronized (self) {
        if (sSharedScriptSuiteRegistry != nil)
            [sSharedScriptSuiteRegistry release];
        sSharedScriptSuiteRegistry = [registry retain];
    }
}

+ (NSScriptSuiteRegistry *) sharedScriptSuiteRegistry {
    @synchronized (self) {
        if (sSharedScriptSuiteRegistry == nil) {
            sSharedScriptSuiteRegistry = [NSScriptSuiteRegistry new];
        }
        return [[sSharedScriptSuiteRegistry retain] autorelease];
    }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
