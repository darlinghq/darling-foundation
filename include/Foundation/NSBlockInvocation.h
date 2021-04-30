#import <Foundation/NSInvocation.h>

// implemented in CoreFoundation

@interface NSBlockInvocation : NSInvocation

@end

id __NSMakeSpecialForwardingCaptureBlock(const char* signature, void (^proxyBlock)(NSBlockInvocation*));
