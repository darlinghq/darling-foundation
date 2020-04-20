#import <Foundation/NSObject.h>
#import <Foundation/NSEnumerator.h>

@class NSArray, NSDictionary, NSString;

@interface NSSet<__covariant ObjectType> : NSObject <NSCopying, NSMutableCopying, NSSecureCoding, NSFastEnumeration>

- (NSUInteger)count;
- (ObjectType)member:(ObjectType)object;
- (NSEnumerator<ObjectType> *)objectEnumerator;

@end

@interface NSSet<__covariant ObjectType> (NSExtendedSet)

- (NSArray *)allObjects;
- (ObjectType)anyObject;
- (BOOL)containsObject:(ObjectType)anObject;
- (NSString *)description;
- (NSString *)descriptionWithLocale:(id)locale;
- (BOOL)intersectsSet:(NSSet *)other;
- (BOOL)isEqualToSet:(NSSet *)other;
- (BOOL)isSubsetOfSet:(NSSet *)other;
- (void)makeObjectsPerformSelector:(SEL)sel;
- (void)makeObjectsPerformSelector:(SEL)sel withObject:(id)argument;
- (NSSet<ObjectType> *)setByAddingObject:(ObjectType)anObject;
- (NSSet<ObjectType> *)setByAddingObjectsFromSet:(NSSet<ObjectType> *)other;
- (NSSet<ObjectType> *)setByAddingObjectsFromArray:(NSArray<ObjectType> *)other;
#if NS_BLOCKS_AVAILABLE
- (void)enumerateObjectsUsingBlock:(void (^)(ObjectType obj, BOOL *stop))block;
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(ObjectType obj, BOOL *stop))block;
- (NSSet *)objectsPassingTest:(BOOL (^)(ObjectType obj, BOOL *stop))predicate;
- (NSSet *)objectsWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (^)(ObjectType obj, BOOL *stop))predicate;
#endif

@end

@interface NSSet<__covariant ObjectType> (NSSetCreation)

+ (instancetype)set;
+ (instancetype)setWithObject:(id)object;
+ (instancetype)setWithObjects:(const ObjectType [])objects count:(NSUInteger)cnt;
+ (instancetype)setWithObjects:(ObjectType)firstObj, ... NS_REQUIRES_NIL_TERMINATION;
+ (instancetype)setWithSet:(NSSet<ObjectType> *)set;
+ (instancetype)setWithArray:(NSArray<ObjectType> *)array;
- (instancetype)initWithObjects:(const ObjectType [])objects count:(NSUInteger)cnt;
- (instancetype)initWithObjects:(ObjectType)firstObj, ... NS_REQUIRES_NIL_TERMINATION;
- (instancetype)initWithSet:(NSSet<ObjectType> *)set;
- (instancetype)initWithSet:(NSSet<ObjectType> *)set copyItems:(BOOL)flag;
- (instancetype)initWithArray:(NSArray<ObjectType> *)array;

@end

@interface NSMutableSet<__covariant ObjectType> : NSSet

- (void)addObject:(ObjectType)object;
- (void)removeObject:(ObjectType)object;

@end

@interface NSMutableSet<__covariant ObjectType> (NSExtendedMutableSet)

- (void)addObjectsFromArray:(NSArray<ObjectType> *)array;
- (void)intersectSet:(NSSet<ObjectType> *)other;
- (void)minusSet:(NSSet<ObjectType> *)other;
- (void)removeAllObjects;
- (void)unionSet:(NSSet<ObjectType> *)other;

- (void)setSet:(NSSet<ObjectType> *)other;

@end

@interface NSMutableSet (NSMutableSetCreation)

+ (id)setWithCapacity:(NSUInteger)numItems;
- (id)initWithCapacity:(NSUInteger)numItems;

@end

typedef struct __CFBag* CFMutableBagRef;
@interface NSCountedSet<__covariant ObjectType> : NSMutableSet
{
    CFMutableBagRef _table;
    void *_reserved;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (instancetype)initWithArray:(NSArray<ObjectType> *)array;
- (instancetype)initWithSet:(NSSet<ObjectType> *)set;
- (NSUInteger)countForObject:(ObjectType)object;
- (NSEnumerator<ObjectType> *)objectEnumerator;
- (void)addObject:(ObjectType)object;
- (void)removeObject:(ObjectType)object;

@end
