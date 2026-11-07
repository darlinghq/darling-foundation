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

// Methods this class does not implement are forwarded here and return nil/0/NO through an object-sized,
// zero-filled return slot. That only fits methods returning an object, an integer or a pointer; a method
// returning a struct or a floating-point value needs a real implementation.
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "@@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

// Darling does not deliver Apple events, so no event is ever being handled or suspended.
- (NSAppleEventDescriptor *)currentAppleEvent
{
    return nil;
}

- (NSAppleEventDescriptor *)currentReplyAppleEvent
{
    return nil;
}

- (NSAppleEventManagerSuspensionID)suspendCurrentAppleEvent
{
    return NULL;
}

- (NSAppleEventDescriptor *)appleEventForSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID
{
    return nil;
}

- (NSAppleEventDescriptor *)replyAppleEventForSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID
{
    return nil;
}

- (void)setCurrentAppleEventAndReplyEventWithSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID
{
}

- (void)resumeWithSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID
{
}

// Handlers set with setEventHandler:... are never called, so there is nothing to remove.
- (void)removeEventHandlerForEventClass:(AEEventClass)eventClass andEventID:(AEEventID)eventID
{
}

- (void) setEventHandler: (id) handler
             andSelector: (SEL) selector
           forEventClass: (AEEventClass) eventClass
              andEventID: (AEEventID) eventID
{
    printf("STUB %s\n", __PRETTY_FUNCTION__);
}

@end
