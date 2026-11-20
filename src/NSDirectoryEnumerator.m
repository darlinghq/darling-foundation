//
//  NSDirectoryEnumerator.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSDirectoryEnumerator.h"
#import "NSObjectInternal.h"
#import <Foundation/NSError.h>
#import <Foundation/FoundationErrors.h>
#include <dirent.h>
#include <errno.h>
#include <limits.h>

@implementation NSDirectoryEnumerator

- (NSDictionary *)fileAttributes
{
    NSRequestConcreteImplementation();
    return nil;
}

- (NSDictionary *)directoryAttributes
{
    NSRequestConcreteImplementation();
    return nil;
}

- (void)skipDescendents
{
    [self skipDescendants];
}

- (NSUInteger)level
{
    NSRequestConcreteImplementation();
    return 0;
}

- (void)skipDescendants
{
    NSRequestConcreteImplementation();
}

@end

@implementation NSAllDescendantPathsEnumerator

+ (id)newWithPath:(NSString *)path prepend:(NSString *)prefix attributes:(NSArray *)properties cross:(BOOL)cross depth:(NSUInteger)depth
{
    NSAllDescendantPathsEnumerator *enumerator = [[NSAllDescendantPathsEnumerator alloc] init];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    enumerator->contents = [[fm contentsOfDirectoryAtPath:path error:NULL] copy];
    enumerator->path = [path copy];
    enumerator->prepend = [prefix copy];
    enumerator->cross = cross;
    enumerator->depth = depth;
    enumerator->directoryAttributes = nil;
    
    return enumerator;
}

- (void)dealloc
{
    [contents release];
    [path release];
    [prepend release];
    [under release];
    [super dealloc];
}

- (void)skipDescendants
{
    cross = NO;
}

- (void)skipDescendents
{
    [self skipDescendants];
}

- (NSAllDescendantPathsEnumerator *)_under
{
    return under;
}

- (NSUInteger)level
{
    return depth;
}

- (id)currentSubdirectoryAttributes
{
    return [[NSFileManager defaultManager] attributesOfItemAtPath:[pathToLastReportedItem stringByDeletingLastPathComponent] error:NULL];
}

- (NSDictionary *)directoryAttributes
{
    return [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
}

- (NSDictionary *)fileAttributes
{
    return [[NSFileManager defaultManager] attributesOfItemAtPath:pathToLastReportedItem error:NULL];
}

- (id)nextObject
{
    NSString *item = nil;
    if (under != nil)
    {
        item = [under nextObject];
        if (item == nil)
        {
            [under release];
            under = nil;
        }
    }
    
    if ([contents count] > idx && item == nil)
    {
        item = contents[idx];
        pathToLastReportedItem = [[path stringByAppendingPathComponent:item] retain];
        BOOL isDir = NO;
        BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:pathToLastReportedItem isDirectory:&isDir];
        if (exists && isDir && cross)
        {
            under = [NSAllDescendantPathsEnumerator newWithPath:pathToLastReportedItem prepend:item attributes:nil cross:cross depth:depth + 1];
        }
        idx++;
    }
    
    if (prepend != nil && item != nil)
    {
        return [NSString stringWithFormat:@"%@/%@", prepend, item];
    }
    else
    {
        return item;
    }
}

@end

static CFURLEnumeratorOptions CFURLEnumeratorOptionsFromNSDirectoryEnumeration(NSDirectoryEnumerationOptions opts)
{
    CFURLEnumeratorOptions options = kCFURLEnumeratorDefaultBehavior;
    if ((opts & NSDirectoryEnumerationSkipsSubdirectoryDescendants) == 0)
    {
        options |= kCFURLEnumeratorDescendRecursively;
    }
    
    if ((opts & NSDirectoryEnumerationSkipsHiddenFiles) != 0)
    {
        options |= kCFURLEnumeratorSkipInvisibles;
    }

    if ((opts & NSVolumeEnumerationProduceFileReferenceURLs) != 0)
    {
        options |= kCFURLEnumeratorGenerateFileReferenceURLs;
    }

    if ((opts & NSDirectoryEnumerationSkipsPackageDescendants) != 0)
    {
        options |= kCFURLEnumeratorSkipPackageContents;
    }

    return options;
}

// The error passed to the error handler: a Cocoa file reading error for the
// POSIX error the enumeration ran into, as with the path-based file calls.
static NSError *NSURLDirectoryEnumeratorError(NSURL *url, int err)
{
    NSInteger code;
    switch (err)
    {
        case ENOENT:
        case ENOTDIR:
            code = NSFileReadNoSuchFileError;
            break;
        case EACCES:
        case EPERM:
            code = NSFileReadNoPermissionError;
            break;
        default:
            code = NSFileReadUnknownError;
            break;
    }
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (url != nil)
    {
        [info setObject:url forKey:NSURLErrorKey];
        if ([url path] != nil)
        {
            [info setObject:[url path] forKey:NSFilePathErrorKey];
        }
    }
    [info setObject:[NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil] forKey:NSUnderlyingErrorKey];
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:info];
}

static NSError *NSURLDirectoryEnumeratorErrorFromCFError(NSURL *url, CFErrorRef error)
{
    NSError *e = (NSError *)error;
    if (e != nil && [[e domain] isEqualToString:NSPOSIXErrorDomain])
    {
        return NSURLDirectoryEnumeratorError(url, (int)[e code]);
    }
    if (e != nil)
    {
        return [[e retain] autorelease];
    }
    return NSURLDirectoryEnumeratorError(url, EIO);
}

@implementation NSURLDirectoryEnumerator

@synthesize errorHandler = _errorHandler;

- (id)initWithURL:(NSURL *)url includingPropertiesForKeys:(NSArray *)properties options:(NSDirectoryEnumerationOptions)options errorHandler:(BOOL (^)(NSURL *url, NSError *error))handler
{
    self = [super init];
    if (self)
    {
        if (!url)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"URL is nil" userInfo:nil];
        }

        _enumerator = CFURLEnumeratorCreateForDirectoryURL(kCFAllocatorDefault, (CFURLRef)[url standardizedURL], CFURLEnumeratorOptionsFromNSDirectoryEnumeration(options), (CFArrayRef)properties);
        self.errorHandler = handler;
        shouldContinue = YES;
        if (_enumerator == NULL)
        {
            // The directory cannot be read: the enumerator is still returned and
            // reports the error to the handler when it is first asked for an item.
            int err = EIO;
            char path[PATH_MAX];
            if ([url getFileSystemRepresentation:path maxLength:sizeof(path)])
            {
                DIR *dir = opendir(path);
                if (dir != NULL)
                {
                    closedir(dir);
                }
                else
                {
                    err = errno;
                }
            }
            _pendingErrorURL = [url retain];
            _pendingError = [NSURLDirectoryEnumeratorError(url, err) retain];
        }
    }
    return self;
}

- (void)dealloc
{
    if (_enumerator)
    {
        CFRelease(_enumerator);
    }
    self.errorHandler = nil;
    [_pendingErrorURL release];
    [_pendingError release];
    [super dealloc];
}

- (NSDictionary *)directoryAttributes
{
    return nil;
}

- (NSDictionary *)fileAttributes
{
    return nil;
}

- (NSUInteger)level
{
    return (NSUInteger)CFURLEnumeratorGetDescendentLevel(_enumerator);
}

- (void)skipDescendants
{
    CFURLEnumeratorSkipDescendents(_enumerator);
}

- (void)skipDescendents
{
    [self skipDescendants];
}

// Reports an error to the handler; enumeration goes on only if the handler says so.
// Without a handler it goes on, as if the handler had returned YES.
- (void)_reportError:(NSError *)error forURL:(NSURL *)url
{
    if (self.errorHandler != NULL)
    {
        shouldContinue = self.errorHandler(url, error);
    }
}

- (id)nextObject
{
    while (shouldContinue)
    {
        if (_pendingError != nil)
        {
            NSURL *errorURL = [_pendingErrorURL autorelease];
            NSError *error = [_pendingError autorelease];
            _pendingErrorURL = nil;
            _pendingError = nil;
            [self _reportError:error forURL:errorURL];
            continue;
        }
        if (_enumerator == NULL)
        {
            break;
        }

        CFURLRef url = NULL;
        CFErrorRef error = NULL;
        // The URL follows the Get rule: the enumerator keeps it only until
        // the next call. The error is ours to release.
        CFURLEnumeratorResult result = CFURLEnumeratorGetNextURL(_enumerator, &url, &error);
        if (result == kCFURLEnumeratorSuccess || result == kCFURLEnumeratorDirectoryPostOrderSuccess)
        {
            return [[(NSURL *)url retain] autorelease];
        }
        if (result == kCFURLEnumeratorError)
        {
            NSURL *errorURL = (NSURL *)url;
            NSError *nsError = NSURLDirectoryEnumeratorErrorFromCFError(errorURL, error);
            if (error != NULL)
            {
                CFRelease(error);
            }
            if (errorURL != nil)
            {
                // A directory that cannot be read is still returned itself; the
                // error is reported on the next call, as macOS does.
                _pendingErrorURL = [errorURL retain];
                _pendingError = [nsError retain];
                return [[errorURL retain] autorelease];
            }
            [self _reportError:nsError forURL:nil];
            continue;
        }
        if (error != NULL)
        {
            CFRelease(error);
        }
        break;
    }
    return nil;
}

@end
