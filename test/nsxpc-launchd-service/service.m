#import <Foundation/Foundation.h>

#import "service.h"

#include <stdatomic.h>

@interface Counter : NSObject <Counter> {
	_Atomic NSUInteger _counter;
}

@end

@interface ServiceDelegate : NSObject <NSXPCListenerDelegate, Service> {
	Counter* _counter;
}

@end

@implementation Counter

- (void)incrementCounter: (NSUInteger)amount
{
	_counter += amount;
}

- (void)fetchCounter: (void(^)(NSUInteger))reply
{
	reply(_counter);
}

@end

@implementation ServiceDelegate

- (void)sayHello
{
	NSLog(@"Client said hello.");
}

- (void)greet: (NSString*)name
{
	NSLog(@"Hello, %@!", name);
}

- (void)generateNonsense: (void(^)(NSString*))reply
{
	reply(@"The quizzical monkey hops atop a serene bungalow.");
}

- (void)findAllWithDetails: (NSDictionary<NSString*, id>*)details callback: (void(^)(NSArray<id>*))callback
{
	NSLog(@"User-provided details: %@", details);

	SomeCodableObject* someNonDefaultCodableObject = [[SomeCodableObject new] autorelease];
	someNonDefaultCodableObject.someString = @"Foo";

	callback(@[
		@123,
		@{
			@"This": @"works",
			@"This, too": @456,
			@"And this": @[
				@{
					@"Whoa": @"this is is a lot of objects",
				},
				@[
					@789,
					@1234,
				],
				@5678,
				@"Nice",
			],
		},
		@"Yeah",
		@9012,
		[[SomeCodableObject new] autorelease],
		someNonDefaultCodableObject,
	]);
}

- (void)fetchSharedCounter: (void(^)(id<Counter>))reply
{
	reply(_counter);
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

- (instancetype)init
{
	if (self = [super init]) {
		_counter = [Counter new];
	}
	return self;
}

- (void)dealloc
{
	[_counter release];
	[super dealloc];
}

@end

int main(int argc, char** argv) {
	ServiceDelegate* delegate = [ServiceDelegate new];
	NSXPCListener* listener = [[NSXPCListener alloc] initWithMachServiceName: @NSXPC_TEST_LAUNCHD_SERVICE_NAME];
	listener.delegate = delegate;
	[listener resume];

	[[NSRunLoop currentRunLoop] run];
	return 0;
};
