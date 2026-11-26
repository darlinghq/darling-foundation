#import <Foundation/NSObject.h>

@class NSArray, NSDate, NSHTTPCookie, NSURL, NSURLSessionTask;

typedef NS_ENUM(NSUInteger, NSHTTPCookieAcceptPolicy) {
    NSHTTPCookieAcceptPolicyAlways,
    NSHTTPCookieAcceptPolicyNever,
    NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain
};

FOUNDATION_EXPORT NSString * const NSHTTPCookieManagerAcceptPolicyChangedNotification;
FOUNDATION_EXPORT NSString * const NSHTTPCookieManagerCookiesChangedNotification;

@class NSHTTPCookieStorageInternal;

// The one ivar of Apple's public header: the storage's state lives in an
// object of CFNetwork's private class.
@interface NSHTTPCookieStorage : NSObject
{
@private
    NSHTTPCookieStorageInternal *_internal;
}

+ (NSHTTPCookieStorage *)sharedHTTPCookieStorage;

- (NSArray *)cookies;
- (void)setCookie:(NSHTTPCookie *)cookie;
- (void)deleteCookie:(NSHTTPCookie *)cookie;
- (NSArray *)cookiesForURL:(NSURL *)URL;
- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)URL mainDocumentURL:(NSURL *)mainDocumentURL;
- (NSHTTPCookieAcceptPolicy)cookieAcceptPolicy;
- (void)setCookieAcceptPolicy:(NSHTTPCookieAcceptPolicy)cookieAcceptPolicy;
- (void)removeCookiesSinceDate:(NSDate *)date;
- (NSArray*)sortedCookiesUsingDescriptors:(NSArray*) sortOrder;

@end

// The cookies of a task's requests and responses; NSURLSession goes through
// these, so a subclass can see and change them.
@interface NSHTTPCookieStorage (NSURLSessionTaskAdditions)
- (void)storeCookies:(NSArray *)cookies forTask:(NSURLSessionTask *)task;
- (void)getCookiesForTask:(NSURLSessionTask *)task completionHandler:(void (^)(NSArray *cookies))completionHandler;
@end
