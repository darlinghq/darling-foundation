#import <Foundation/NSObject.h>
#import <stdbool.h>

@class NSMethodSignature;

@interface NSInvocation : NSObject
{
    __strong void *_frame;
    __strong void *_retdata;
    NSMethodSignature *_signature;
    id      *_container;
    uint8_t _retainedArgs;
    uint8_t _reserved[15];
}

+ (NSInvocation *)invocationWithMethodSignature:(NSMethodSignature *)sig;
- (NSMethodSignature *)methodSignature;
- (void)retainArguments;
- (BOOL)argumentsRetained;
- (id)target;
- (void)setTarget:(id)target;
- (SEL)selector;
- (void)setSelector:(SEL)selector;
- (void)getReturnValue:(void *)retLoc;
- (void)setReturnValue:(void *)retLoc;
- (void)getArgument:(void *)argumentLocation atIndex:(NSInteger)idx;
- (void)setArgument:(void *)argumentLocation atIndex:(NSInteger)idx;
- (void)invoke;
- (void)invokeWithTarget:(id)target;

@end
