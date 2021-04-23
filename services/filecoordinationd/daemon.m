#import <Foundation/NSSet.h>
#import <Foundation/NSDictionary.h>

#include <stdbool.h>

#import "daemon.h"
#import "XPCObject.h"
#import "FileAccessRequest.h"
#import "logging.h"

NSMutableSet<XPCObject*>* clients = nil;
static NSMutableDictionary<NSFileAccessCancellationToken*, FileAccessRequest*>* pendingRequests = nil;

static void handleXPCError(xpc_object_t error) {
	char* desc = xpc_copy_description(error);
	FCDLog(@"Unknown XPC error: %s", desc);
	free(desc);
};

static void handleIntent(XPCMessage* reply, NSString* path, NSUInteger options, NSFileAccessCancellationToken* cancellationToken, NSString* purposeIdentifier) {
	FileAccessRequest* request = [FileAccessRequest requestForPath: path withOptions: options reply: reply purposeIdentifier: purposeIdentifier];
	@synchronized(pendingRequests) {
		pendingRequests[cancellationToken] = request;
	}
	[request start];
};

static void handleWillMoveToURLNotification(NSString* oldPath, NSString* newPath) {
	FCDUnimplementedFunction();
};

static void handleDidMoveToURLNotification(NSString* oldPath, NSString* newPath) {
	FCDUnimplementedFunction();
};

static void handleDidChangeUbiquityAttributes(NSString* path, NSSet<NSURLResourceKey>* attributes) {
	FCDUnimplementedFunction();
};

static void handleNotification(DaemonNotificationType type, NSString* path, xpc_object_t details) {
	switch (type) {
		case DaemonNotificationTypeWillMoveToURL: {
			NSString* newPath = [NSString stringWithUTF8String: xpc_dictionary_get_string(details, DaemonNotificationDetailsNewPathKey)];

			handleWillMoveToURLNotification(path, newPath);
		} break;
		case DaemonNotificationTypeDidMoveToURL: {
			NSString* newPath = [NSString stringWithUTF8String: xpc_dictionary_get_string(details, DaemonNotificationDetailsNewPathKey)];

			handleDidMoveToURLNotification(path, newPath);
		} break;
		case DaemonNotificationTypeDidChangeUbiquityAttributes: {
			NSMutableSet<NSURLResourceKey>* attributes = [NSMutableSet set];

			xpc_array_apply(xpc_dictionary_get_value(details, DaemonNotificationDetailsChangedAttributesKey), ^bool(size_t index, xpc_object_t value) {
				[attributes addObject: [NSString stringWithUTF8String: xpc_string_get_string_ptr(value)]];
				return true;
			});

			handleDidChangeUbiquityAttributes(path, [NSSet setWithSet: attributes]);
		} break;
		default: {
			// invalid message
		} break;
	}
};

static void handleCancellation(NSFileAccessCancellationToken* cancellationToken) {
	FileAccessRequest* request = nil;
	@synchronized(pendingRequests) {
		request = pendingRequests[cancellationToken];
		[pendingRequests removeObjectForKey: cancellationToken];
	}
	if (request != nil) {
		[request cancel];
	}
};

static void handleNewConnection(xpc_connection_t connection) {
	XPCObject* connectionObject = [XPCObject objectWithXPCObject: connection];
	@synchronized(clients) {
		FCDDebug(@"new client: %@", connectionObject);
		[clients addObject: connectionObject];
	}

	xpc_connection_set_event_handler(connection, ^(xpc_object_t object) {
		@autoreleasepool {
			FCDDebug(@"received message from client %@: %@", connectionObject, xpc_nsdescription(object));
			xpc_type_t type = xpc_get_type(object);
			if (type == XPC_TYPE_ERROR) {
				if (object == XPC_ERROR_CONNECTION_INVALID) {
					// drop this client, it's no longer valid
					@synchronized(clients) {
						FCDDebug(@"dropping client %@", connectionObject);
						[clients removeObject: connectionObject];
					}
				} else {
					handleXPCError(object);
				}
			} else if (type == XPC_TYPE_DICTIONARY) {
				DaemonMessageType messageType = xpc_dictionary_get_uint64(object, DaemonMessageTypeKey);

				switch (messageType) {
					case DaemonMessageTypeIntent: {
						NSString* path = [NSString stringWithUTF8String: xpc_dictionary_get_string(object, DaemonIntentPathKey)];
						NSUInteger options = xpc_dictionary_get_uint64(object, DaemonIntentOptionsKey);
						NSFileAccessCancellationToken* cancellationToken = [NSString stringWithUTF8String: xpc_dictionary_get_string(object, DaemonIntentCancellationTokenKey)];
						NSString* purposeIdentifier = [NSString stringWithUTF8String: xpc_dictionary_get_string(object, DaemonIntentPurposeIdentifierKey)];
						XPCMessage* reply = [XPCMessage messageInReplyTo: [XPCMessage messageForConnection: connectionObject withRawMessage: [XPCObject objectWithXPCObject: object]]];

						handleIntent(reply, path, options, cancellationToken, purposeIdentifier);
					} break;
					case DaemonMessageTypeNotification: {
						DaemonNotificationType type = xpc_dictionary_get_uint64(object, DaemonNotificationTypeKey);
						NSString* path = [NSString stringWithUTF8String: xpc_dictionary_get_string(object, DaemonNotificationPathKey)];
						xpc_object_t details = xpc_dictionary_get_value(object, DaemonNotificationDetailsKey);

						handleNotification(type, path, details);
					} break;
					case DaemonMessageTypeCancellation: {
						NSFileAccessCancellationToken* cancellationToken = [NSString stringWithUTF8String: xpc_dictionary_get_string(object, DaemonCancellationCancellationTokenKey)];

						handleCancellation(cancellationToken);
					} break;
					default: {
						// invalid message and/or message sequence
						FCDLog(@"received invalid message and/or invalid message sequence from client %@ with message %@", connectionObject, xpc_nsdescription(object));
					} break;
				}
			} else {
				// huh?
				FCDLog(@"received non-dictionary and non-error message from libxpc; this is impossible (or at least it *should* be): %@", xpc_nsdescription(object));
			}
		}
	});
	xpc_connection_resume(connection);
};

int main(int argc, char** argv) {
	// our libxpc's `xpc_main` is not working yet
	//xpc_main(handle_new_connection);

	clients = [NSMutableSet new];
	pendingRequests = [NSMutableDictionary new];

	dispatch_queue_t queue = dispatch_queue_create(DAEMON_SERVICE_NAME ".connection-queue", DISPATCH_QUEUE_CONCURRENT);
	xpc_connection_t server = xpc_connection_create_mach_service(DAEMON_SERVICE_NAME, queue, XPC_CONNECTION_MACH_SERVICE_LISTENER);

	xpc_connection_set_event_handler(server, ^(xpc_object_t connection) {
		xpc_type_t type = xpc_get_type(connection);
		if (type == XPC_TYPE_CONNECTION) {
			handleNewConnection(connection);
		} else {
			// huh?
			FCDLog(@"received non-connection message from libxpc in main connection event handler: %@", xpc_nsdescription(connection));
		}
	});
	xpc_connection_resume(server);

	dispatch_main();
	return 0;
};
