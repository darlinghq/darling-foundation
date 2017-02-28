#import <Foundation/NSPointerFunctions.h>
#import <Foundation/NSPointerArray.h>
#import "NSObjectInternal.h"

#define NSPointerFunctionsMemoryTypeMask 0xff
#define NSPointerFunctionsPersonalityMask 0xff00

#define NSPointerFunctionsMemoryType(options) (options & NSPointerFunctionsMemoryTypeMask)
#define NSPointerFunctionsPersonality(options) (options & NSPointerFunctionsPersonalityMask)

#define NSPointerFunctionsOptionsInvalid (-1)

CF_PRIVATE
@interface NSWeakCallback : NSObject {
    id _callback_next;
    void *_callback_function;
    id _callback_target;
}

@end

CF_PRIVATE
extern void * const _NSPointerFunctionsSentinel;

CF_PRIVATE
@interface NSConcretePointerFunctions : NSPointerFunctions {
@package
    struct NSSlice slice;
}

@property NSUInteger (*hashFunction)(const void *item, NSUInteger (*size)(const void *item));
@property BOOL (*isEqualFunction)(const void *item1, const void*item2, NSUInteger (*size)(const void *item));
@property NSUInteger (*sizeFunction)(const void *item);
@property NSString *(*descriptionFunction)(const void *item);
@property void (*relinquishFunction)(const void *item, NSUInteger (*size)(const void *item));
@property void *(*acquireFunction)(const void *src, NSUInteger (*size)(const void *item), BOOL shouldCopy);
@property BOOL usesStrongWriteBarrier;
@property BOOL usesWeakReadAndWriteBarriers;

+ (BOOL)initializeSlice:(struct NSSlice *)aSlice withOptions:(NSPointerFunctionsOptions)options;
+ (void)initializeBackingStore:(struct NSSlice *)aSlice sentinel:(BOOL)sentinel compactable:(BOOL)compactable;
- (id)initWithOptions:(NSPointerFunctionsOptions)options;
- (BOOL)isEqual:(id)other;
- (NSUInteger)hash;
- (id)copyWithZone:(NSZone *)zone;

@end
