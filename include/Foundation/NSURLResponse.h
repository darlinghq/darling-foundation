#import <Foundation/NSObject.h>

@class NSDictionary, NSString, NSURL, NSURLRequest;

#define NSURLResponseUnknownLength ((long long)-1)

@class NSURLResponseInternal;

NS_ASSUME_NONNULL_BEGIN

@interface NSURLResponse : NSObject <NSSecureCoding, NSCopying>
{
    NSURLResponseInternal *_internal;
}

- (instancetype)initWithURL:(NSURL *)URL MIMEType:(nullable NSString *)MIMEType expectedContentLength:(NSInteger)length textEncodingName:(nullable NSString *)name;
@property (nullable, readonly, copy) NSURL *URL;
@property (nullable, readonly, copy) NSString *MIMEType;
@property (readonly) long long expectedContentLength;
@property (nullable, readonly, copy) NSString *textEncodingName;
@property (nullable, readonly, copy) NSString *suggestedFilename;

@end

@class NSHTTPURLResponseInternal;

@interface NSHTTPURLResponse : NSURLResponse
{
    NSHTTPURLResponseInternal *_httpInternal;
}

+ (NSString *)localizedStringForStatusCode:(NSInteger)statusCode;
- (nullable instancetype)initWithURL:(NSURL *)URL statusCode:(NSInteger)statusCode HTTPVersion:(nullable NSString *)HTTPVersion headerFields:(nullable NSDictionary *)headerFields;
@property (readonly) NSInteger statusCode;
@property (readonly, copy) NSDictionary *allHeaderFields;

@end

NS_ASSUME_NONNULL_END
