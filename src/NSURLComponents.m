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
    return [self initWithString:resolve ? [url absoluteString] : [url relativeString]];
}

+ (instancetype)componentsWithURL:(NSURL *)url resolvingAgainstBaseURL:(BOOL)resolve
{
    return [[[self alloc] initWithURL:url resolvingAgainstBaseURL:resolve] autorelease];
}

- (NSString *)scheme
{
    return [(NSString *)_CFURLComponentsCopyScheme(_components) autorelease];
}

- (void)setScheme:(NSString *)scheme
{
    if (!_CFURLComponentsSetScheme(_components, (CFStringRef)scheme))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL scheme"];
}

- (NSString *)host
{
    return [(NSString *)_CFURLComponentsCopyHost(_components) autorelease];
}

- (void)setHost:(NSString *)host
{
    if (!_CFURLComponentsSetHost(_components, (CFStringRef)host))
        [NSException raise:NSInvalidArgumentException format:@"invalid URL host"];
}

- (NSURL *)URL
{
    return [(NSURL *)_CFURLComponentsCopyURL(_components) autorelease];
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

- (void)dealloc
{
    if (_components) CFRelease(_components);
    [super dealloc];
}

@end
