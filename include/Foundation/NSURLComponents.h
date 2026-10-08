#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#import <Foundation/NSArray.h>

@interface NSURLComponents : NSObject {
    void *_components;
}

- (instancetype)initWithString:(NSString *)string;
+ (instancetype)componentsWithString:(NSString *)string;

- (instancetype)initWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve;
+ (instancetype)componentsWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve;

@property(nullable, copy) NSArray<NSURLQueryItem *> *queryItems;

@property(copy) NSString *scheme;
@property(copy) NSString *host;
@property(nullable, readonly, copy) NSURL *URL;

@end
