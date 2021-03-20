#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>
#import <objc/runtime.h>

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

- (NSMethodSignature *) _methodSignatureForRemoteSelector: (SEL) selector;

@end
