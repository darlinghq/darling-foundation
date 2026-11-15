#import <Foundation/Foundation.h>

#import "daemon.h"
#import "logging.h"

// The NSXPC service of the file coordination daemon, for clients that run on Apple's Foundation (the dyld shared cache
// of a current macOS): its NSFileCoordinator talks NSXPC to com.apple.FileCoordination, not Darling's own protocol
// (that is on DAEMON_SERVICE_NAME).
//
// QUIRK: the message names, the claim class names and the reply layout below are not documented. Evidence: black-box
// observation, tier 2, of the XPC traffic between NSFileCoordinator and the system's file coordination service in a
// test program of our own, macOS 26.7.3 x86_64 (vd-upstream MAC-EVIDENCE.md, MC-V551):
// - -grantAccessClaim:withReply: takes a claim object (NSFileReadingClaim, NSFileWritingClaim or, for several items,
//   NSFileMultipleAccessClaim) and replies with two arrays, a third array, a BOOL and an NSError. For a claim nothing
//   else holds, the first array has one NSNull per item read (nil if none), the second one NSNull per item written
//   (nil if none), the third is nil, the BOOL is NO and the error is nil.
// - -revokeAccessClaimForID:, -revokeSubarbitrationClaimForID: and -removePresenterWithID: are one-way.
// - -addPresenter:withID:fileURL:lastPresentedItemEventIdentifier:ubiquityAttributes:options:responses: carries a
//   proxy of the client's presenter and has no reply.
// Test: tests/nsxpc-apple-arbiter-client.m (impl/V551-tests), which acts as such a client.
//
// Every claim is granted at once and no conflict between claims or presenters is tracked: coordination between
// processes that all use Apple's NSFileCoordinator is therefore not enforced, only between clients of the Darling
// protocol. A claim of a class not listed above, or any other message, is not understood and invalidates the
// connection of the client that sent it (the NSXPC rule for a message that cannot be decoded).

// A claim is decoded only as far as the number of items it covers; the URLs are not read.
@interface NSURLPromisePair : NSObject <NSSecureCoding>
@end

@implementation NSURLPromisePair
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder: (NSCoder*)coder { return [super init]; }
- (void)encodeWithCoder: (NSCoder*)coder {}
@end

@interface NSFileAccessClaim : NSObject <NSSecureCoding>
@property(readonly) NSUInteger readingItemCount;
@property(readonly) NSUInteger writingItemCount;
@end

@implementation NSFileAccessClaim
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder: (NSCoder*)coder { return [super init]; }
- (void)encodeWithCoder: (NSCoder*)coder {}
- (NSUInteger)readingItemCount { return 0; }
- (NSUInteger)writingItemCount { return 0; }
@end

@interface NSFileWritingClaim : NSFileAccessClaim
@end
@implementation NSFileWritingClaim
- (NSUInteger)writingItemCount { return 1; }
@end

@interface NSFileReadingClaim : NSFileAccessClaim
@end
@implementation NSFileReadingClaim
- (NSUInteger)readingItemCount { return 1; }
@end

@interface NSFileMultipleAccessClaim : NSFileAccessClaim {
	NSUInteger _reading;
	NSUInteger _writing;
}
@end
@implementation NSFileMultipleAccessClaim
- (instancetype)initWithCoder: (NSCoder*)coder {
	if ((self = [super initWithCoder: coder])) {
		NSSet* classes = [NSSet setWithObjects: [NSArray class], [NSMutableArray class], [NSURLPromisePair class], nil];
		_reading = [[coder decodeObjectOfClasses: classes forKey: @"NSReadingURLPairsKey"] count];
		_writing = [[coder decodeObjectOfClasses: classes forKey: @"NSWritingURLPairsKey"] count];
	}
	return self;
}
- (NSUInteger)readingItemCount { return _reading; }
- (NSUInteger)writingItemCount { return _writing; }
@end

// The presenter the client passes with -addPresenter:...; its methods are never called here.
@protocol FCDAppleArbiterPresenter
@end

@protocol FCDAppleArbiter
- (void)grantAccessClaim: (NSFileAccessClaim*)claim withReply: (void (^)(NSArray*, NSArray*, NSArray*, BOOL, NSError*))reply;
- (oneway void)revokeAccessClaimForID: (NSString*)claimID;
- (oneway void)revokeSubarbitrationClaimForID: (NSString*)claimID;
- (oneway void)removePresenterWithID: (NSString*)presenterID;
- (void)addPresenter: (id)presenter withID: (NSString*)presenterID fileURL: (NSURL*)url lastPresentedItemEventIdentifier: (id)eventIdentifier ubiquityAttributes: (NSDictionary*)attributes options: (unsigned long long)options responses: (unsigned long long)responses;
@end

@interface FCDAppleArbiter : NSObject <FCDAppleArbiter, NSXPCListenerDelegate>
@end

static NSArray* FCDNullEntries(NSUInteger count) {
	if (count == 0) {
		return nil;
	}
	NSMutableArray* entries = [NSMutableArray arrayWithCapacity: count];
	for (NSUInteger i = 0; i < count; i++) {
		[entries addObject: [NSNull null]];
	}
	return entries;
}

@implementation FCDAppleArbiter

- (void)grantAccessClaim: (NSFileAccessClaim*)claim withReply: (void (^)(NSArray*, NSArray*, NSArray*, BOOL, NSError*))reply {
	FCDDebug(@"granting access claim %@", claim);
	reply(FCDNullEntries(claim.readingItemCount), FCDNullEntries(claim.writingItemCount), nil, NO, nil);
}

- (oneway void)revokeAccessClaimForID: (NSString*)claimID {
	FCDDebug(@"claim %@ revoked", claimID);
}

- (oneway void)revokeSubarbitrationClaimForID: (NSString*)claimID {
	FCDDebug(@"subarbitration claim %@ revoked", claimID);
}

- (oneway void)removePresenterWithID: (NSString*)presenterID {
	FCDDebug(@"presenter %@ removed", presenterID);
}

- (void)addPresenter: (id)presenter withID: (NSString*)presenterID fileURL: (NSURL*)url lastPresentedItemEventIdentifier: (id)eventIdentifier ubiquityAttributes: (NSDictionary*)attributes options: (unsigned long long)options responses: (unsigned long long)responses {
	FCDDebug(@"presenter %@ added for %@", presenterID, url);
}

- (BOOL)listener: (NSXPCListener*)listener shouldAcceptNewConnection: (NSXPCConnection*)connection {
	NSXPCInterface* interface = [NSXPCInterface interfaceWithProtocol: @protocol(FCDAppleArbiter)];
	NSSet* claimClasses = [NSSet setWithObjects: [NSFileAccessClaim class], [NSFileWritingClaim class], [NSFileReadingClaim class], [NSFileMultipleAccessClaim class], [NSURLPromisePair class], [NSArray class], [NSMutableArray class], nil];
	[interface setClasses: claimClasses forSelector: @selector(grantAccessClaim:withReply:) argumentIndex: 0 ofReply: NO];
	SEL addPresenter = @selector(addPresenter:withID:fileURL:lastPresentedItemEventIdentifier:ubiquityAttributes:options:responses:);
	[interface setInterface: [NSXPCInterface interfaceWithProtocol: @protocol(FCDAppleArbiterPresenter)] forSelector: addPresenter argumentIndex: 0 ofReply: NO];
	NSSet* plainClasses = [NSSet setWithObjects: [NSString class], [NSNumber class], [NSNull class], [NSDictionary class], [NSArray class], [NSData class], [NSDate class], nil];
	[interface setClasses: plainClasses forSelector: addPresenter argumentIndex: 3 ofReply: NO];
	[interface setClasses: plainClasses forSelector: addPresenter argumentIndex: 4 ofReply: NO];
	connection.exportedInterface = interface;
	connection.exportedObject = self;
	[connection resume];
	return YES;
}

@end

void FCDStartAppleArbiter(void) {
	static NSXPCListener* listener = nil;
	static FCDAppleArbiter* arbiter = nil;
	arbiter = [[FCDAppleArbiter alloc] init];
	listener = [[NSXPCListener alloc] initWithMachServiceName: @APPLE_ARBITER_SERVICE_NAME];
	listener.delegate = arbiter;
	[listener resume];
}
