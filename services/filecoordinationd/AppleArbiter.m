#import <Foundation/Foundation.h>

#import "daemon.h"
#import "logging.h"

// The NSXPC service of the file coordination daemon, for clients that run on Apple's Foundation (the dyld shared cache
// of a current macOS): its NSFileCoordinator talks NSXPC to com.apple.FileCoordination, not Darling's own protocol
// (that is on DAEMON_SERVICE_NAME). The message names and the claim class names below are the ones observed on the
// wire: -grantAccessClaim:withReply: with a claim argument and a reply of three arrays, a BOOL and an error, and the
// one-way -revokeAccessClaimForID:.
//
// Every claim is granted at once and no conflict between claims is tracked: coordination between processes that all
// use Apple's NSFileCoordinator is therefore not enforced, only between clients of the Darling protocol.

// Only the names matter here (the decoder looks the classes up by name); the contents of a claim are not read.
@interface NSFileAccessClaim : NSObject <NSSecureCoding>
@end

@implementation NSFileAccessClaim
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder: (NSCoder*)coder { return [super init]; }
- (void)encodeWithCoder: (NSCoder*)coder {}
@end

@interface NSFileWritingClaim : NSFileAccessClaim
@end
@implementation NSFileWritingClaim
@end

@interface NSFileReadingClaim : NSFileAccessClaim
@end
@implementation NSFileReadingClaim
@end

@protocol FCDAppleArbiter
- (void)grantAccessClaim: (NSFileAccessClaim*)claim withReply: (void (^)(NSArray*, NSArray*, NSArray*, BOOL, NSError*))reply;
- (oneway void)revokeAccessClaimForID: (NSString*)claimID;
@end

@interface FCDAppleArbiter : NSObject <FCDAppleArbiter, NSXPCListenerDelegate>
@end

@implementation FCDAppleArbiter

- (void)grantAccessClaim: (NSFileAccessClaim*)claim withReply: (void (^)(NSArray*, NSArray*, NSArray*, BOOL, NSError*))reply {
	FCDDebug(@"granting access claim %@", claim);
	reply(@[], @[], @[], YES, nil);
}

- (oneway void)revokeAccessClaimForID: (NSString*)claimID {
	FCDDebug(@"claim %@ revoked", claimID);
}

- (BOOL)listener: (NSXPCListener*)listener shouldAcceptNewConnection: (NSXPCConnection*)connection {
	NSXPCInterface* interface = [NSXPCInterface interfaceWithProtocol: @protocol(FCDAppleArbiter)];
	NSSet* claimClasses = [NSSet setWithObjects: [NSFileAccessClaim class], [NSFileWritingClaim class], [NSFileReadingClaim class], nil];
	[interface setClasses: claimClasses forSelector: @selector(grantAccessClaim:withReply:) argumentIndex: 0 ofReply: NO];
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
