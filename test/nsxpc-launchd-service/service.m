#import <Foundation/Foundation.h>

#import "service.h"

#include <stdatomic.h>

@class ServiceDelegate;

@interface Counter : NSObject <Counter> {
	_Atomic NSUInteger _counter;
}

+ (instancetype)sharedCounter;

@end

@interface ServerPeer : NSObject <Service> {
	NSUInteger _identifier;
	ServiceDelegate* _delegate;
	NSMutableArray<NSXPCListenerEndpoint*>* _endpoints;
}

- (instancetype)initWithIdentifier: (NSUInteger)identifier delegate: (ServiceDelegate*)delegate;

@property(assign) NSUInteger identifier;
@property(assign /* actually weak */) ServiceDelegate* delegate;
@property(readonly) NSArray<NSXPCListenerEndpoint*>* endpoints;

@end

@interface ServiceDelegate : NSObject <NSXPCListenerDelegate> {
	_Atomic NSUInteger _nextIdentifier;
	NSMutableDictionary<NSNumber*, ServerPeer*>* _peersByIdentifier;
}

@property(readonly) NSDictionary<NSNumber*, ServerPeer*>* peersByIdentifier;

@end

@implementation Counter

+ (instancetype)sharedCounter
{
	static Counter* counter = nil;
	static dispatch_once_t token;
	dispatch_once(&token, ^{
		counter = [Counter new];
	});
	return counter;
}

- (void)incrementCounter: (NSUInteger)amount
{
	_counter += amount;
}

- (void)fetchCounter: (void(^)(NSUInteger))reply
{
	reply(_counter);
}

@end

@implementation ServerPeer

@synthesize identifier = _identifier;
@synthesize endpoints = _endpoints;

- (ServiceDelegate*)delegate
{
	return objc_loadWeak(&_delegate);
}

- (void)setDelegate: (ServiceDelegate*)delegate
{
	objc_storeWeak(&_delegate, delegate);
}

- (instancetype)initWithIdentifier: (NSUInteger)identifier delegate: (ServiceDelegate*)delegate
{
	if (self = [super init]) {
		self.identifier = identifier;
		self.delegate = delegate;
		_endpoints = [NSMutableArray new];
	}
	return self;
}

- (void)dealloc
{
	[_endpoints release];
	[super dealloc];
}

- (void)sayHello
{
	NSLog(@"Client #%lu said hello.", (long unsigned)self.identifier);
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
	reply([Counter sharedCounter]);
}

- (void)broadcast: (NSXPCListenerEndpoint*)endpoint
{
	@synchronized(_endpoints) {
		[_endpoints addObject: endpoint];
	}
}

- (void)findAnotherServer: (void(^)(NSXPCListenerEndpoint*))reply
{
	ServiceDelegate* delegate = self.delegate;

	if (!delegate) {
		reply(nil);
		return;
	}

	// TODO: make this more random
	@synchronized(delegate.peersByIdentifier) {
		for (ServerPeer* peer in delegate.peersByIdentifier.allValues) {
			@synchronized(peer.endpoints) {
				if (peer.endpoints.count == 0) {
					continue;
				}
				reply(peer.endpoints[arc4random_uniform(peer.endpoints.count)]);
				return;
			}
		}
	}

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

@end

@implementation ServiceDelegate

@synthesize peersByIdentifier = _peersByIdentifier;

- (BOOL)listener: (NSXPCListener*)listener shouldAcceptNewConnection: (NSXPCConnection*)connection
{
	NSXPCInterface* serviceInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Service)];
	NSXPCInterface* counterInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Counter)];
	ServerPeer* server = nil;

	[serviceInterface setInterface: counterInterface forSelector: @selector(fetchSharedCounter:) argumentIndex: 0 ofReply: YES];

	NSLog(@"Received new connection request from EUID %u, EGID %u, PID %u", connection.effectiveUserIdentifier, connection.effectiveGroupIdentifier, connection.processIdentifier);

	server = [[[ServerPeer alloc] initWithIdentifier: _nextIdentifier++ delegate: self] autorelease];

	@synchronized(_peersByIdentifier) {
		_peersByIdentifier[[NSNumber numberWithUnsignedInteger: server.identifier]] = server;
	}

	connection.exportedInterface = serviceInterface;
	connection.exportedObject = server;

	connection.invalidationHandler = ^{
		NSLog(@"Client connection got invalidated");
		@synchronized(_peersByIdentifier) {
			[_peersByIdentifier removeObjectForKey: [NSNumber numberWithUnsignedInteger: server.identifier]];
		}
	};

	[connection resume];
	return YES;
}

- (instancetype)init
{
	if (self = [super init]) {
		_peersByIdentifier = [NSMutableDictionary new];
	}
	return self;
}

- (void)dealloc
{
	[_peersByIdentifier release];
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
