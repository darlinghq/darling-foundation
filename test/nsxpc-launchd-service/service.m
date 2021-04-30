#import <Foundation/Foundation.h>

#import "service.h"

@interface ServiceDelegate : NSObject <NSXPCListenerDelegate, Service>

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

- (BOOL)listener: (NSXPCListener*)listener shouldAcceptNewConnection: (NSXPCConnection*)connection
{
	NSLog(@"Received new connection request from EUID %u, EGID %u, PID %u", connection.effectiveUserIdentifier, connection.effectiveGroupIdentifier, connection.processIdentifier);

	connection.invalidationHandler = ^{
		NSLog(@"Client connection got invalidated");
	};

	connection.exportedInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Service)];
	connection.exportedObject = self;

	[connection resume];
	return YES;
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
