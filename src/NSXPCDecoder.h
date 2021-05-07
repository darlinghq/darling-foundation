#import <Foundation/NSXPCCoder.h>
#import <Foundation/NSXPCInterface.h>
#import <xpc/xpc.h>
#import "NSXPCSerialization.h"

CF_PRIVATE
@interface NSXPCDecoder : NSXPCCoder {
    xpc_object_t _oolObjects;
    struct NSXPCDeserializer _deserializer;
    struct NSXPCObject* _collection;
    NSUInteger _genericKey;
    struct NSXPCObject _rootObject;
    NSSet<Class>* _currentWhitelist;
}

- (void) _startReadingFromXPCObject: (xpc_object_t) object;

- (id) _decodeObjectOfClasses: (NSSet *) classes
                     atObject: (const struct NSXPCObject *) object;

- (xpc_object_t)_xpcObjectForIndex: (NSUInteger)index;

- (void) __decodeXPCObject: (xpc_object_t) object
 allowingSimpleMessageSend: (BOOL) allowSimpleMessageSend
             outInvocation: (NSInvocation **) invocation
              outArguments: (NSArray **) arguments
      outArgumentsMaxCount: (NSUInteger) argumentsMaxCount
        outMethodSignature: (NSMethodSignature **) signature
               outSelector: (SEL *) selector
                   isReply: (BOOL) isReply
             replySelector: (SEL) replySelector
                 interface: (NSXPCInterface *) interface;


- (void) _decodeMessageFromXPCObject: (xpc_object_t) object
           allowingSimpleMessageSend: (BOOL) allowSimpleMessageSend
                       outInvocation: (NSInvocation **) invocation
                        outArguments: (NSArray **) arguments
                outArgumentsMaxCount: (NSUInteger) argumentsMaxCount
                  outMethodSignature: (NSMethodSignature **) signature
                         outSelector: (SEL *) selector
                           interface: (NSXPCInterface *) interface;

- (NSInvocation*) _decodeReplyFromXPCObject: (xpc_object_t) object
                                forSelector: (SEL) selector
                                  interface: (NSXPCInterface*) interface;

// the key argument is only used for exception messages
- (void)_validateAllowedClass: (Class)class forKey: (NSString*)key allowingInvocations: (BOOL)allowingInvocations;
- (void)_validateAllowedXPCType: (xpc_type_t)type forKey: (NSString*)key;

@end
