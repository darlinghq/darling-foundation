#import <Foundation/NSObject.h>
#import <CoreFoundation/CFString.h>

typedef struct {
    NSUInteger size;
    NSUInteger alignment;
    size_t offset;
    char *type;
} NSMethodType;

@interface NSMethodSignature : NSObject {
    NSMethodType *_types;
    CFMutableStringRef _typeString;
    NSUInteger _count;
    NSUInteger _frameLength;
    BOOL _isOneway;
    BOOL _stret;
}

+ (NSMethodSignature *)signatureWithObjCTypes:(const char *)types;
- (NSUInteger)numberOfArguments;
- (const char *)getArgumentTypeAtIndex:(NSUInteger)idx NS_RETURNS_INNER_POINTER;
- (NSUInteger)frameLength;
- (BOOL)isOneway;
- (const char *)methodReturnType NS_RETURNS_INNER_POINTER;
- (NSUInteger)methodReturnLength;

@end

@interface NSMethodSignature (Internal)
- (NSString *) _typeString;
@end
