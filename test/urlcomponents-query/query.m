#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSException.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSObjCRuntime.h>
#include <dlfcn.h>
#include <stdio.h>

@interface NSObject (QueryRegression)
+ (id)componentsWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve;
- (NSArray *)queryItems;
- (void)setQueryItems:(NSArray *)items;
- (NSURL *)URL;
- (NSString *)scheme;
- (NSString *)host;
+ (id)componentsWithString:(NSString *)string;
- (NSString *)name;
- (NSString *)value;
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc == 2 && !dlopen(argv[1], RTLD_NOW)) {
            fprintf(stderr, "FAIL load candidate: %s\n", dlerror());
            return 2;
        }
        Class componentsClass = NSClassFromString(argc == 2 ? @"DARTestURLComponents" : @"NSURLComponents");
        @try {
            NSURL *url = [NSURL URLWithString:@"https://example.invalid/path?name=a%20b&flag&empty=&name=second"];
            id components = [componentsClass componentsWithURL:url resolvingAgainstBaseURL:NO];
            NSArray *items = [components queryItems];
            if ([items count] != 4 || ![[[items objectAtIndex:0] name] isEqual:@"name"] ||
                ![[[items objectAtIndex:0] value] isEqual:@"a b"] ||
                ![[[items objectAtIndex:1] name] isEqual:@"flag"] || [[items objectAtIndex:1] value] != nil ||
                ![[[items objectAtIndex:2] name] isEqual:@"empty"] ||
                ![[[items objectAtIndex:2] value] isEqual:@""] ||
                ![[[items objectAtIndex:3] name] isEqual:@"name"] ||
                ![[[items objectAtIndex:3] value] isEqual:@"second"]) {
                fprintf(stderr, "FAIL ordered decoded query items and nil/empty values\n");
                return 1;
            }
            id absent = [componentsClass componentsWithURL:[NSURL URLWithString:@"https://example.invalid/path"] resolvingAgainstBaseURL:NO];
            id empty = [componentsClass componentsWithURL:[NSURL URLWithString:@"https://example.invalid/path?"] resolvingAgainstBaseURL:NO];
            if ([absent queryItems] != nil || [empty queryItems] == nil || [[empty queryItems] count] != 0) {
                fprintf(stderr, "FAIL absent versus empty query\n");
                return 1;
            }
            [components setQueryItems:items];
            if (![[[components URL] absoluteString] isEqual:@"https://example.invalid/path?name=a%20b&flag&empty=&name=second"] ||
                ![[components scheme] isEqual:@"https"] || ![[components host] isEqual:@"example.invalid"]) {
                fprintf(stderr, "FAIL query setter round trip or component getters\n");
                return 1;
            }
            [components setQueryItems:[NSArray array]];
            if ([components queryItems] == nil || [[components queryItems] count] != 0) return 1;
            [components setQueryItems:nil];
            if ([components queryItems] != nil) return 1;
            id stringComponents = [componentsClass componentsWithString:@"https://example.invalid/path?flag"];
            if ([[stringComponents queryItems] count] != 1 || [[[stringComponents queryItems] objectAtIndex:0] value] != nil) return 1;
            NSURL *relative = [NSURL URLWithString:@"child?flag" relativeToURL:[NSURL URLWithString:@"https://example.invalid/base/"]];
            id unresolved = [componentsClass componentsWithURL:relative resolvingAgainstBaseURL:NO];
            id resolved = [componentsClass componentsWithURL:relative resolvingAgainstBaseURL:YES];
            if ([unresolved host] != nil || ![[resolved host] isEqual:@"example.invalid"] ||
                ![[[resolved URL] absoluteString] isEqual:@"https://example.invalid/base/child?flag"]) return 1;
            puts("PASS ordered decoded query items; nil/empty values and queries; setter round trip; relative URL resolution");
        } @catch (NSException *exception) {
            fprintf(stderr, "FAIL exception: %s: %s\n", [[exception name] UTF8String], [[exception reason] UTF8String]);
            return 1;
        }
    }
    return 0;
}
