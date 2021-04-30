#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <objc/runtime.h>
#import <xpc/xpc.h>

@class _NSXPCInterfaceMethodInfo;

// NSXPCInterface describes an interface for a proxy.
@interface NSXPCInterface : NSObject {
    Protocol * _protocol;
    NSUInteger _remoteVersion;
    Class _distantObjectClass;
    NSMutableDictionary<NSString *, _NSXPCInterfaceMethodInfo *> *_methods;
}

@property(assign) Protocol *protocol;
@property(readonly) Class _distantObjectClass;

+ (instancetype) interfaceWithProtocol: (Protocol *) protocol;

- (NSSet *) classesForSelector: (SEL) selelector
                 argumentIndex: (NSUInteger) argumentIndex
                       ofReply: (BOOL) isReply;

- (NSXPCInterface *) interfaceForSelector: (SEL) selector
                            argumentIndex: (NSUInteger) argumentIndex
                                  ofReply: (BOOL) isReply;

- (xpc_type_t) XPCTypeForSelector: (SEL) selector
                    argumentIndex: (NSUInteger) argumentIndex
                          ofReply: (BOOL) isReply;

- (void) setClass: (Class) klass
      forSelector: (SEL) selector
    argumentIndex: (NSUInteger) argumentIndex
          ofReply: (BOOL) isReply;

- (void) setClasses: (NSSet<Class> *) classes
        forSelector: (SEL) selector
      argumentIndex: (NSUInteger) argumentIndex
            ofReply: (BOOL) isReply;

- (void) setInterface: (NSXPCInterface *) interface
          forSelector: (SEL) selector
        argumentIndex: (NSUInteger) argumentIndex
              ofReply: (BOOL) isReply;

- (void) setXPCType: (xpc_type_t) type
        forSelector: (SEL) selector
      argumentIndex: (NSUInteger) argumentIndex
            ofReply: (BOOL) isReply;

- (NSMethodSignature *) _methodSignatureForRemoteSelector: (SEL) selector;
- (NSMethodSignature*)replyBlockSignatureForSelector: (SEL)selector;

@end
