#import <Foundation/NSObject.h>

@class NSDictionary, NSString, NSURL, NSURLRequest;

#define NSURLResponseUnknownLength ((long long)-1)

@class NSURLResponseInternal;

@interface NSURLResponse : NSObject <NSCoding, NSCopying>
{
    NSURLResponseInternal *_internal;
}

- (id)initWithURL:(NSURL *)URL MIMEType:(NSString *)MIMEType expectedContentLength:(NSInteger)length textEncodingName:(NSString *)name;
- (NSURL *)URL;
- (NSString *)MIMEType;
- (long long)expectedContentLength;
- (NSString *)textEncodingName;
- (NSString *)suggestedFilename;

@end

@class NSHTTPURLResponseInternal;

@interface NSHTTPURLResponse : NSURLResponse
{
    NSHTTPURLResponseInternal *_httpInternal;
}

+ (NSString *)localizedStringForStatusCode:(NSInteger)statusCode;
- (id)initWithURL:(NSURL*)URL statusCode:(NSInteger)statusCode HTTPVersion:(NSString*)HTTPVersion headerFields:(NSDictionary *)headerFields;
- (NSInteger)statusCode;
- (NSDictionary *)allHeaderFields;

@end
