#import <Foundation/NSCoder.h>
#import <xpc/xpc.h>

@class NSXPCConnection;

@interface NSXPCCoder : NSCoder {
    id<NSObject> _userInfo;
    NSXPCConnection *_connection;
}

@property(retain) id<NSObject> userInfo;
@property(readonly) NSXPCConnection *connection;

- (void) encodeXPCObject: (xpc_object_t) object
                  forKey: (NSString *) key;

- (xpc_object_t) decodeXPCObjectOfType: (xpc_type_t) type
                                forKey: (NSString *) key;

@end
