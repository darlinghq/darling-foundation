#import <Foundation/NSObject.h>
#import <Foundation/NSError.h>

#include <xpc/xpc.h>

// returns the description of the object as an autoreleased NSString
NSString* xpc_nsdescription(xpc_object_t object);

// this wrapper is necessary because our libxpc is pure C at the moment,
// meaning XPC objects cannot interact normally with Objective-C
// (e.g. to enable retain/release and being in collections)

@interface XPCObject : NSObject {
	xpc_object_t _object;
}

@property(strong) xpc_object_t object;

- (instancetype)initWithXPCObject: (xpc_object_t)object;
+ (instancetype)objectWithXPCObject: (xpc_object_t)object;

@end

// this is just a convenience wrapper to make message sending and replying more object-oriented

@class XPCMessage;
typedef void (^XPCReplyWaiter)(NSError* error, XPCMessage* reply);

extern const NSErrorDomain XPCMessageErrorDomain;

typedef NS_ENUM(NSInteger, XPCMessageErrorCode) {
	XPCMessageNoError = 0,
	XPCMessageUnknownError = 1,
	XPCMessageConnectionInterrupted = 2,
	XPCMessageConnectionInvalidated = 3,
};

@interface XPCMessage : XPCObject {
	XPCObject* _connection;
}

@property(strong) XPCObject* connection;

- (instancetype)initForConnection: (XPCObject*)connection;
+ (instancetype)messageForConnection: (XPCObject*)connection;

- (instancetype)initForConnection: (XPCObject*)connection withRawMessage: (XPCObject*)message;
+ (instancetype)messageForConnection: (XPCObject*)connection withRawMessage: (XPCObject*)message;

- (instancetype)initInReplyTo: (XPCMessage*)message;
+ (instancetype)messageInReplyTo: (XPCMessage*)message;

- (void)send;
- (void)sendWithReply: (XPCReplyWaiter)waiter;
- (void)sendWithBlockingReply: (XPCReplyWaiter)waiter;

@end
