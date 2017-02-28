#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSPointerFunctions.h>

@class NSWeakCallback;

struct NSSlice {
    void **items;
    BOOL wantsStrong;
    BOOL wantsWeak;
    BOOL wantsARC;
    BOOL shouldCopyIn;
    BOOL usesStrong;
    BOOL usesWeak;
    BOOL usesARC;
    BOOL usesSentinel;
    BOOL pointerPersonality;
    BOOL integerPersonality;
    BOOL simpleReadClear;
    NSWeakCallback *callback;
    NSUInteger (*sizeFunction)(const void *item);
    NSUInteger (*hashFunction)(const void *item, NSUInteger (*size)(const void *item));
    BOOL (*isEqualFunction)(const void *item1, const void*item2, NSUInteger (*size)(const void *item));
    NSString *(*describeFunction)(const void *item);
    void *(*acquireFunction)(const void *src, NSUInteger (*size)(const void *item), BOOL shouldCopy);
    void (*relinquishFunction)(const void *item, NSUInteger (*size)(const void *item));
    void *(*allocateFunction)(size_t count);
    void (*freeFunction)(void **buffer, NSUInteger size);
    void *(*readAt)(void **ptr, BOOL *wasSentinel);
    void (*clearAt)(void **ptr);
    void (*storeAt)(void **buffer, void *item, NSUInteger index);
};


@interface NSPointerArray : NSObject <NSFastEnumeration, NSCopying, NSCoding>
{
    struct NSSlice slice;
    NSUInteger count;
    NSUInteger capacity;
    NSUInteger options;
    NSUInteger mutations;
    BOOL needsCompaction;
}

+ (id)pointerArrayWithOptions:(NSPointerFunctionsOptions)options;
+ (id)pointerArrayWithPointerFunctions:(NSPointerFunctions *)functions;
- (id)initWithOptions:(NSPointerFunctionsOptions)options;
- (id)initWithPointerFunctions:(NSPointerFunctions *)functions;
- (NSPointerFunctions *)pointerFunctions;
- (void *)pointerAtIndex:(NSUInteger)index;
- (void)addPointer:(void *)pointer;
- (void)removePointerAtIndex:(NSUInteger)index;
- (void)insertPointer:(void *)item atIndex:(NSUInteger)index;
- (void)replacePointerAtIndex:(NSUInteger)index withPointer:(void *)item;
- (void)compact;
- (NSUInteger)count;
- (void)setCount:(NSUInteger)count;

@end

@interface NSPointerArray (NSPointerArrayConveniences)

+ (id)strongObjectsPointerArray;
+ (id)weakObjectsPointerArray;
- (NSArray *)allObjects;

@end
