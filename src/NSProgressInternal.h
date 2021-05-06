#import <Foundation/NSProgress.h>
#import <xpc/xpc.h>

@class NSXPCConnection;

@interface _NSProgressWithRemoteParent : NSProgress {
	NSUInteger _sequence;
	NSXPCConnection* _parentConnection;
}

@property NSUInteger sequence;
@property(retain) NSXPCConnection* parentConnection;

@end

@interface NSProgress (NSProgressUpdateOverXPC)

- (void)_receiveProgressMessage: (xpc_object_t)message forSequence: (NSUInteger)sequence;

@end
