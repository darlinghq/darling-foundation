//
//  NSBundle.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <dispatch/dispatch.h>
#import <CoreFoundation/CFBundle.h>
#import <CoreFoundation/CFBundlePriv.h>
#import <objc/runtime.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>

NSString *const NSBundleDidLoadNotification = @"NSBundleDidLoadNotification";
NSString *const NSLoadedClasses = @"NSLoadedClasses";

static NSMutableDictionary *bundlesByIdentifier = nil;
static NSBundle *mainBundle = nil;
static NSMutableDictionary *classToBundle = nil;
static NSMutableDictionary<NSString *, NSBundle *> *bundlesByPath = nil;
static NSMutableDictionary<NSString *, NSBundle *> *frameworkBundlesByPath = nil;

__attribute__((visibility("hidden")))
NSString * _NSFrameworkPathFromLibraryPath(NSString *path)
{
	path = [path stringByResolvingSymlinksInPath];
	path = [path stringByDeletingLastPathComponent];
	NSString *extension = [path pathExtension];
	if ([extension compare:@"framework"] != NSOrderedSame)
	{
		path = [path stringByDeletingLastPathComponent];
		NSString *last = [path lastPathComponent];
		if ([last compare:@"Versions"] != NSOrderedSame)
		{
			return nil;
		}
		path = [path stringByDeletingLastPathComponent];
		NSString *extension = [path pathExtension];
		if ([extension compare:@"framework"] != NSOrderedSame)
		{
			return nil;
		}
		return path;
	}
	else
	{
		return path;
	}
}

__attribute__((visibility("hidden")))
NSString * _NSBundlePathFromExecutablePath(NSString *path)
{
	// Follow symlinks
	path = [path stringByResolvingSymlinksInPath];

	// Go up two levels
	NSString *oneGone = [path stringByDeletingLastPathComponent];
	path = [oneGone stringByDeletingLastPathComponent];

	NSString *last = [path lastPathComponent];

	while ([last compare:@"Contents"] != NSOrderedSame)
	{
		if ([path compare:@"Executables"] == NSOrderedSame)
		{
			return oneGone;
		}
		path = [path stringByDeletingLastPathComponent];
		last = [path lastPathComponent];
		if ([last compare:@"Support Files"] != NSOrderedSame)
		{
			return oneGone;
		}
	}
	return [path stringByDeletingLastPathComponent];
}

static NSString* frameworkPathForPath(NSString *filePath) {
    NSString *frameworkPath = _NSFrameworkPathFromLibraryPath(filePath);
    if (frameworkPath) {
        filePath = frameworkPath;
    } else {
        filePath = _NSBundlePathFromExecutablePath(filePath);
    }
    return filePath;
};

@implementation NSBundle

+ (void)initialize
{
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        bundlesByIdentifier = [[NSMutableDictionary alloc] init];
        classToBundle = [[NSMutableDictionary alloc] init];
        bundlesByPath = [NSMutableDictionary dictionary];
        frameworkBundlesByPath = [NSMutableDictionary dictionary];
    });
}

+ (NSBundle *)mainBundle
{
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        CFBundleRef cfBundle = CFBundleGetMainBundle();
        if (cfBundle != NULL) {
            mainBundle = [[NSBundle alloc] init];
            mainBundle->_cfBundle = (CFBundleRef) CFRetain(cfBundle);
            [mainBundle load];
        }
    });

    return mainBundle;
}

- (BOOL)_isRegistered
{
    @synchronized(self) {
        return (_flags & NSBundleIsRegisteredFlag) != 0;
    }
}

- (void)_setIsRegistered: (BOOL)isRegistered
{
    @synchronized(self) {
        if (isRegistered) {
            _flags |= NSBundleIsRegisteredFlag;
        } else {
            _flags &= ~NSBundleIsRegisteredFlag;
        }
    }
}

- (void)_addToGlobalTables
{
    NSString* bundleIdentifier = [self bundleIdentifier];
    NSString* bundlePath = [self bundlePath];

    if (bundleIdentifier != nil) {
        @synchronized(bundlesByIdentifier) {
            bundlesByIdentifier[bundleIdentifier] = self;
        }
    }

    if (bundlePath != nil) {
        @synchronized(bundlesByPath) {
            bundlesByPath[bundlePath] = self;
        }

        if (self != [NSBundle mainBundle] && frameworkPathForPath([self executablePath]) != nil) {
            @synchronized(frameworkBundlesByPath) {
                frameworkBundlesByPath[bundlePath] = self;
            }
        }
    }

    [self _setIsRegistered: YES];
}

- (void)_removeFromGlobalTables
{
    if (![self _isRegistered]) {
        return;
    }

    NSString* bundleIdentifier = [self bundleIdentifier];
    NSString* bundlePath = [self bundlePath];

    if (bundleIdentifier != nil) {
        @synchronized(bundlesByIdentifier) {
            [bundlesByIdentifier removeObjectForKey: bundleIdentifier];
        }
    }

    if (bundlePath != nil) {
        @synchronized(bundlesByPath) {
            [bundlesByPath removeObjectForKey: bundlePath];
        }
        @synchronized(frameworkBundlesByPath) {
            [frameworkBundlesByPath removeObjectForKey: bundlePath];
        }
    }
}

+ (NSBundle *)bundleWithPath:(NSString *)path
{
    return [[[self alloc] initWithPath:path] autorelease];
}

+ (NSBundle *)bundleWithURL:(NSURL *)url
{
    return [[[self alloc] initWithURL:url] autorelease];
}

+ (NSBundle *)bundleForClass:(Class)aClass
{
    if ([aClass respondsToSelector: @selector(bundleForClass)]) {
        return [aClass bundleForClass];
    }

    @synchronized (classToBundle) {
        NSBundle *bundle = classToBundle[aClass];
        if (bundle != nil) {
            return bundle;
        }
    }

    const char *fileName = class_getImageName(aClass);
    if (fileName == NULL) {
        // According to Cocotron's implementation,
        // this is correct behaviour for Nil class.
        return [self mainBundle];
    }

    NSString *filePath = [NSString stringWithUTF8String: fileName];
    
    NSString *frameworkPath = _NSFrameworkPathFromLibraryPath(filePath);
    if (frameworkPath)
    {
	filePath = frameworkPath;
    }
    else
    {
	NSString *executablePath = _NSBundlePathFromExecutablePath(filePath);
	if (!executablePath) return nil;
	filePath = executablePath;
    }

    NSBundle *bundle = [self bundleWithPath:filePath];

    @synchronized (classToBundle) {
        classToBundle[aClass] = bundle;
    }

    return bundle;
}

+ (NSBundle *)bundleWithIdentifier:(NSString *)identifier
{
    NSBundle *bundle = nil;
    @synchronized(bundlesByIdentifier)
    {
        bundle = [bundlesByIdentifier[identifier] retain];
        // TODO: we should be doing some searching if the bundle is nil
    }
    return [bundle autorelease];
}

+ (NSArray *)allBundles
{
    NSArray *allBundles = nil;
    @synchronized(bundlesByIdentifier)
    {
        allBundles = [[bundlesByIdentifier allValues] copy];
    }
    return [allBundles autorelease];
}

+ (NSArray *)allFrameworks
{
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        unsigned int imageCount = 0;
        const char **imageNames = objc_copyImageNames(&imageCount);
        if (imageNames != nil) {
            for (unsigned int i = 0; i < imageCount; ++i) {
                @autoreleasepool {
                    NSString *path = [[NSFileManager defaultManager] stringWithFileSystemRepresentation: imageNames[i] length: strlen(imageNames[i])];
                    NSString *frameworkPath = frameworkPathForPath(path);
                    if (frameworkPath != nil) {
                        [NSBundle bundleWithPath: frameworkPath];
                        // the bundle will automatically register itself to the framework table if it refers to one
                    }
                }
            }
            free(imageNames);
        }
    });

    NSArray *allFrameworks = nil;
    @synchronized(allFrameworks) {
        allFrameworks = [[frameworkBundlesByPath allValues] copy];
    }

    return [allFrameworks autorelease];
}

- (id)initWithPath:(NSString *)path
{
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path isDirectory:YES];
    self = [self initWithURL:url];
    [url release];
    return self;
}

- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self)
    {
        _cfBundle = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)url);
        if (!_cfBundle)
        {
            [self release];
            return nil;
        }

        // only add it to the global table after we've initialized `_cfBundle`
        NSBundle *existingOne = nil;
        @synchronized(bundlesByPath) {
            existingOne = bundlesByPath[[url path]];
            if (existingOne == nil) {
                [self _addToGlobalTables];
            }
        }
        if (existingOne != nil) {
            [self release];
            return [existingOne retain];
        }
    }
    return self;
}

static void __NSBundleMainBundleDealloc()
{
    RELEASE_LOG("Attempt to dealloc [NSBundle mainBundle], ignored.");
}

- (void)dealloc
{
    if (self == mainBundle) {
        __NSBundleMainBundleDealloc();
        return;
    }

    [self _removeFromGlobalTables];
    if (_cfBundle)
    {
        CFRelease(_cfBundle);
    }
    [super dealloc];
}

- (CFBundleRef)_cfBundle
{
    return _cfBundle;
}

- (NSString *) description {
    return  [[super description] stringByAppendingFormat: @" <%@>%@", [self bundlePath], [self isLoaded] ? @" (loaded)":@""];
}

- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)ext
{
    return [self URLForResource:name withExtension:ext subdirectory:nil];
}

- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)ext subdirectory:(NSString *)subpath
{
    return [(NSURL *)CFBundleCopyResourceURL(_cfBundle, (CFStringRef)name, (CFStringRef)ext, (CFStringRef)subpath) autorelease];
}

- (NSURL *)URLForResource:(NSString *)name withExtension:(NSString *)ext subdirectory:(NSString *)subpath localization:(NSString *)localizationName
{
    return [(NSURL *)CFBundleCopyResourceURLForLocalization(_cfBundle, (CFStringRef)name, (CFStringRef)ext, (CFStringRef)subpath, (CFStringRef)localizationName) autorelease];
}

- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext
{
    return [[self URLForResource:name withExtension:ext subdirectory:nil] path];
}

- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext inDirectory:(NSString *)subpath
{
    return [[self URLForResource:name withExtension:ext subdirectory:subpath] path];
}

- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)ext inDirectory:(NSString *)subpath forLocalization:(NSString *)localizationName
{
    return [[self URLForResource:name withExtension:ext subdirectory:subpath localization:localizationName] path];
}

- (NSDictionary *)infoDictionary
{
    return (NSDictionary *)CFBundleGetInfoDictionary(_cfBundle);
}

- (NSDictionary *)localizedInfoDictionary
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        return (NSDictionary *)CFBundleGetLocalInfoDictionary(bundle);
    }
    else
    {
        return nil;
    }
}

- (NSArray *)URLsForResourcesWithExtension:(NSString *)ext subdirectory:(NSString *)subpath
{
    return [self URLsForResourcesWithExtension:ext subdirectory:subpath localization:nil];
}

- (NSArray *)URLsForResourcesWithExtension:(NSString *)ext subdirectory:(NSString *)subpath localization:(NSString *)localizationName
{
    return [(NSArray *)CFBundleCopyResourceURLsOfTypeForLocalization(_cfBundle, (CFStringRef)ext, (CFStringRef)subpath, (CFStringRef)localizationName) autorelease];
}

- (NSArray *)pathsForResourcesOfType:(NSString *)ext inDirectory:(NSString *)subpath
{
    return [self pathsForResourcesOfType:ext inDirectory:subpath forLocalization:nil];
}

- (NSArray *)pathsForResourcesOfType:(NSString *)ext inDirectory:(NSString *)subpath forLocalization:(NSString *)localizationName
{
    NSMutableArray *paths = [[NSMutableArray alloc] init];
    NSArray *urls = [self URLsForResourcesWithExtension:ext subdirectory:subpath localization:localizationName];
    for (NSURL *url in urls)
    {
        [paths addObject:[url path]];
    }
    return [paths autorelease];
}

- (NSString*)bundlePath
{
    NSURL *url = (NSURL *)CFBundleCopyBundleURL(_cfBundle);
    NSString *path = [url path];
    CFRelease(url);
    return path;
}

- (NSURL *)bundleURL
{
    return [(NSURL *)CFBundleCopyBundleURL(_cfBundle) autorelease];
}

- (NSString *)resourcePath
{
    return [[self resourceURL] path];
}

- (NSString *)executablePath
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        CFURLRef url = CFBundleCopyExecutableURL(bundle);
        NSString *path = [(NSURL *)url path];
        if (url != NULL)
        {
            CFRelease(url);
        }
        return path;
    }
    else
    {
        return nil;
    }
}

- (NSString *)pathForAuxiliaryExecutable:(NSString *)executableName
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        CFURLRef url = CFBundleCopyAuxiliaryExecutableURL(bundle, (CFStringRef)executableName);
        NSString *path = [(NSURL *)url path];
        if (url != NULL)
        {
            CFRelease(url);
        }
        return path;
    }
    else
    {
        return nil;
    }
}

- (NSString *)privateFrameworksPath
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        CFURLRef url = CFBundleCopyPrivateFrameworksURL(bundle);
        NSString *path = [(NSURL *)url path];
        if (url != NULL)
        {
            CFRelease(url);
        }
        return path;
    }
    else
    {
        return nil;
    }
}

- (NSString *)sharedFrameworksPath
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        CFURLRef url = CFBundleCopySharedFrameworksURL(bundle);
        NSString *path = [(NSURL *)url path];
        if (url != NULL)
        {
            CFRelease(url);
        }
        return path;
    }
    else
    {
        return nil;
    }
}

- (NSString *)sharedSupportPath
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        CFURLRef url = CFBundleCopySharedSupportURL(bundle);
        NSString *path = [(NSURL *)url path];
        if (url != NULL)
        {
            CFRelease(url);
        }
        return path;
    }
    else
    {
        return nil;
    }
}

- (NSString *)builtInPlugInsPath
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        CFURLRef url = CFBundleCopyBuiltInPlugInsURL(bundle);
        NSString *path = [(NSURL *)url path];
        if (url != NULL)
        {
            CFRelease(url);
        }
        return path;
    }
    else
    {
        return nil;
    }
}

- (NSURL *)resourceURL
{
    return [(NSURL *)CFBundleCopyResourcesDirectoryURL(_cfBundle) autorelease];
}

- (NSURL *)executableURL
{
    return [[self bundleURL] URLByAppendingPathComponent:[[self infoDictionary] objectForKey:@"CFBundleExecutable"]];
}

- (NSURL *)URLForAuxiliaryExecutable:(NSString *)executableName
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        return [(NSURL *)CFBundleCopyAuxiliaryExecutableURL(bundle, (CFStringRef)executableName) autorelease];
    }
    else
    {
        return nil;
    }
}

- (NSURL *)privateFrameworksURL
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        return [(NSURL *)CFBundleCopyPrivateFrameworksURL(bundle) autorelease];
    }
    else
    {
        return nil;
    }
}

- (NSURL *)sharedFrameworksURL
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        return [(NSURL *)CFBundleCopySharedFrameworksURL(bundle) autorelease];
    }
    else
    {
        return nil;
    }
}

- (NSURL *)sharedSupportURL
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        return [(NSURL *)CFBundleCopySharedSupportURL(bundle) autorelease];
    }
    else
    {
        return nil;
    }
}

- (NSURL *)builtInPlugInsURL
{
    CFBundleRef bundle = [self _cfBundle];
    if (bundle != NULL)
    {
        return [(NSURL *)CFBundleCopyBuiltInPlugInsURL(bundle) autorelease];
    }
    else
    {
        return nil;
    }
}

- (NSURL *)appStoreReceiptURL
{
    NSURL *url = [self bundleURL];
    if (url != nil)
    {
        url = [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"StoreKit" isDirectory:YES];
    }
    return [url URLByAppendingPathComponent:@"receipt" isDirectory:NO];
}


- (NSString *)localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName
{
    return [(NSString *)CFBundleCopyLocalizedString(_cfBundle, (CFStringRef)key, (CFStringRef)value, (CFStringRef)tableName) autorelease];
}

- (id)objectForInfoDictionaryKey:(NSString *)key
{
    return (id)CFBundleGetValueForInfoDictionaryKey(_cfBundle, (CFStringRef)key);
}

- (NSString *)bundleIdentifier
{
    return [[self infoDictionary] objectForKey:@"CFBundleIdentifier"];
}

- (BOOL)load
{
    return [self loadAndReturnError:NULL];
}

- (BOOL)isLoaded
{
    @synchronized(self) {
        return (_flags & NSBundleIsLoadedFlag) != 0;
    }
}

- (void)_setIsLoaded: (BOOL)isLoaded
{
    @synchronized(self) {
        if (isLoaded) {
            _flags |= NSBundleIsLoadedFlag;
        } else {
            _flags &= ~NSBundleIsLoadedFlag;
        }
    }
}

- (BOOL)unload
{
    // Not supported
    return NO;
}

- (BOOL)preflightAndReturnError:(NSError **)error
{
    if (error != NULL)
    {
        *error = nil;
    }
    return CFBundlePreflightExecutable(_cfBundle, (CFErrorRef *)error);
}

- (BOOL)loadAndReturnError:(NSError **)error
{
    if (error != NULL)
    {
        *error = nil;
    }
    Boolean loaded = false;
    // synchronize this entire block to prevent simultaneous loads
    @synchronized(self)
    {
        if (![self isLoaded])
        {
            loaded = CFBundleLoadExecutableAndReturnError(_cfBundle, (CFErrorRef *)error);
            if (loaded)
            {
                [self _setIsLoaded: YES];
            }
        }
    }

    return loaded;
}

- (Class)classNamed:(NSString *)className
{
#warning TODO: classNamed should lookup by images
    return NSClassFromString(className);
}

- (Class)principalClass
{
    if (![self isLoaded])
    {
        [self load];
    }
    if (_principalClass == Nil)
    {
        NSString *principalClassName = [[self infoDictionary] objectForKey:@"NSPrincipalClass"];
        Class cls = NSClassFromString(principalClassName);
        // ensure an initialize is triggered and the class is reasonable
        if (cls != Nil && class_respondsToSelector(object_getClass(cls), @selector(self)))
        {
            _principalClass = [cls self];
        }
    }
    return _principalClass;
}

- (NSArray *)localizations
{
    return [(NSArray *)CFBundleCopyBundleLocalizations(_cfBundle) autorelease];
}

- (NSArray *)preferredLocalizations
{
    return [NSBundle preferredLocalizationsFromArray:[self localizations]];
}

- (NSString *)developmentLocalization
{
    return [(NSString *)CFBundleGetDevelopmentRegion(_cfBundle) autorelease];
}

+ (NSArray *)preferredLocalizationsFromArray:(NSArray *)localizationsArray
{
    return [(NSArray *)CFBundleCopyPreferredLocalizationsFromArray((CFArrayRef)localizationsArray) autorelease];
}

- (NSArray *)executableArchitectures
{
    return [(NSArray *)CFBundleCopyExecutableArchitectures(_cfBundle) autorelease];
}

@end
