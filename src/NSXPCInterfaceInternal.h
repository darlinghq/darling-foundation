#import <Foundation/NSXPCInterface.h>

@class NSMethodSignature, NSMutableArray, NSSet;

@interface _NSXPCInterfaceMethodInfo : NSObject {
	NSMethodSignature* _methodSignature;
	NSMethodSignature* _replyBlockSignature;
	NSMutableArray<NSSet<Class>*>* _parameterClassesWhitelist;
	NSMutableArray<NSSet<Class>*>* _replyParameterClassesWhitelist;
	NSMutableArray<NSXPCInterface*>* _parameterInterfaces;
	NSMutableArray<NSXPCInterface*>* _replyParameterInterfaces;
	NSMutableArray<Class>* _parameterXPCWhitelist;
	NSMutableArray<Class>* _replyParameterXPCWhitelist;
	Class _returnClass;
}

@property(readonly) NSMethodSignature* methodSignature;
@property(readonly) NSMethodSignature* replyBlockSignature;
@property(readonly) NSMutableArray<NSSet<Class>*>* parameterClassesWhitelist;
@property(readonly) NSMutableArray<NSSet<Class>*>* replyParameterClassesWhitelist;
@property(readonly) NSMutableArray<NSXPCInterface*>* parameterInterfaces;
@property(readonly) NSMutableArray<NSXPCInterface*>* replyParameterInterfaces;
@property(readonly) NSMutableArray<Class>* parameterXPCWhitelist;
@property(readonly) NSMutableArray<Class>* replyParameterXPCWhitelist;
@property(readonly) Class returnClass;

- (instancetype)initWithProtocol: (Protocol*)protocol selector: (SEL)selector;

@end

@interface NSXPCInterface (Internal)

- (NSXPCInterface*)_interfaceForArgument: (NSUInteger)argumentIndex ofSelector: (SEL)selector reply: (BOOL)ofReply;
- (Class)_returnClassForSelector: (SEL)selector;
- (BOOL)_hasProxiesInReplyBlockArgumentsOfSelector: (SEL)selector;
- (NSArray<NSSet*>*)_allowedClassesForSelector: (SEL)selector reply: (BOOL)isReply;

/**
 * Possible return values:
 * - 0 = DOES respond to selector
 * - 1 = DOES NOT respond to selector
 * - 2 = DOES respond to selector, but versions aren't compatible
 */
- (char)_respondsToRemoteSelector: (SEL)selector;

@end
