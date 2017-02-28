#import <Foundation/NSArray.h>
#import "NSKeyValueAccessor.h"
#import "NSKeyValueObservingInternal.h"
#import <Foundation/NSObject.h>
#import <Foundation/NSOrderedSet.h>
#import <Foundation/NSSet.h>

@class NSEnumerator;
@class NSHashTable;
@class NSIndexSet;

typedef struct {
    id container;
    NSString *key;
} NSKeyValueProxyLocator;

struct NSKeyValueProxyPool;

@class NSKeyValueCollectionGetter;

@protocol NSKeyValueProxyCaching
+ (NSHashTable *)_proxyShare;
+ (struct NSKeyValueProxyPool *)_proxyNonGCPoolPointer;
- (void)_proxyNonGCFinalize;
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueCollectionGetter *)getter;
- (NSKeyValueProxyLocator)_proxyLocator;
@end

#define PROXY_POOLS 4

typedef struct NSKeyValueProxyPool {
    NSUInteger idx;
    id<NSKeyValueProxyCaching> proxy[PROXY_POOLS];
} NSKeyValueProxyPool;

CF_PRIVATE
@interface NSKeyValueNonmutatingCollectionMethodSet : NSObject
@end

CF_PRIVATE
@interface NSKeyValueNonmutatingArrayMethodSet : NSKeyValueNonmutatingCollectionMethodSet
{
@public
    Method count;
    Method objectAtIndex;
    Method getObjectsRange;
    Method objectsAtIndexes;
}
@end

CF_PRIVATE
@interface NSKeyValueNonmutatingOrderedSetMethodSet : NSKeyValueNonmutatingCollectionMethodSet
{
@public
    Method count;
    Method objectAtIndex;
    Method indexOfObject;
    Method getObjectsRange;
    Method objectsAtIndexes;
}
@end

CF_PRIVATE
@interface NSKeyValueNonmutatingSetMethodSet : NSKeyValueNonmutatingCollectionMethodSet
{
@public
    Method count;
    Method enumerator;
    Method member;
}
@end

CF_PRIVATE
@interface NSKeyValueMutatingCollectionMethodSet : NSObject
@end

CF_PRIVATE
@interface NSKeyValueMutatingArrayMethodSet : NSKeyValueMutatingCollectionMethodSet
{
@public
    Method insertObjectAtIndex;
    Method insertObjectsAtIndexes;
    Method removeObjectAtIndex;
    Method removeObjectsAtIndexes;
    Method replaceObjectAtIndex;
    Method replaceObjectsAtIndexes;
}
@end

CF_PRIVATE
@interface NSKeyValueMutatingOrderedSetMethodSet : NSKeyValueMutatingCollectionMethodSet
{
@public
    Method insertObjectAtIndex;
    Method removeObjectAtIndex;
    Method replaceObjectAtIndex;
    Method insertObjectsAtIndexes;
    Method removeObjectsAtIndexes;
    Method replaceObjectsAtIndexes;
}
@end

CF_PRIVATE
@interface NSKeyValueMutatingSetMethodSet : NSKeyValueMutatingCollectionMethodSet
{
@public
    Method addObject;
    Method removeObject;
    Method intersectSet;
    Method minusSet;
    Method unionSet;
    Method setSet;
}
@end

CF_PRIVATE
@interface NSKeyValueNilOrderedSetEnumerator : NSEnumerator
@end

CF_PRIVATE
@interface NSKeyValueNilSetEnumerator : NSEnumerator
@end

CF_PRIVATE
@interface NSKeyValueSlowGetter : NSKeyValueGetter
@end

CF_PRIVATE
@interface NSKeyValueSlowSetter : NSKeyValueSetter
@end

CF_PRIVATE
@interface NSKeyValueProxyGetter : NSKeyValueGetter
{
    Class _proxyClass;
}
@end

CF_PRIVATE
@interface NSKeyValueCollectionGetter : NSKeyValueProxyGetter
{
    NSKeyValueNonmutatingCollectionMethodSet *_methods;
}
- (NSKeyValueNonmutatingCollectionMethodSet *)methods;
@end

CF_PRIVATE
@interface NSKeyValueSlowMutableCollectionGetter : NSKeyValueProxyGetter
{
    NSKeyValueGetter *_baseGetter;
    NSKeyValueSetter *_baseSetter;
}
- (id)initWithContainerClassID:(Class)cls key:(NSString *)key baseGetter:(NSKeyValueGetter *)baseGetter baseSetter:(NSKeyValueSetter *)baseSetter containerIsa:(Class)containerIsa proxyClass:(Class)proxyClass;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableCollection1Getter : NSKeyValueProxyGetter
{
    NSKeyValueNonmutatingCollectionMethodSet *_nonmutatingMethods;
    NSKeyValueMutatingCollectionMethodSet *_mutatingMethods;
}
- (id)initWithContainerClassID:(Class)cls key:(NSString *)key nonmutatingMethods:(NSKeyValueNonmutatingCollectionMethodSet *)nonmutatingMethods mutatingMethods:(NSKeyValueMutatingCollectionMethodSet *)mutatingMethods proxyClass:(Class)proxyClass;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableCollection2Getter : NSKeyValueProxyGetter
{
    NSKeyValueGetter *_baseGetter;
    NSKeyValueMutatingCollectionMethodSet *_mutatingMethods;
}
- (id)initWithContainerClassID:(Class)cls key:(NSString *)key baseGetter:(NSKeyValueGetter *)baseGetter mutatingMethods:(NSKeyValueMutatingCollectionMethodSet *)mutatingMethods proxyClass:(Class)proxyClass;
@end

CF_PRIVATE
@interface NSKeyValueIvarMutableCollectionGetter : NSKeyValueProxyGetter
{
    Ivar _ivar;
}
- (id)initWithContainerClassID:(Class)cls key:(NSString *)key containerIsa:(Class)containerIsa ivar:(Ivar)ivar proxyClass:(Class)proxyClass;
@end

CF_PRIVATE
@interface NSKeyValueNotifyingMutableCollectionGetter : NSKeyValueProxyGetter
{
    NSKeyValueProxyGetter *_mutableCollectionGetter;
}
- (id)initWithContainerClassID:(Class)cls key:(NSString*)key mutableCollectionGetter:(NSKeyValueProxyGetter*)getter proxyClass:(Class)proxyClass;
@end

CF_PRIVATE
@interface NSKeyValueProxyShareKey : NSObject <NSKeyValueProxyCaching>
{
@public
    NSObject *_container;
    NSString *_key;
}
@end

CF_PRIVATE
@interface NSKeyValueArray : NSArray <NSKeyValueProxyCaching>
{
    NSObject *_container;
    NSString *_key;
    NSKeyValueNonmutatingArrayMethodSet *_methods;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueOrderedSet : NSOrderedSet <NSKeyValueProxyCaching>
{
    NSObject *_container;
    NSString *_key;
    NSKeyValueNonmutatingOrderedSetMethodSet *_methods;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueSet : NSSet <NSKeyValueProxyCaching>
{
    NSObject *_container;
    NSString *_key;
    NSKeyValueNonmutatingSetMethodSet *_methods;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueMutableArray : NSMutableArray <NSKeyValueProxyCaching>
{
@public
    NSObject *_container;
    NSString *_key;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueMutableOrderedSet : NSMutableOrderedSet <NSKeyValueProxyCaching>
{
@public
    NSObject *_container;
    NSString *_key;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueMutableSet : NSMutableSet <NSKeyValueProxyCaching>
{
@public
    NSObject *_container;
    NSString *_key;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueSlowMutableArray : NSKeyValueMutableArray
{
    NSKeyValueGetter *_valueGetter;
    NSKeyValueSetter *_valueSetter;
    BOOL _treatNilValuesLikeEmptyArrays;
    char _padding[3];
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueSlowMutableCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueSlowMutableOrderedSet : NSKeyValueMutableOrderedSet
{
    NSKeyValueGetter *_valueGetter;
    NSKeyValueSetter *_valueSetter;
    BOOL _treatNilValuesLikeEmptyOrderedSets;
    char _padding[3];
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueSlowMutableCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueSlowMutableSet : NSKeyValueMutableSet
{
    NSKeyValueGetter *_valueGetter;
    NSKeyValueSetter *_valueSetter;
    BOOL _treatNilValuesLikeEmptySets;
    char _padding[3];
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueSlowMutableCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableArray : NSKeyValueMutableArray
{
    NSKeyValueMutatingArrayMethodSet *_mutatingMethods;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueProxyGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableArray1 : NSKeyValueFastMutableArray
{
    NSKeyValueNonmutatingArrayMethodSet *_nonmutatingMethods;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueFastMutableCollection1Getter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableArray2 : NSKeyValueFastMutableArray
{
    NSKeyValueGetter *_valueGetter;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueFastMutableCollection2Getter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableOrderedSet : NSKeyValueMutableOrderedSet
{
    NSKeyValueMutatingOrderedSetMethodSet *_mutatingMethods;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueProxyGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableOrderedSet1 : NSKeyValueFastMutableOrderedSet
{
    NSKeyValueNonmutatingOrderedSetMethodSet *_nonmutatingMethods;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueFastMutableCollection1Getter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableOrderedSet2 : NSKeyValueFastMutableOrderedSet
{
    NSKeyValueGetter *_valueGetter;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueFastMutableCollection2Getter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableSet : NSKeyValueMutableSet
{
    NSKeyValueMutatingSetMethodSet *_mutatingMethods;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueProxyGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableSet1 : NSKeyValueFastMutableSet
{
    NSKeyValueNonmutatingSetMethodSet *_nonmutatingMethods;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueFastMutableCollection1Getter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueFastMutableSet2 : NSKeyValueFastMutableSet
{
    NSKeyValueGetter *_valueGetter;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueFastMutableCollection2Getter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueIvarMutableArray : NSKeyValueMutableArray
{
    Ivar _ivar;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueIvarMutableCollectionGetter*)getter;
@end

CF_PRIVATE
@interface NSKeyValueIvarMutableOrderedSet : NSKeyValueMutableOrderedSet
{
    Ivar _ivar;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueIvarMutableCollectionGetter*)getter;
@end

CF_PRIVATE
@interface NSKeyValueIvarMutableSet : NSKeyValueMutableSet
{
    Ivar _ivar;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueIvarMutableCollectionGetter*)getter;
@end

CF_PRIVATE
@interface NSKeyValueNotifyingMutableArray : NSKeyValueMutableArray
{
    NSMutableArray *_mutableArray;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueNotifyingMutableCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueNotifyingMutableOrderedSet : NSKeyValueMutableOrderedSet
{
    NSMutableOrderedSet *_mutableOrderedSet;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueNotifyingMutableCollectionGetter *)getter;
@end

CF_PRIVATE
@interface NSKeyValueNotifyingMutableSet : NSKeyValueMutableSet
{
    NSMutableSet *_mutableSet;
}
- (id)_proxyInitWithContainer:(NSObject *)container getter:(NSKeyValueNotifyingMutableCollectionGetter *)getter;
@end
