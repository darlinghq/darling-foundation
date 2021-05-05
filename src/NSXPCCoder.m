#import <Foundation/NSXPCCoder.h>
#import <xpc/xpc.h>
#import "NSXPCCoderInternal.h"

@implementation NSXPCCoder

@synthesize userInfo = _userInfo;
@synthesize connection = _connection;

- (void) encodeXPCObject: (xpc_object_t) object
                  forKey: (NSString *) key
{
    // Do nothing, overriden in NSXPCEncoder.
}

- (xpc_object_t) decodeXPCObjectOfType: (xpc_type_t) type
                                forKey: (NSString *) key
{
    // Do nothing, overriden in NSXPCDecoder.
    return NULL;
}

- (xpc_object_t) decodeXPCObjectForKey: (NSString *)key
{
    // Do nothing, overriden in NSXPCDecoder.
    return NULL;
}

- (BOOL) requiresSecureCoding {
    return YES;
}

- (void) dealloc {
    [_userInfo release];
    [_connection release];
    [super dealloc];
}

@end

@implementation NSXPCCoder (Internal)

- (void)setConnection: (NSXPCConnection*)connection
{
    NSXPCConnection* oldConnection = _connection;
    _connection = [connection retain];
    [oldConnection release];
}

@end
