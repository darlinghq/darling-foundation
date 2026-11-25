#import <Foundation/NSObject.h>

typedef NS_ENUM(NSUInteger, NSURLCacheStoragePolicy) {
    NSURLCacheStorageAllowed,
    NSURLCacheStorageAllowedInMemoryOnly,
    NSURLCacheStorageNotAllowed,
};

@class NSData, NSDictionary, NSURLRequest, NSURLResponse;

// DARLING: CFCachedURLResponseRef is CFNetwork's private type; SDK consumers,
// which may declare it themselves, see the ivar as a plain pointer
#ifdef DARLING
typedef struct _CFCachedURLResponse* CFCachedURLResponseRef;
#endif

@interface NSCachedURLResponse : NSObject <NSCoding, NSCopying>
{
    NSURLResponse* _response;
#ifdef DARLING
    CFCachedURLResponseRef _cachedResponseRef;
#else
    void *_cachedResponseRef; // a CFCachedURLResponseRef
#endif
}

- (id)initWithResponse:(NSURLResponse *)response data:(NSData *)data;
- (id)initWithResponse:(NSURLResponse *)response data:(NSData *)data userInfo:(NSDictionary *)userInfo storagePolicy:(NSURLCacheStoragePolicy)storagePolicy;
- (NSURLResponse *)response;
- (NSData *)data;
- (NSDictionary *)userInfo;
- (NSURLCacheStoragePolicy)storagePolicy;

@end

// DARLING: CFURLCacheRef is CFNetwork's private type; SDK consumers, which may
// declare it themselves, see the ivar as a plain pointer
#ifdef DARLING
typedef struct _CFURLCache* CFURLCacheRef;
#endif

@interface NSURLCache : NSObject
{
#ifdef DARLING
    CFURLCacheRef _cacheRef;
#else
    void *_cacheRef; // a CFURLCacheRef
#endif
}

+ (NSURLCache *)sharedURLCache;
+ (void)setSharedURLCache:(NSURLCache *)cache;
- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity diskPath:(NSString *)path;
- (id)initWithMemoryCapacity:(NSUInteger)memoryCapacity diskCapacity:(NSUInteger)diskCapacity directoryURL:(NSURL *)directoryURL;
- (NSCachedURLResponse *)cachedResponseForRequest:(NSURLRequest *)request;
- (void)storeCachedResponse:(NSCachedURLResponse *)cachedResponse forRequest:(NSURLRequest *)request;
- (void)removeCachedResponseForRequest:(NSURLRequest *)request;
- (void)removeAllCachedResponses;
- (NSUInteger)memoryCapacity;
- (NSUInteger)diskCapacity;
- (void)setMemoryCapacity:(NSUInteger)memoryCapacity;
- (void)setDiskCapacity:(NSUInteger)diskCapacity;
- (NSUInteger)currentMemoryUsage;
- (NSUInteger)currentDiskUsage;

@end
