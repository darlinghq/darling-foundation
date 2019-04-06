#import <Foundation/NSObject.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSObjCRuntime.h>

typedef NS_OPTIONS(NSUInteger, NSBinarySearchingOptions) {
    NSBinarySearchingFirstEqual     = (1UL << 8),
    NSBinarySearchingLastEqual      = (1UL << 9),
    NSBinarySearchingInsertionIndex = (1UL << 10),
};

@class NSData, NSIndexSet, NSString, NSURL;

@interface NSArray<__covariant ObjectType> : NSObject <NSCopying, NSMutableCopying, NSSecureCoding, NSFastEnumeration>

- (NSUInteger)count;
- (id)objectAtIndex:(NSUInteger)idx;

@end

@interface NSArray<ObjectType> (NSExtendedArray)

- (NSArray<ObjectType> *)arrayByAddingObject:(ObjectType)obj;
- (NSArray<ObjectType> *)arrayByAddingObjectsFromArray:(NSArray<ObjectType> *)other;
- (NSString *)componentsJoinedByString:(NSString *)sep;
- (BOOL)containsObject:(ObjectType)obj;
- (NSString *)description;
- (NSString *)descriptionWithLocale:(id)locale;
- (NSString *)descriptionWithLocale:(id)locale indent:(NSUInteger)level;
- (id)firstObjectCommonWithArray:(NSArray<ObjectType> *)other;
- (void)getObjects:(ObjectType [])objects range:(NSRange)range;
- (NSUInteger)indexOfObject:(ObjectType)obj;
- (NSUInteger)indexOfObject:(ObjectType)obj inRange:(NSRange)range;
- (NSUInteger)indexOfObjectIdenticalTo:(ObjectType)obj;
- (NSUInteger)indexOfObjectIdenticalTo:(ObjectType)obj inRange:(NSRange)range;
- (BOOL)isEqualToArray:(NSArray<ObjectType> *)other;
- (ObjectType)firstObject;
- (ObjectType)lastObject;
- (NSEnumerator<ObjectType> *)objectEnumerator;
- (NSEnumerator<ObjectType> *)reverseObjectEnumerator;
- (NSData *)sortedArrayHint;
- (NSArray<ObjectType> *)sortedArrayUsingFunction:(NSInteger (*)(ObjectType, ObjectType, void *))comparator context:(void *)context;
- (NSArray<ObjectType> *)sortedArrayUsingFunction:(NSInteger (*)(ObjectType, ObjectType, void *))comparator context:(void *)context hint:(NSData *)hint;
- (NSArray<ObjectType> *)sortedArrayUsingSelector:(SEL)comparator;
- (NSArray<ObjectType> *)subarrayWithRange:(NSRange)range;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)atomically;
- (BOOL)writeToURL:(NSURL *)url atomically:(BOOL)atomically;
- (void)makeObjectsPerformSelector:(SEL)sel;
- (void)makeObjectsPerformSelector:(SEL)sel withObject:(id)aeg;
- (NSArray<ObjectType> *)objectsAtIndexes:(NSIndexSet *)indices;
- (ObjectType)objectAtIndexedSubscript:(NSUInteger)idx;
#if NS_BLOCKS_AVAILABLE
- (void)enumerateObjectsUsingBlock:(void (^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (void)enumerateObjectsAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts usingBlock:(void (^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (NSUInteger)indexOfObjectPassingTest:(BOOL (^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (NSUInteger)indexOfObjectAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts passingTest:(BOOL (^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (NSIndexSet *)indexesOfObjectsPassingTest:(BOOL (^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (NSIndexSet *)indexesOfObjectsWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (NSIndexSet *)indexesOfObjectsAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts passingTest:(BOOL (^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (NSArray<ObjectType> *)sortedArrayUsingComparator:(NSComparator)comparator;
- (NSArray<ObjectType> *)sortedArrayWithOptions:(NSSortOptions)opts usingComparator:(NSComparator)comparator;
- (NSUInteger)indexOfObject:(ObjectType)obj inSortedRange:(NSRange)r options:(NSBinarySearchingOptions)opts usingComparator:(NSComparator)comparator;
#endif

@end

@interface NSArray<ObjectType> (NSArrayCreation)

+ (instancetype)array;
+ (instancetype)arrayWithObject:(ObjectType)obj;
+ (instancetype)arrayWithObjects:(const ObjectType [])objects count:(NSUInteger)cnt;
+ (instancetype)arrayWithObjects:(ObjectType)firstObj, ... NS_REQUIRES_NIL_TERMINATION;
+ (instancetype)arrayWithArray:(NSArray<ObjectType> *)array;

- (instancetype)initWithObjects:(const ObjectType [])objects count:(NSUInteger)cnt;
- (instancetype)initWithObjects:(ObjectType)firstObj, ... NS_REQUIRES_NIL_TERMINATION;
- (instancetype)initWithArray:(NSArray<ObjectType> *)array;
- (instancetype)initWithArray:(NSArray<ObjectType> *)array copyItems:(BOOL)flag;
+ (instancetype)arrayWithContentsOfFile:(NSString *)path;
+ (instancetype)arrayWithContentsOfURL:(NSURL *)url;
- (instancetype)initWithContentsOfFile:(NSString *)path;
- (instancetype)initWithContentsOfURL:(NSURL *)url;

@end

@interface NSArray<ObjectType> (NSDeprecated)

- (void)getObjects:(ObjectType [])objects;

@end

@interface NSMutableArray<ObjectType> : NSArray

- (instancetype)init;
- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (void)addObject:(ObjectType)obj;
- (void)insertObject:(ObjectType)obj atIndex:(NSUInteger)idx;
- (void)removeLastObject;
- (void)removeObjectAtIndex:(NSUInteger)idx;
- (void)replaceObjectAtIndex:(NSUInteger)idx withObject:(ObjectType)obj;

@end

@interface NSMutableArray<ObjectType> (NSExtendedMutableArray)

- (void)addObjectsFromArray:(NSArray<ObjectType> *)other;
- (void)exchangeObjectAtIndex:(NSUInteger)idx1 withObjectAtIndex:(NSUInteger)idx2;
- (void)removeAllObjects;
- (void)removeObject:(ObjectType)obj inRange:(NSRange)range;
- (void)removeObject:(ObjectType)obj;
- (void)removeObjectIdenticalTo:(ObjectType)obj inRange:(NSRange)range;
- (void)removeObjectIdenticalTo:(ObjectType)obj;
- (void)removeObjectsFromIndices:(NSUInteger *)indices numIndices:(NSUInteger)cnt;
- (void)removeObjectsInArray:(NSArray<ObjectType> *)other;
- (void)removeObjectsInRange:(NSRange)range;
- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray<ObjectType> *)other range:(NSRange)otherRange;
- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray<ObjectType> *)other;
- (void)setArray:(NSArray<ObjectType> *)other;
- (void)sortUsingFunction:(NSInteger (*)(ObjectType, ObjectType, void *))compare context:(void *)context;
- (void)sortUsingSelector:(SEL)comparator;
- (void)insertObjects:(NSArray<ObjectType> *)objects atIndexes:(NSIndexSet *)indices;
- (void)removeObjectsAtIndexes:(NSIndexSet *)indices;
- (void)replaceObjectsAtIndexes:(NSIndexSet *)indices withObjects:(NSArray<ObjectType> *)objects;
- (void)setObject:(ObjectType)obj atIndexedSubscript:(NSUInteger)idx;
#if NS_BLOCKS_AVAILABLE
- (void)sortUsingComparator:(NSComparator)comparator;
- (void)sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparator)comparator;
#endif

@end

@interface NSMutableArray<ObjectType> (NSMutableArrayCreation)

+ (instancetype)arrayWithCapacity:(NSUInteger)numItems;

+ (NSMutableArray<ObjectType> *)arrayWithContentsOfFile:(NSString *)path;
+ (NSMutableArray<ObjectType> *)arrayWithContentsOfURL:(NSURL *)url;
- (NSMutableArray<ObjectType> *)initWithContentsOfFile:(NSString *)path;
- (NSMutableArray<ObjectType> *)initWithContentsOfURL:(NSURL *)url;

@end
