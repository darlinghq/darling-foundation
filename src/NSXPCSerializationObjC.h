#import "NSXPCSerialization.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSSet.h>

@class NSXPCEncoder, NSXPCDecoder;
@class NSInvocation, NSMethodSignature;

CF_PRIVATE
void _NSXPCSerializationAddTypedObjCValuesToArray(
    NSXPCEncoder *encoder,
    struct NSXPCSerializer *serializer,
    const char *type,
    const void *addr
);

CF_PRIVATE
void _NSXPCSerializationAddInvocationArgumentsArray(
    NSInvocation *invocation,
    NSMethodSignature *signature,
    NSXPCEncoder *encoder,
    struct NSXPCSerializer *serializer,
    bool isReply
);

CF_PRIVATE
void _NSXPCSerializationDecodeTypedObjCValuesFromArray(
    NSXPCDecoder *decoder,
    struct NSXPCDeserializer *deserializer,
    const char *type,
    void *addr,
    BOOL unknown1,
    const struct NSXPCObject *containerObject,
    struct NSXPCObject *object,
    NSInvocation *invocation,
    NSSet *classes
);

CF_PRIVATE
void _NSXPCSerializationDecodeInvocationArgumentArray(
    NSInvocation *invocation,
    NSMethodSignature *signature,
    NSXPCDecoder *decoder,
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    NSArray<NSSet *> *classesForArguments,
    bool isReply
);
