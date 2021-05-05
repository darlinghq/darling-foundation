#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#import "service.h"

int main(int argc, char** argv) {
	dispatch_semaphore_t waiter = dispatch_semaphore_create(0);
	NSXPCConnection* server = [[NSXPCConnection alloc] initWithMachServiceName: @NSXPC_TEST_LAUNCHD_SERVICE_NAME];
	NSXPCInterface* serviceInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Service)];
	NSXPCInterface* counterInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Counter)];

	[serviceInterface setInterface: counterInterface forSelector: @selector(fetchSharedCounter:) argumentIndex: 0 ofReply: YES];

	server.remoteObjectInterface = serviceInterface;

	[server resume];

	id<Service> service = server.remoteObjectProxy;

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
