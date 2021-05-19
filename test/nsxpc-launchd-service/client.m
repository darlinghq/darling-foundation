#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#import "service.h"

@protocol NSXPCProxyWithTimeout

@property double _timeout;

@end

@interface AnonymousServerDelegate : NSObject <NSXPCListenerDelegate, Service> {

}

@end

@implementation AnonymousServerDelegate

- (void)sayHello
{
	NSLog(@"Client said hello!");
}

- (void)greet: (NSString*)name
{
	NSLog(@"Hello, %@", name);
}

- (void)generateNonsense: (void(^)(NSString*))reply
{
	reply(@"This not is not actually not nonsense not!");
}

- (void)findAllWithDetails: (NSDictionary<NSString*, id>*)details callback: (void(^)(NSArray<id>*))callback
{
	callback(@[
		@"Not quite empty, but almost empty",
	]);
}

- (void)fetchSharedCounter: (void(^)(id<Counter>))reply
{
	reply(nil);
}

- (void)broadcast: (NSXPCListenerEndpoint*)endpoint
{
	NSLog(@"Received endpoint to broadcast, but we don't support that in anonymous servers.");
}

- (void)findAnotherServer: (void(^)(NSXPCListenerEndpoint*))reply
{
	reply(nil);
}

- (void)invalidateConnection
{
	[[NSXPCConnection currentConnection] invalidate];
}

- (void)wait: (NSUInteger)secondsToWait reply: (void(^)(void))reply
{
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, secondsToWait * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), reply);
}

- (BOOL)listener: (NSXPCListener*)listener shouldAcceptNewConnection: (NSXPCConnection*)connection
{
	NSXPCInterface* serviceInterface = generateServiceInterface();

	NSLog(@"Received new connection request from EUID %u, EGID %u, PID %u", connection.effectiveUserIdentifier, connection.effectiveGroupIdentifier, connection.processIdentifier);

	connection.invalidationHandler = ^{
		NSLog(@"Client connection got invalidated");
	};

	connection.exportedInterface = serviceInterface;
	connection.exportedObject = self;

	[connection resume];
	return YES;
}

@end

static void serve(id<Service> proxyService) {
	AnonymousServerDelegate* delegate = [AnonymousServerDelegate new];
	NSXPCListener* anon = [NSXPCListener anonymousListener];

	anon.delegate = delegate;

	[anon resume];

	[proxyService broadcast: anon.endpoint];

	[[NSRunLoop currentRunLoop] run];
};

int main(int argc, char** argv) {
	dispatch_semaphore_t waiter = dispatch_semaphore_create(0);
	dispatch_semaphore_t waiter2 = dispatch_semaphore_create(0);
	dispatch_semaphore_t synchronizer = dispatch_semaphore_create(0);
	dispatch_semaphore_t interrupted = dispatch_semaphore_create(0);
	__block NSXPCConnection* server = [[NSXPCConnection alloc] initWithMachServiceName: @NSXPC_TEST_LAUNCHD_SERVICE_NAME];
	NSXPCInterface* serviceInterface = generateServiceInterface();
	__block id<Service, NSObject, NSXPCProxyWithTimeout> service = nil;

	server.remoteObjectInterface = serviceInterface;

	[server resume];

	service = server.remoteObjectProxy;

	if (argc > 1 && tolower(argv[1][0]) == 'c') {
		// 'c' for "connect"

		[service findAnotherServer: ^(NSXPCListenerEndpoint* endpoint) {
			NSXPCConnection* anonServer = nil;

			if (!endpoint) {
				NSLog(@"Server didn't have another server for us to connect to");
				exit(0);
			}

			anonServer = [[NSXPCConnection alloc] initWithListenerEndpoint: endpoint];

			[server release];
			server = anonServer;

			server.remoteObjectInterface = serviceInterface;

			[server resume];

			dispatch_semaphore_signal(waiter);
		}];

		dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);

		service = server.remoteObjectProxy;
	} else if (argc > 1 && tolower(argv[1][0]) == 's') {
		// 's' for "serve"
		serve(service);
		return 0;
	}

	[service sayHello];

	[service greet: @"User"];

	[service generateNonsense: ^(NSString* nonsense) {
		NSLog(@"The server told me to say: %@", nonsense);
		dispatch_semaphore_signal(waiter);
	}];

	[service findAllWithDetails: @{
		@"Find": @"something",
		@"Like": @"this",
	} callback: ^(NSArray<id>* results) {
		NSLog(@"Server returned results: %@", results);
		dispatch_semaphore_signal(waiter);
	}];

	[service fetchSharedCounter: ^(id<Counter, NSXPCProxyCreating> counter) {
		id<Counter, NSXPCProxyCreating> counterWithErrorHandler = nil;

		if (!counter) {
			NSLog(@"Server didn't have a counter for us");
			dispatch_semaphore_signal(waiter);
			return;
		}

		NSLog(@"Received counter reference; going to increment it...");
		[counter incrementCounter: 1];
		[counter fetchCounter: ^(NSUInteger value) {
			NSLog(@"Fetched current counter value: %lu", (long)value);
			dispatch_semaphore_signal(waiter);
		}];

		counterWithErrorHandler = [counter remoteObjectProxyWithErrorHandler: ^(NSError* error) {
			NSLog(@"Counter with error handler received error: %@", error);
			dispatch_semaphore_signal(waiter2);
		}];

		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			dispatch_semaphore_signal(synchronizer);
			dispatch_semaphore_wait(waiter2, DISPATCH_TIME_FOREVER);
			[counterWithErrorHandler fetchCounter: ^(NSUInteger value) {
				NSLog(@"Counter with error handler successfully fetched counter value? That wasn't supposed to happen! The value is %lu", (long)value);
				dispatch_semaphore_signal(waiter2);
			}];
		});
	}];

	NSLog(@"Responds to `sayHello`? %@", [service respondsToSelector: @selector(sayHello)] ? @"YES" : @"NO");
	NSLog(@"Responds to `lolNope`? %@", [service respondsToSelector: @selector(lolNope)] ? @"YES" : @"NO");

	// setup an interruption handler for later
	server.interruptionHandler = ^{
		NSLog(@"The connection was interrupted");
		dispatch_semaphore_signal(interrupted);
	};

	dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);
	dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);
	dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);

	// now let's test non-root proxy invalidation upon interruption (using the counter)
	dispatch_semaphore_wait(synchronizer, DISPATCH_TIME_FOREVER);
	[service invalidateConnection];
	dispatch_semaphore_signal(waiter2);

	dispatch_semaphore_wait(waiter2, DISPATCH_TIME_FOREVER);

	// now let's try sending a message back over the connection to see if it will reconnect

	// first, we must wait for interruption to be signaled;
	// this is because otherwise we race against the interruption notification and might send the message before the connection gets notified of interruption
	// (the error handler for the proxy would get invoked properly due to send failure, but not the actual connection interruption handler; that one could be slightly delayed)

	dispatch_semaphore_wait(interrupted, DISPATCH_TIME_FOREVER);

	[service generateNonsense: ^(NSString* nonsense) {
		NSLog(@"The second time--after reconnecting--the server told me to say: %@", nonsense);
		dispatch_semaphore_signal(waiter);
	}];

	dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);

	// finally, let's test out the timeout.
	// this should trigger an invalidation.

	NSLog(@"Going to wait 5 seconds for the timeout...");

	server.invalidationHandler = ^{
		NSLog(@"The connection was invalidated");
		dispatch_semaphore_signal(waiter);
	};

	// invalidate the connection after 5 seconds of waiting for a reply
	service._timeout = 5;

	// this should not trigger the timeout
	[service wait: 3 reply: ^{
		NSLog(@"Waited 3 seconds and did not trigger the timeout");
		dispatch_semaphore_signal(waiter);
	}];

	// ask the server to wait for 6 seconds before calling back
	[service wait: 6 reply: ^{
		NSLog(@"Huh? Waiting for a timeout failed and we actually received a reply!");
		dispatch_semaphore_signal(waiter);
	}];

	dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);
	dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);

	return 0;
};
