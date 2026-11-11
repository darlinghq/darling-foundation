#import <Foundation/NSObject.h>

@class NSArray, NSDate, NSHTTPCookie, NSURL;

typedef NS_ENUM(NSUInteger, NSHTTPCookieAcceptPolicy) {
    NSHTTPCookieAcceptPolicyAlways,
    NSHTTPCookieAcceptPolicyNever,
    NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain
};

FOUNDATION_EXPORT NSString * const NSHTTPCookieManagerAcceptPolicyChangedNotification;
FOUNDATION_EXPORT NSString * const NSHTTPCookieManagerCookiesChangedNotification;

typedef struct __CFHTTPCookieStorage *CFHTTPCookieStorageRef;

@interface NSHTTPCookieStorage : NSObject
{
    CFHTTPCookieStorageRef _storage;
    NSHTTPCookieAcceptPolicy _acceptPolicy;
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
