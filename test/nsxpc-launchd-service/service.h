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
 * Asks the server to say hello to someone with the given name.
 */
- (void)greet: (NSString*)name;

/**
 * Asks the server to come up with some nonsense and tell you what it is via the given reply block.
 */
- (void)generateNonsense: (void(^)(NSString*))reply;

/**
 * Asks the server to look for objects with the given details and return them via the given callback block.
 */
- (void)findAllWithDetails: (NSDictionary<NSString*, id>*)details callback: (void(^)(NSArray<id>*))callback;

/**
 * Returns a reference to the common counter shared by all clients of the service via the given reply block.
 */
- (void)fetchSharedCounter: (void(^)(id<Counter>))reply;

@end
