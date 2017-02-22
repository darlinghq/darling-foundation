#import <Foundation/NSObject.h>
#import <Foundation/NSSet.h>

@class NSString, NSCache;

@protocol NSCacheDelegate <NSObject>
@optional
- (void)cache:(NSCache *)cache willEvictObject:(id)obj;
@end

@interface NSCache : NSObject {
    CFMutableDictionaryRef _objects;
    NSMutableSet *_discardableObjects;
    NSString *_cacheName;
    NSInteger _countLimit;
    NSInteger _costLimit;
    NSInteger _currentCost;
    BOOL _evictsContent;
    OSSpinLock _accessLock;
    id _delegate;
    
    struct {
        unsigned willEvictObject : 1;
    } _delegateHas;
}

- (void)setName:(NSString *)n;
- (NSString *)name;
- (void)setDelegate:(id <NSCacheDelegate>)delegate;
- (id <NSCacheDelegate>)delegate;
- (id)objectForKey:(id)key;
- (void)setObject:(id)obj forKey:(id)key;
- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)cost;
- (void)removeObjectForKey:(id)key;
- (void)removeAllObjects;
- (void)setTotalCostLimit:(NSUInteger)limit;
- (NSUInteger)totalCostLimit;
- (void)setCountLimit:(NSUInteger)limit;
- (NSUInteger)countLimit;
- (BOOL)evictsObjectsWithDiscardedContent;
- (void)setEvictsObjectsWithDiscardedContent:(BOOL)evicts;

@end
