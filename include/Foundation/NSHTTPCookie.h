#import <Foundation/NSObject.h>

@class NSArray, NSDate, NSDictionary, NSString, NSURL;

FOUNDATION_EXPORT NSString * const NSHTTPCookieName;
FOUNDATION_EXPORT NSString * const NSHTTPCookieValue;
FOUNDATION_EXPORT NSString * const NSHTTPCookieOriginURL;
FOUNDATION_EXPORT NSString * const NSHTTPCookieVersion;
FOUNDATION_EXPORT NSString * const NSHTTPCookieDomain;
FOUNDATION_EXPORT NSString * const NSHTTPCookiePath;
FOUNDATION_EXPORT NSString * const NSHTTPCookieSecure;
FOUNDATION_EXPORT NSString * const NSHTTPCookieExpires;
FOUNDATION_EXPORT NSString * const NSHTTPCookieComment;
FOUNDATION_EXPORT NSString * const NSHTTPCookieCommentURL;
FOUNDATION_EXPORT NSString * const NSHTTPCookieDiscard;
FOUNDATION_EXPORT NSString * const NSHTTPCookieMaximumAge;
FOUNDATION_EXPORT NSString * const NSHTTPCookiePort;

typedef NSString * NSHTTPCookiePropertyKey NS_TYPED_EXTENSIBLE_ENUM;
// the values of a cookie's SameSite policy (macOS 10.15)
typedef NSString * NSHTTPCookieStringPolicy NS_TYPED_ENUM;

// Value: NSHTTPCookieSameSiteLax or NSHTTPCookieSameSiteStrict; a cookie
// without it has no SameSite policy.
FOUNDATION_EXPORT NSHTTPCookiePropertyKey const NSHTTPCookieSameSitePolicy;
FOUNDATION_EXPORT NSHTTPCookieStringPolicy const NSHTTPCookieSameSiteLax;
FOUNDATION_EXPORT NSHTTPCookieStringPolicy const NSHTTPCookieSameSiteStrict;

// DARLING: CFHTTPCookieRef is CFNetwork's private type; SDK consumers, which may
// declare it themselves, see the ivar as a plain pointer
#ifdef DARLING
typedef struct __CFHTTPCookie *CFHTTPCookieRef;
#endif

@interface NSHTTPCookie : NSObject
{
#ifdef DARLING
    CFHTTPCookieRef  _cookiePrivate;
#else
    void *_cookiePrivate; // a CFHTTPCookieRef
#endif
}

+ (id)cookieWithProperties:(NSDictionary *)properties;
+ (NSDictionary *)requestHeaderFieldsWithCookies:(NSArray *)cookies;
+ (NSArray *)cookiesWithResponseHeaderFields:(NSDictionary *)headerFields forURL:(NSURL *)URL;
- (id)initWithProperties:(NSDictionary *)properties;
@property (readonly, copy) NSDictionary *properties;
@property (readonly) NSUInteger version;
@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *value;
@property (readonly, copy) NSDate *expiresDate;
@property (readonly, getter=isSessionOnly) BOOL sessionOnly;
@property (readonly, copy) NSString *domain;
@property (readonly, copy) NSString *path;
@property (readonly, getter=isSecure) BOOL secure;
@property (readonly, getter=isHTTPOnly) BOOL HTTPOnly;
@property (readonly, copy) NSString *comment;
@property (readonly, copy) NSURL *commentURL;
@property (readonly, copy) NSArray *portList;
// NSHTTPCookieSameSiteLax, NSHTTPCookieSameSiteStrict or nil (macOS 10.15)
@property (readonly, copy) NSHTTPCookieStringPolicy sameSitePolicy;

@end
