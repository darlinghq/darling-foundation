#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

@interface NSURLComponents : NSObject

- (instancetype)initWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve;
+ (instancetype)componentsWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve;

@property(copy) NSString *scheme;
@property(copy) NSString *host;
@property(nullable, readonly, copy) NSURL *URL;

@end
