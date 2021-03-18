
#import <CoreFoundation/CoreFoundation.h>
#import "XPCObject.h"
#import "daemon.h"

static dispatch_queue_t xpcMessageHandlingQueue = NULL;
const NSErrorDomain XPCMessageErrorDomain = (const NSErrorDomain)CFSTR(DAEMON_SERVICE_NAME ".XPCMessageErrorDomain");

NSString* xpc_nsdescription(xpc_object_t object)  {
	char* desc = xpc_copy_description(object);
	NSString* nsdesc = [NSString stringWithUTF8String: desc];
	free(desc);
	return nsdesc;
};

@implementation XPCObject

- (xpc_object_t)object
{
	return _object;
}

- (void)setObject: (xpc_object_t)newObject
{
	if (newObject != NULL) {
		xpc_retain(newObject);
	}
	if (_object != NULL) {
		xpc_release(_object);
	}
	_object = newObject;
}

- (instancetype)initWithXPCObject: (xpc_object_t)object
{
	if (self = [super init]) {
		self.object = object;
	}
	return self;
}

+ (instancetype)objectWithXPCObject: (xpc_object_t)object
{
	return [[[XPCObject alloc] initWithXPCObject: object] autorelease];
}

- (void)dealloc
{
	if (_object != NULL) {
		xpc_release(_object);
	}
	[super dealloc];
}

- (BOOL)isEqual: (id)object
{
	if ([object class] != [self class]) {
		return NO;
	}

	XPCObject* other = (XPCObject*)object;

	return xpc_equal(self.object, other.object);
}

- (NSUInteger)hash
{
	return xpc_hash(self.object);
}

- (NSString*)description
{
	return xpc_nsdescription(self.object);
}

@end

@implementation XPCMessage

@synthesize connection = _connection;

+ (void)initialize
{
	xpcMessageHandlingQueue = dispatch_queue_create(DAEMON_SERVICE_NAME ".message-handling-queue", DISPATCH_QUEUE_CONCURRENT);
}

- (void)dealloc
{
	[_connection release];
	[super dealloc];
}

- (instancetype)initForConnection: (XPCObject*)connection
{
	if (self = [super init]) {
		self.object = xpc_dictionary_create(NULL, NULL, 0);
		self.connection = connection;
	}
	return self;
}

+ (instancetype)messageForConnection: (XPCObject*)connection
{
	return [[[XPCMessage alloc] initForConnection: connection] autorelease];
}

- (instancetype)initForConnection: (XPCObject*)connection withRawMessage: (XPCObject*)message
{
	if (self = [super init]) {
		self.object = message.object;
		self.connection = connection;
	}
	return self;
}

+ (instancetype)messageForConnection: (XPCObject*)connection withRawMessage: (XPCObject*)message
{
	return [[[XPCMessage alloc] initForConnection: connection withRawMessage: message] autorelease];
}

- (instancetype)initInReplyTo: (XPCMessage*)message
{
	if (self = [super init]) {
		self.object = xpc_dictionary_create_reply(message.object);
		self.connection = message.connection;
	}
	return self;
}

+ (instancetype)messageInReplyTo: (XPCMessage*)message
{
	return [[[XPCMessage alloc] initInReplyTo: message] autorelease];
}

- (void)send
{
	xpc_connection_send_message(self.connection.object, self.object);
}

- (void)sendWithReply: (XPCReplyWaiter)waiter blocking: (BOOL)blocking
{
	if (!blocking) {
		waiter = [[waiter copy] autorelease];
	}
	void (^resultHandler)(xpc_object_t) = ^(xpc_object_t result) {
		xpc_type_t type = xpc_get_type(result);
		if (type == XPC_TYPE_ERROR) {
			NSError* error = nil;
			if (result == XPC_ERROR_CONNECTION_INTERRUPTED) {
				error = [NSError errorWithDomain: XPCMessageErrorDomain code: XPCMessageConnectionInterrupted userInfo: nil];
			} else if (result == XPC_ERROR_CONNECTION_INVALID) {
				error = [NSError errorWithDomain: XPCMessageErrorDomain code: XPCMessageConnectionInvalidated userInfo: nil];
			} else {
				error = [NSError errorWithDomain: XPCMessageErrorDomain code: XPCMessageUnknownError userInfo: nil];
			}
			waiter(error, nil);
		} else {
			waiter(nil, [XPCMessage messageForConnection: self.connection withRawMessage: [XPCObject objectWithXPCObject: result]]);
		}
	};

	if (blocking) {
		resultHandler(xpc_connection_send_message_with_reply_sync(self.connection.object, self.object));
	} else {
		xpc_connection_send_message_with_reply(self.connection.object, self.object, xpcMessageHandlingQueue, resultHandler);
	}
}

- (void)sendWithReply: (XPCReplyWaiter)waiter
{
	[self sendWithReply: waiter blocking: NO];
}

- (void)sendWithBlockingReply: (XPCReplyWaiter)waiter
{
	[self sendWithReply: waiter blocking: YES];
}

@end
