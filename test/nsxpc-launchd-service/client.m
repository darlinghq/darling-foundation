#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#import "service.h"

#ifndef TEST_SECURE_CODING
	#define TEST_SECURE_CODING 0
#endif

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

- (BOOL)listener: (NSXPCListener*)listener shouldAcceptNewConnection: (NSXPCConnection*)connection
{
	NSXPCInterface* serviceInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Service)];
	NSXPCInterface* counterInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Counter)];

	[serviceInterface setInterface: counterInterface forSelector: @selector(fetchSharedCounter:) argumentIndex: 0 ofReply: YES];

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
	__block NSXPCConnection* server = [[NSXPCConnection alloc] initWithMachServiceName: @NSXPC_TEST_LAUNCHD_SERVICE_NAME];
	NSXPCInterface* serviceInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Service)];
	NSXPCInterface* counterInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Counter)];
	__block id<Service> service = nil;

	[serviceInterface setInterface: counterInterface forSelector: @selector(fetchSharedCounter:) argumentIndex: 0 ofReply: YES];

#if TEST_SECURE_CODING
	// purposefully set the wrong classes to see if our de/serialization will catch it

	// validate outgoing object; not sure if NSXPC should catch this
	// currently, we don't catch this; TODO: check official NSXPC behavior
	[serviceInterface setClasses: [NSSet setWithObjects: [NSNumber class], nil] forSelector: @selector(greet:) argumentIndex: 0 ofReply: NO];

	// validate incoming object; definitely supposed to be caught
	[serviceInterface setClasses: [NSSet setWithObjects: [NSNumber class], nil] forSelector: @selector(generateNonsense:) argumentIndex: 0 ofReply: YES];
#endif

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

	[service fetchSharedCounter: ^(id<Counter> counter) {
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
	}];

	dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);
	dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);
	dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);

	return 0;
};
