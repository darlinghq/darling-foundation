#import <Foundation/NSXPCCoder.h>
#import <xpc/xpc.h>
#import "NSXPCSerialization.h"

CF_PRIVATE
@interface NSXPCEncoder : NSXPCCoder {
    xpc_object_t _oolObjects;
    struct NSXPCSerializer _serializer;
    NSUInteger _genericKey;
}

- (instancetype) initWithStackSpace: (unsigned char *) buffer
                               size: (size_t) bufferSize;

- (void) _encodeObject: (id) object;
- (void) _encodeUnkeyedObject: (id) object;

- (void) _encodeInvocation: (NSInvocation *) invocation
                   isReply: (BOOL) isReply
                      into: (xpc_object_t) destinationDictionary;

@end
