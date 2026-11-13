#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <Foundation/NSArray.h>

@class NSNumber;

@interface NSURLComponents : NSObject <NSCopying> {
    void *_components;
}

- (instancetype)init;
- (instancetype)initWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve;
+ (instancetype)componentsWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve;
- (instancetype)initWithString:(NSString *)string;
+ (instancetype)componentsWithString:(NSString *)string;

@property(nullable, readonly, copy) NSURL *URL;
- (NSURL *)URLRelativeToURL:(NSURL *)baseURL;
@property(nullable, readonly, copy) NSString *string;

@property(nullable, copy) NSString *scheme;
@property(nullable, copy) NSString *user;
@property(nullable, copy) NSString *password;
@property(nullable, copy) NSString *host;
@property(nullable, copy) NSNumber *port;
@property(nullable, copy) NSString *path;
@property(nullable, copy) NSString *query;
@property(nullable, copy) NSString *fragment;

@property(nullable, copy) NSString *percentEncodedUser;
@property(nullable, copy) NSString *percentEncodedPassword;
@property(nullable, copy) NSString *percentEncodedHost;
@property(nullable, copy) NSString *percentEncodedPath;
@property(nullable, copy) NSString *percentEncodedQuery;
@property(nullable, copy) NSString *percentEncodedFragment;

@property(readonly) NSRange rangeOfScheme;
@property(readonly) NSRange rangeOfUser;
@property(readonly) NSRange rangeOfPassword;
@property(readonly) NSRange rangeOfHost;
@property(readonly) NSRange rangeOfPort;
@property(readonly) NSRange rangeOfPath;
@property(readonly) NSRange rangeOfQuery;
@property(readonly) NSRange rangeOfFragment;

@property(nullable, copy) NSArray<NSURLQueryItem *> *queryItems;
@property(nullable, copy) NSArray<NSURLQueryItem *> *percentEncodedQueryItems;

@end
