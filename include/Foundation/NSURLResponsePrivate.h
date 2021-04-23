#import <Foundation/NSURLResponse.h>

@interface NSHTTPURLResponse (Internal)

+ (BOOL)isErrorStatusCode:(NSInteger)statusCode;

@end
