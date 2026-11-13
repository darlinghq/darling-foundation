#import <Foundation/NSURLComponents.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSException.h>
#import <CoreFoundation/CFURLComponents.h>

@implementation NSURLComponents

- (instancetype)init
{
    self = [super init];
    if (self) {
        _components = _CFURLComponentsCreate(kCFAllocatorDefault);
        if (!_components) { [self release]; return nil; }
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string
{
    self = [super init];
    if (self) {
        _components = _CFURLComponentsCreateWithString(kCFAllocatorDefault, (CFStringRef)string);
        if (!_components) { [self release]; return nil; }
    }
    return self;
}

+ (instancetype)componentsWithString:(NSString *)string
{
    return [[[self alloc] initWithString:string] autorelease];
}

- (instancetype)initWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve
{
    if (url == nil) {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"*** -[NSURLComponents initWithURL:resolvingAgainstBaseURL:]: nil URL parameter"];
    }
    self = [super init];
    if (self) {
        _components = _CFURLComponentsCreateWithURL(kCFAllocatorDefault, (CFURLRef)url, resolve);
        if (!_components) { [self release]; return nil; }
    }
    return self;
}

+ (instancetype)componentsWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve
{
    return [[[self alloc] initWithURL:url resolvingAgainstBaseURL:resolve] autorelease];
}

- (NSString *)scheme
{
    return [(NSString *)_CFURLComponentsCopyScheme(_components) autorelease];
}

- (void)setScheme:(NSString *)value
{
    if (!_CFURLComponentsSetScheme(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for scheme"];
}

- (NSString *)user
{
    return [(NSString *)_CFURLComponentsCopyUser(_components) autorelease];
}

- (void)setUser:(NSString *)value
{
    if (!_CFURLComponentsSetUser(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for user"];
}

- (NSString *)password
{
    return [(NSString *)_CFURLComponentsCopyPassword(_components) autorelease];
}

- (void)setPassword:(NSString *)value
{
    if (!_CFURLComponentsSetPassword(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for password"];
}

- (NSString *)host
{
    return [(NSString *)_CFURLComponentsCopyHost(_components) autorelease];
}

- (void)setHost:(NSString *)value
{
    if (!_CFURLComponentsSetHost(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for host"];
}

- (NSString *)path
{
    return [(NSString *)_CFURLComponentsCopyPath(_components) autorelease] ?: @"";
}

- (void)setPath:(NSString *)value
{
    if (!_CFURLComponentsSetPath(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for path"];
}

- (NSString *)query
{
    return [(NSString *)_CFURLComponentsCopyQuery(_components) autorelease];
}

- (void)setQuery:(NSString *)value
{
    if (!_CFURLComponentsSetQuery(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for query"];
}

- (NSString *)fragment
{
    return [(NSString *)_CFURLComponentsCopyFragment(_components) autorelease];
}

- (void)setFragment:(NSString *)value
{
    if (!_CFURLComponentsSetFragment(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for fragment"];
}

- (NSString *)percentEncodedUser
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedUser(_components) autorelease];
}

- (void)setPercentEncodedUser:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedUser(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for percentEncodedUser"];
}

- (NSString *)percentEncodedPassword
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedPassword(_components) autorelease];
}

- (void)setPercentEncodedPassword:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedPassword(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for percentEncodedPassword"];
}

- (NSString *)percentEncodedHost
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedHost(_components) autorelease];
}

- (void)setPercentEncodedHost:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedHost(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for percentEncodedHost"];
}

- (NSString *)percentEncodedPath
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedPath(_components) autorelease] ?: @"";
}

- (void)setPercentEncodedPath:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedPath(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for percentEncodedPath"];
}

- (NSString *)percentEncodedQuery
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedQuery(_components) autorelease];
}

- (void)setPercentEncodedQuery:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedQuery(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for percentEncodedQuery"];
}

- (NSString *)percentEncodedFragment
{
    return [(NSString *)_CFURLComponentsCopyPercentEncodedFragment(_components) autorelease];
}

- (void)setPercentEncodedFragment:(NSString *)value
{
    if (!_CFURLComponentsSetPercentEncodedFragment(_components, (CFStringRef)value))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL component for percentEncodedFragment"];
}

- (NSNumber *)port
{
    return [(NSNumber *)_CFURLComponentsCopyPort(_components) autorelease];
}

- (void)setPort:(NSNumber *)port
{
    if (!_CFURLComponentsSetPort(_components, (CFNumberRef)port))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL port"];
}

- (NSURL *)URL
{
    return [(NSURL *)_CFURLComponentsCopyURL(_components) autorelease];
}

- (NSURL *)URLRelativeToURL:(NSURL *)baseURL
{
    return [(NSURL *)_CFURLComponentsCopyURLRelativeToURL(_components, (CFURLRef)baseURL) autorelease];
}

- (NSString *)string
{
    return [(NSString *)_CFURLComponentsCopyString(_components) autorelease];
}

// A component that is not part of the string has no range, reported as NSNotFound.
static NSRange rangeFromCF(CFRange range)
{
    if (range.location == kCFNotFound)
        return NSMakeRange(NSNotFound, 0);
    return NSMakeRange((NSUInteger)range.location, (NSUInteger)range.length);
}

- (NSRange)rangeOfScheme
{
    return rangeFromCF(_CFURLComponentsGetRangeOfScheme(_components));
}

- (NSRange)rangeOfUser
{
    return rangeFromCF(_CFURLComponentsGetRangeOfUser(_components));
}

- (NSRange)rangeOfPassword
{
    return rangeFromCF(_CFURLComponentsGetRangeOfPassword(_components));
}

- (NSRange)rangeOfHost
{
    return rangeFromCF(_CFURLComponentsGetRangeOfHost(_components));
}

- (NSRange)rangeOfPort
{
    return rangeFromCF(_CFURLComponentsGetRangeOfPort(_components));
}

- (NSRange)rangeOfPath
{
    return rangeFromCF(_CFURLComponentsGetRangeOfPath(_components));
}

- (NSRange)rangeOfQuery
{
    return rangeFromCF(_CFURLComponentsGetRangeOfQuery(_components));
}

- (NSRange)rangeOfFragment
{
    return rangeFromCF(_CFURLComponentsGetRangeOfFragment(_components));
}

- (NSArray *)queryItems
{
    NSArray *pairs = [(NSArray *)_CFURLComponentsCopyQueryItems(_components) autorelease];
    if (!pairs) return nil;
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[pairs count]];
    for (NSDictionary *pair in pairs) {
        [items addObject:[[[NSURLQueryItem alloc]
            initWithName:[pair objectForKey:(NSString *)_kCFURLComponentsNameKey]
            value:[pair objectForKey:(NSString *)_kCFURLComponentsValueKey]] autorelease]];
    }
    return [[items copy] autorelease];
}

- (void)setQueryItems:(NSArray *)items
{
    if (!items) {
        _CFURLComponentsSetPercentEncodedQuery(_components, NULL);
        return;
    }
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:[items count]];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:[items count]];
    for (NSURLQueryItem *item in items) {
        [names addObject:[item name]];
        [values addObject:[item value] ?: [NSNull null]];
    }
    _CFURLComponentsSetQueryItems(_components, (CFArrayRef)names, (CFArrayRef)values);
}

- (NSArray *)percentEncodedQueryItems
{
    NSArray *pairs = [(NSArray *)_CFURLComponentsCopyPercentEncodedQueryItems(_components) autorelease];
    if (!pairs) return nil;
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:[pairs count]];
    for (NSDictionary *pair in pairs) {
        [items addObject:[[[NSURLQueryItem alloc]
            initWithName:[pair objectForKey:(NSString *)_kCFURLComponentsNameKey]
            value:[pair objectForKey:(NSString *)_kCFURLComponentsValueKey]] autorelease]];
    }
    return [[items copy] autorelease];
}

- (void)setPercentEncodedQueryItems:(NSArray *)items
{
    if (!items) {
        _CFURLComponentsSetPercentEncodedQuery(_components, NULL);
        return;
    }
    NSMutableArray *names = [NSMutableArray arrayWithCapacity:[items count]];
    NSMutableArray *values = [NSMutableArray arrayWithCapacity:[items count]];
    for (NSURLQueryItem *item in items) {
        [names addObject:[item name]];
        [values addObject:[item value] ?: [NSNull null]];
    }
    if (!_CFURLComponentsSetPercentEncodedQueryItems(_components, (CFArrayRef)names, (CFArrayRef)values))
        [NSException raise:NSInvalidArgumentException format:@"invalid percent-encoded query item"];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSURLComponents *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        if (copy->_components) CFRelease(copy->_components);
        copy->_components = _CFURLComponentsCreateCopy(kCFAllocatorDefault, _components);
    }
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (self == other) return YES;
    if (![other isKindOfClass:[NSURLComponents class]]) return NO;
    NSString *a = [self string], *b = [other string];
    return a == b || [a isEqual:b];
}

- (NSUInteger)hash
{
    return [[self string] hash];
}

- (void)dealloc
{
    if (_components) CFRelease(_components);
    [super dealloc];
}

@end
