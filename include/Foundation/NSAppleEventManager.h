#ifndef NSAPPLEEVENTMANAGER_H
#define NSAPPLEEVENTMANAGER_H
#include <TargetConditionals.h>
// Apple Events are macOS-only: iOS has no AE framework and no NSAppleEvent* classes.
#if TARGET_OS_OSX
#include "NSAppleEventDescriptor.h"

typedef const struct __NSAppleEventManagerSuspension *NSAppleEventManagerSuspensionID;

@interface NSAppleEventManager : NSObject

+ (NSAppleEventManager *)sharedAppleEventManager;

- (NSAppleEventDescriptor *)appleEventForSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID;
- (NSAppleEventDescriptor *)currentAppleEvent;
- (NSAppleEventDescriptor *)currentReplyAppleEvent;

- (OSErr)dispatchRawAppleEvent:(const AppleEvent *)theAppleEvent
                  withRawReply:(AppleEvent *)theReply
                 handlerRefCon:(UInt32)handlerRefcon;
- (void)removeEventHandlerForEventClass:(AEEventClass)eventClass
                             andEventID:(AEEventID)eventID;
- (NSAppleEventDescriptor *)replyAppleEventForSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID;
- (void)resumeWithSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID;
- (void)setCurrentAppleEventAndReplyEventWithSuspensionID:(NSAppleEventManagerSuspensionID)suspensionID;
- (void)setEventHandler:(id)handler
            andSelector:(SEL)handleEventSelector
          forEventClass:(AEEventClass)eventClass
             andEventID:(AEEventID)eventID;
- (NSAppleEventManagerSuspensionID)suspendCurrentAppleEvent;

@end

#endif /* TARGET_OS_OSX */
#endif
