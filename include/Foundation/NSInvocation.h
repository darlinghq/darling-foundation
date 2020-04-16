#import <Foundation/NSObject.h>

@class NSMethodSignature, NSMutableArray;

@interface NSInvocation : NSObject
{
    void *_frame;
    void *_retdata;
    NSMethodSignature *_signature;
    NSMutableArray *_container;
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
