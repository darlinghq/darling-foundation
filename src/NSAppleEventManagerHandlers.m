/*
 This file is part of Darling.

 Copyright (C) 2026 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

// Event handlers of NSAppleEventManager. Each handler is an object and selector registered for an event
// class and ID; they are called from the AE event handler table when an event arrives.

#import <Foundation/NSAppleEventManager.h>
#import <Foundation/NSAppleEventDescriptor.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSLock.h>
#include <dlfcn.h>
#include <dispatch/dispatch.h>

// AE links against Foundation (through CarbonCore), so Foundation looks AE up when it is first needed;
// see NSAppleEventDescriptor.m.
#define AE_PATH "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/AE.framework/Versions/A/AE"

static struct {
    __typeof__(AEInstallEventHandler) *installHandler;
    __typeof__(AERemoveEventHandler) *removeHandler;
    __typeof__(AEDuplicateDesc) *duplicateDesc;
    __typeof__(AEDisposeDesc) *disposeDesc;
    __typeof__(AEGetAttributePtr) *getAttributePtr;
} ae;

static BOOL loadAE(void)
{
    static dispatch_once_t once;
    static BOOL loaded;
    dispatch_once(&once, ^{
        void *h = dlopen(AE_PATH, RTLD_LAZY | RTLD_GLOBAL);
        if (h == NULL)
            return;
        ae.installHandler = dlsym(h, "AEInstallEventHandler");
        ae.removeHandler = dlsym(h, "AERemoveEventHandler");
        ae.duplicateDesc = dlsym(h, "AEDuplicateDesc");
        ae.disposeDesc = dlsym(h, "AEDisposeDesc");
        ae.getAttributePtr = dlsym(h, "AEGetAttributePtr");
        loaded = ae.installHandler && ae.removeHandler && ae.duplicateDesc && ae.disposeDesc && ae.getAttributePtr;
    });
    return loaded;
}

@interface NSAppleEventHandlerRecord : NSObject {
@public
    id target;
    SEL selector;
}
@end

@implementation NSAppleEventHandlerRecord
- (void) dealloc {
    [target release];
    [super dealloc];
}
@end

static NSMutableDictionary *handlerRecords; // "class:id" -> NSAppleEventHandlerRecord
static NSRecursiveLock *handlerLock;

static NSString *handlerKey(AEEventClass eventClass, AEEventID eventID) {
    return [NSString stringWithFormat: @"%08x:%08x", (unsigned) eventClass, (unsigned) eventID];
}

static NSString *const kCurrentEventKey = @"NSAppleEventManager.currentEvent";
static NSString *const kCurrentReplyKey = @"NSAppleEventManager.currentReply";

// The AE handler for every registered class and ID.
static OSErr handleAppleEvent(const AppleEvent *event, AppleEvent *reply, SRefCon refcon) {
    OSErr err = noErr;
    @autoreleasepool {
        DescType type;
        Size size;
        AEEventClass eventClass = 0;
        AEEventID eventID = 0;
        ae.getAttributePtr(event, keyEventClassAttr, typeType, &type, &eventClass, sizeof(eventClass), &size);
        ae.getAttributePtr(event, keyEventIDAttr, typeType, &type, &eventID, sizeof(eventID), &size);

        NSAppleEventHandlerRecord *record;
        [handlerLock lock];
        record = [[[handlerRecords objectForKey: handlerKey(eventClass, eventID)] retain] autorelease];
        [handlerLock unlock];
        if (record == nil)
            return errAEEventNotHandled;

        AEDesc eventCopy, replyCopy;
        if (ae.duplicateDesc(event, &eventCopy) != noErr)
            return memFullErr;
        if (reply == NULL || ae.duplicateDesc(reply, &replyCopy) != noErr) {
            replyCopy.descriptorType = typeNull;
            replyCopy.dataHandle = NULL;
        }
        NSAppleEventDescriptor *eventDescriptor = [[[NSAppleEventDescriptor alloc] initWithAEDescNoCopy: &eventCopy] autorelease];
        NSAppleEventDescriptor *replyDescriptor = [[[NSAppleEventDescriptor alloc] initWithAEDescNoCopy: &replyCopy] autorelease];

        NSMutableDictionary *threadInfo = [[NSThread currentThread] threadDictionary];
        id previousEvent = [[[threadInfo objectForKey: kCurrentEventKey] retain] autorelease];
        id previousReply = [[[threadInfo objectForKey: kCurrentReplyKey] retain] autorelease];
        [threadInfo setObject: eventDescriptor forKey: kCurrentEventKey];
        [threadInfo setObject: replyDescriptor forKey: kCurrentReplyKey];
        @try {
            [record->target performSelector: record->selector withObject: eventDescriptor withObject: replyDescriptor];
        } @finally {
            if (previousEvent) [threadInfo setObject: previousEvent forKey: kCurrentEventKey];
            else [threadInfo removeObjectForKey: kCurrentEventKey];
            if (previousReply) [threadInfo setObject: previousReply forKey: kCurrentReplyKey];
            else [threadInfo removeObjectForKey: kCurrentReplyKey];
        }

        // The handler may have filled in the reply.
        if (reply != NULL && replyCopy.dataHandle != NULL && [replyDescriptor aeDesc]->dataHandle != NULL) {
            ae.disposeDesc(reply);
            ae.duplicateDesc([replyDescriptor aeDesc], reply);
        }
    }
    return err;
}

@implementation NSAppleEventManager (EventHandlers)

- (void) setEventHandler: (id) handler
             andSelector: (SEL) selector
           forEventClass: (AEEventClass) eventClass
              andEventID: (AEEventID) eventID
{
    if (handler == nil || selector == NULL || !loadAE())
        return;

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handlerRecords = [[NSMutableDictionary alloc] init];
        handlerLock = [[NSRecursiveLock alloc] init];
    });

    NSAppleEventHandlerRecord *record = [[[NSAppleEventHandlerRecord alloc] init] autorelease];
    record->target = [handler retain];
    record->selector = selector;
    [handlerLock lock];
    [handlerRecords setObject: record forKey: handlerKey(eventClass, eventID)];
    [handlerLock unlock];
    ae.installHandler(eventClass, eventID, handleAppleEvent, 0, false);
}

- (void) removeEventHandlerForEventClass: (AEEventClass) eventClass andEventID: (AEEventID) eventID {
    if (!loadAE() || handlerRecords == nil)
        return;
    [handlerLock lock];
    [handlerRecords removeObjectForKey: handlerKey(eventClass, eventID)];
    [handlerLock unlock];
    ae.removeHandler(eventClass, eventID, handleAppleEvent, false);
}

- (NSAppleEventDescriptor *) currentAppleEvent {
    return [[[NSThread currentThread] threadDictionary] objectForKey: kCurrentEventKey];
}

- (NSAppleEventDescriptor *) currentReplyAppleEvent {
    return [[[NSThread currentThread] threadDictionary] objectForKey: kCurrentReplyKey];
}

@end
