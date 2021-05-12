#import <Foundation/Foundation.h>

#define NSXPC_TEST_LAUNCHD_SERVICE_NAME "org.darlinghq.Foundation.nsxpc-test-service"

@interface SomeCodableObject : NSObject <NSSecureCoding> {
	NSString* _someString;
	NSMutableArray<SomeCodableObject*>* _someOtherCodableObjects;
}

@property(copy) NSString* someString;
@property(readonly) NSMutableArray<SomeCodableObject*>* someOtherCodableObjects;

+ (BOOL)supportsSecureCoding;

- (instancetype)initWithCoder: (NSCoder*)coder;
- (void)encodeWithCoder: (NSCoder*)coder;

@end

@protocol Counter

/**
 * Increments the counter by the given amount.
 */
- (void)incrementCounter: (NSUInteger)amount;

/**
 * Returns the current value of the counter via the given reply block.
 */
- (void)fetchCounter: (void(^)(NSUInteger))reply;

@end

@protocol Service

/**
 * Say hello to the server.
 */
- (void)sayHello;

/**
 * Ask the server to say hello to someone with the given name.
 */
- (void)greet: (NSString*)name;

/**
 * Ask the server to come up with some nonsense and tell you what it is via the given reply block.
 */
- (void)generateNonsense: (void(^)(NSString*))reply;

/**
 * Ask the server to look for objects with the given details and return them via the given callback block.
 */
- (void)findAllWithDetails: (NSDictionary<NSString*, id>*)details callback: (void(^)(NSArray<id>*))callback;

/**
 * Returns a reference to the common counter shared by all clients of the service via the given reply block.
 */
- (void)fetchSharedCounter: (void(^)(id<Counter>))reply;

/**
 * Tell the server that you're also a server and give it an endpoint.
 */
- (void)broadcast: (NSXPCListenerEndpoint*)endpoint;

/**
 * Ask the server to find another server for us to talk to and have it return an endpoint for it in the given reply block.
 * Returns `nil` if no server was available.
 */
- (void)findAnotherServer: (void(^)(NSXPCListenerEndpoint*))reply;

/**
 * Ask the server to invalidate the connection on its end.
 */
- (void)invalidateConnection;

/**
 * Ask the server to wait for the given number of seconds to elapse before invoking the reply block.
 */
- (void)wait: (NSUInteger)secondsToWait reply: (void(^)(void))reply;

@end
