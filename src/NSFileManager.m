//
//  NSFileManager.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <dispatch/dispatch.h>
#import <dirent.h>
#import <errno.h>
#import <math.h>
#import <unistd.h>
#import <stdio.h>
#import <stdlib.h>
#import <sys/param.h>
#import <sys/mount.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <copyfile.h>
#import <CoreFoundation/CFURL.h>
#import <MacTypes.h> // for kUnknownType

#import <Foundation/NSURL.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSError.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSException.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/FoundationErrors.h>

#import "NSDirectoryEnumerator.h"
#import "NSFileAttributes.h"
#import "NSFileManagerInternal.h"
#import "NSPathStore.h"
#import "NSFilesystemItemRemoveOperation.h"

CF_EXPORT CFStringEncoding CFStringFileSystemEncoding(void);

NSString *const NSUbiquityIdentityDidChangeNotification = @"NSUbiquityIdentityDidChangeNotification";
NSString *const NSFileType = @"NSFileType";
NSString *const NSFileTypeDirectory = @"NSFileTypeDirectory";
NSString *const NSFileTypeRegular = @"NSFileTypeRegular";
NSString *const NSFileTypeSymbolicLink = @"NSFileTypeSymbolicLink";
NSString *const NSFileTypeSocket = @"NSFileTypeSocket";
NSString *const NSFileTypeCharacterSpecial = @"NSFileTypeCharacterSpecial";
NSString *const NSFileTypeBlockSpecial = @"NSFileTypeBlockSpecial";
NSString *const NSFileTypeUnknown = @"NSFileTypeUnknown";
NSString *const NSFileSize = @"NSFileSize";
NSString *const NSFileModificationDate = @"NSFileModificationDate";
NSString *const NSFileReferenceCount = @"NSFileReferenceCount";
NSString *const NSFileDeviceIdentifier = @"NSFileDeviceIdentifier";
NSString *const NSFileOwnerAccountName = @"NSFileOwnerAccountName";
NSString *const NSFileGroupOwnerAccountName = @"NSFileGroupOwnerAccountName";
NSString *const NSFilePosixPermissions = @"NSFilePosixPermissions";
NSString *const NSFileSystemNumber = @"NSFileSystemNumber";
NSString *const NSFileSystemFileNumber = @"NSFileSystemFileNumber";
NSString *const NSFileExtensionHidden = @"NSFileExtensionHidden";
NSString *const NSFileHFSCreatorCode = @"NSFileHFSCreatorCode";
NSString *const NSFileHFSTypeCode = @"NSFileHFSTypeCode";
NSString *const NSFileImmutable = @"NSFileImmutable";
NSString *const NSFileAppendOnly = @"NSFileAppendOnly";
NSString *const NSFileCreationDate = @"NSFileCreationDate";
NSString *const NSFileOwnerAccountID = @"NSFileOwnerAccountID";
NSString *const NSFileGroupOwnerAccountID = @"NSFileGroupOwnerAccountID";
NSString *const NSFileBusy = @"NSFileBusy";
NSString *const NSFileProtectionKey = @"NSFileProtectionKey";
NSString *const NSFileProtectionNone = @"NSFileProtectionNone";
NSString *const NSFileProtectionComplete = @"NSFileProtectionComplete";
NSString *const NSFileProtectionCompleteUnlessOpen = @"NSFileProtectionCompleteUnlessOpen";
NSString *const NSFileProtectionCompleteUntilFirstUserAuthentication = @"NSFileProtectionCompleteUntilFirstUserAuthentication";
NSString *const NSFileSystemSize = @"NSFileSystemSize";
NSString *const NSFileSystemFreeSize = @"NSFileSystemFreeSize";
NSString *const NSFileSystemNodes = @"NSFileSystemNodes";
NSString *const NSFileSystemFreeNodes = @"NSFileSystemFreeNodes";

// Internal enum values
enum {
    NSDirectoryEnumerationRecursive    = 1UL << 7,
    NSDirectoryEnumerationGenerateURLs = 1UL << 8
};

@interface NSFileManager ()
- (NSArray *)directoryContentsAtPath:(NSString *)path matchingExtension:(NSString *)extension options:(NSDirectoryEnumerationOptions)options keepExtension:(BOOL)keepExtension error:(NSError **)error;
@end

// QUIRK: macOS file systems treat the precomposed and the decomposed spelling of a name as the same
// file, so a path finds an existing file whichever spelling it uses; names are created in the
// decomposed spelling of -fileSystemRepresentation. Linux file systems compare the bytes, so the
// lookups here try the file system representation and then the path as given, which finds files that
// exist only in the spelling of the caller. Evidence: black-box observation of NSFileManager on
// macOS 26.7.3 (tier 2, MAC-EVIDENCE "Unicode normalization of paths").
// Test: tests/filemanager-unicode-normalization.m
static int _NSFileManagerStat(NSString *path, struct stat *s, BOOL followLinks)
{
    const char *representation = [path fileSystemRepresentation];
    int err = followLinks ? stat(representation, s) : lstat(representation, s);

    if (err == -1 && errno == ENOENT)
    {
        const char *literal = [path UTF8String];

        if (literal != NULL && strcmp(literal, representation) != 0)
        {
            err = followLinks ? stat(literal, s) : lstat(literal, s);
        }
    }
    return err;
}

@implementation NSFileManager

static void initializeDirectories(NSMutableSet *paths, NSSearchPathDirectory directory)
{
    [paths addObjectsFromArray:NSSearchPathForDirectoriesInDomains(directory, NSAllDomainsMask, YES)];
}

- (id)init
{
    self = [super init];
    if (self)
    {
        static pthread_mutex_t lock = PTHREAD_RECURSIVE_MUTEX_INITIALIZER;
        static BOOL initialized = NO;
        pthread_mutex_lock(&lock);
        if (!initialized)
        {
            initialized = YES;
            NSMutableSet *paths = [[NSMutableSet alloc] init];
            initializeDirectories(paths, NSApplicationDirectory);
            initializeDirectories(paths, NSDemoApplicationDirectory);
            initializeDirectories(paths, NSDeveloperApplicationDirectory);
            initializeDirectories(paths, NSAdminApplicationDirectory);
            initializeDirectories(paths, NSLibraryDirectory);
            initializeDirectories(paths, NSDeveloperDirectory);
            initializeDirectories(paths, NSUserDirectory);
            initializeDirectories(paths, NSDocumentationDirectory);
            initializeDirectories(paths, NSDocumentDirectory);
            initializeDirectories(paths, NSCoreServiceDirectory);
            initializeDirectories(paths, NSAutosavedInformationDirectory);
            initializeDirectories(paths, NSDesktopDirectory);
            initializeDirectories(paths, NSCachesDirectory);
            initializeDirectories(paths, NSApplicationSupportDirectory);
            initializeDirectories(paths, NSDownloadsDirectory);
            initializeDirectories(paths, NSInputMethodsDirectory);
            initializeDirectories(paths, NSMoviesDirectory);
            initializeDirectories(paths, NSMusicDirectory);
            initializeDirectories(paths, NSPicturesDirectory);
            initializeDirectories(paths, NSPrinterDescriptionDirectory);
            initializeDirectories(paths, NSSharedPublicDirectory);
            initializeDirectories(paths, NSPreferencePanesDirectory);
            initializeDirectories(paths, NSApplicationScriptsDirectory);
            initializeDirectories(paths, NSItemReplacementDirectory);
            for (NSString *path in paths)
            {
                BOOL isDir = NO;
                BOOL exists = [self fileExistsAtPath:path isDirectory:&isDir];
                if (!exists)
                {
                    [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
                }
            }
            [paths release];
        }
        pthread_mutex_unlock(&lock);
    }
    return self;
}

+ (NSFileManager *)defaultManager
{
    static NSFileManager *defaultManager = nil;
    static pthread_mutex_t lock = PTHREAD_RECURSIVE_MUTEX_INITIALIZER;
    pthread_mutex_lock(&lock);
    if (defaultManager == nil)
    {
        defaultManager = [[NSFileManager alloc] init];
        
    }
    pthread_mutex_unlock(&lock);
    return (NSFileManager *)defaultManager;
}

- (void)setDelegate:(id)delegate
{
    if (_delegate != delegate)
    {
        _delegate = delegate;
        _flags.shouldCopyItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldCopyItemAtPath:toPath:)];
        _flags.shouldCopyItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldCopyItemAtURL:toURL:)];
        _flags.shouldProceedAfterErrorCopyingItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:copyingItemAtPath:toPath:)];
        _flags.shouldProceedAfterErrorCopyingItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:copyingItemAtURL:toURL:)];
        _flags.shouldMoveItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldMoveItemAtPath:toPath:)];
        _flags.shouldMoveItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldMoveItemAtURL:toURL:)];
        _flags.shouldProceedAfterErrorMovingItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:movingItemAtPath:toPath:)];
        _flags.shouldProceedAfterErrorMovingItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:movingItemAtURL:toURL:)];
        _flags.shouldLinkItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldLinkItemAtPath:toPath:)];
        _flags.shouldLinkItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldLinkItemAtURL:toURL:)];
        _flags.shouldProceedAfterErrorLinkingItemAtPathToPath = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:linkingItemAtPath:toPath:)];
        _flags.shouldProceedAfterErrorLinkingItemAtURLToURL = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:linkingItemAtURL:toURL:)];
        _flags.shouldRemoveItemAtPath = [delegate respondsToSelector:@selector(fileManager:shouldRemoveItemAtPath:)];
        _flags.shouldRemoveItemAtURL = [delegate respondsToSelector:@selector(fileManager:shouldRemoveItemAtURL:)];
        _flags.shouldProceedAfterErrorRemovingItemAtPath = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:removingItemAtPath:)];
        _flags.shouldProceedAfterErrorRemovingItemAtURL = [delegate respondsToSelector:@selector(fileManager:shouldProceedAfterError:removingItemAtURL:)];
    }
}

- (id)delegate
{
    return _delegate;
}

- (BOOL)fileExistsAtPath:(NSString *)path
{
    return [self fileExistsAtPath:path isDirectory:NULL];
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory
{
    if (path == nil)
    {
        return NO;
    }
    BOOL exists = NO;
    BOOL isDir = NO;
    struct stat s;
    int err = _NSFileManagerStat(path, &s, YES);
    if (err == 0)
    {
        exists = YES;
        if (S_ISDIR(s.st_mode))
        {
            isDir = YES;
        }
    }
    if (isDirectory)
    {
        *isDirectory = isDir;
    }
    return exists;
}

static inline BOOL _NSFileAccessibleForMode(NSString *path, int mode)
{
    char buffer[BUG_COMPLIANT_PATH_MAX];
    if ([path getFileSystemRepresentation:buffer maxLength:BUG_COMPLIANT_PATH_MAX])
    {
        return access(buffer, mode) == 0;
    }
    else
    {
        return NO;
    }
}

- (BOOL)isReadableFileAtPath:(NSString *)path
{
    return _NSFileAccessibleForMode(path, R_OK);
}

- (BOOL)isWritableFileAtPath:(NSString *)path
{
    return _NSFileAccessibleForMode(path, W_OK);
}

- (BOOL)isExecutableFileAtPath:(NSString *)path
{
    return _NSFileAccessibleForMode(path, X_OK);
}

- (BOOL)isDeletableFileAtPath:(NSString *)path
{
    NSString *parent = [path stringByDeletingLastPathComponent];
    if (parent == nil)
    {
        parent = [self currentDirectoryPath];
    }

    return [self isWritableFileAtPath:parent];
}

- (NSString *)displayNameAtPath:(NSString *)path
{
    return [[[path lastPathComponent] componentsSeparatedByString:@":"] componentsJoinedByString:NSPathSep];
}

- (NSArray *)componentsToDisplayForPath:(NSString *)path
{
    return [path pathComponents];
}

- (NSArray *)directoryContentsAtPath:(NSString *)path matchingExtension:(NSString *)extension options:(NSDirectoryEnumerationOptions)options keepExtension:(BOOL)keepExtension error:(NSError **)error
{
    NSMutableArray *files = [NSMutableArray array];
    NSError* localError = nil;
    [self _directoryContentsAtPath:path 
                matchingExtension:extension
                options:options
                keepExtension:keepExtension
                error:&localError
                toResult:files];
    if (localError != nil)
    {
        if (error)
        {
            *error = localError;
        }
        return nil;
    }
    if (options & NSDirectoryEnumerationGenerateURLs)
    {
        return [files sortedArrayUsingComparator:^(NSURL *url1, NSURL *url2){
            return [url1.path caseInsensitiveCompare:url2.path];
        }];
    }
    else
    {
        return [files sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    }
}

- (void)_directoryContentsAtPath:(NSString *)path matchingExtension:(NSString *)extension options:(NSDirectoryEnumerationOptions)options keepExtension:(BOOL)keepExtension error:(NSError **)error toResult:(NSMutableArray *)files
{
    DIR *dirp = opendir([path fileSystemRepresentation]);
    if (!dirp) {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
        }
        return;
    }

    struct dirent buffer;
    struct dirent *dp;

    while ((0 == readdir_r(dirp, &buffer, &dp)) && dp) {
        unsigned namelen = strlen(dp->d_name);
        if ((namelen == 1 && dp->d_name[0] == PATH_DOT) || (namelen == 2 && dp->d_name[0] == PATH_DOT && dp->d_name[1] == PATH_DOT))
        {
            continue;
        }

        if (dp->d_name[0] == PATH_DOT && ((options & NSDirectoryEnumerationSkipsHiddenFiles) != 0))
        {
            continue;
        }

        NSString *item = [NSString stringWithUTF8String:dp->d_name];
        if (!(extension != nil && ![[item pathExtension] isEqualToString:extension]))
        {
            if ((options & NSDirectoryEnumerationGenerateURLs) != 0)
            {
                [files addObject:[NSURL fileURLWithPath:[path stringByAppendingPathComponent:item]]];
            }
            else
            {
                if (!keepExtension)
                {
                    [files addObject:[item stringByDeletingPathExtension]];
                }
                else
                {
                    [files addObject:item];
                }
            }
        }

        // should NSDirectoryEnumerationSkipsPackageDescendants be checked somehow here?
        if (dp->d_type == DT_DIR && (options & NSDirectoryEnumerationRecursive) != 0)
        {
            [self _directoryContentsAtPath:[path stringByAppendingPathComponent:item] 
                                            matchingExtension:extension
                                                      options:options
                                                keepExtension:keepExtension
                                                        error:error
                                                        toResult:files];
        }
    }
    closedir(dirp);
}


- (NSArray *)mountedVolumeURLsIncludingResourceValuesForKeys:(NSArray *)propertyKeys options:(NSVolumeEnumerationOptions)options
{
    return nil;
}

- (NSArray *)contentsOfDirectoryAtURL:(NSURL *)directoryUrl includingPropertiesForKeys:(NSArray *)keys options:(NSDirectoryEnumerationOptions)mask error:(NSError **)error
{
    NSArray *urls = [self directoryContentsAtPath:[directoryUrl path]
                                matchingExtension:nil 
                                          options:mask | NSDirectoryEnumerationGenerateURLs 
                                    keepExtension:YES 
                                            error:error];
    // TODO: refactor this... it is rather ineffecient
    for (NSURL *url in urls)
    {
        struct stat s;
        int err = _NSFileManagerStat([url path], &s, YES);
        if (err != 0)
        {
            if (error)
            {
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
                }];
            }
            return urls;
        }
        for (NSString *key in keys)
        {
            CFTypeRef value = NULL;
            if ([key isEqualToString:NSURLNameKey])
            {
                value = [[url lastPathComponent] retain];
            }
            else if ([key isEqualToString:NSURLLocalizedNameKey])
            {
                value = [[[url lastPathComponent] stringByDeletingPathExtension] retain];
            }
            else if ([key isEqualToString:NSURLIsRegularFileKey])
            {
                value = [(S_ISREG(s.st_mode) ? @YES : @NO) retain];
            }
            else if ([key isEqualToString:NSURLIsDirectoryKey])
            {
                value = [(S_ISDIR(s.st_mode) ? @YES : @NO) retain];
            }
            else if ([key isEqualToString:NSURLIsSymbolicLinkKey])
            {
                value = [(S_ISLNK(s.st_mode) ? @YES : @NO) retain];
            }
            else if ([key isEqualToString:NSURLIsVolumeKey])
            {
                value = [@NO retain]; // is this even possible?
            }
            else if ([key isEqualToString:NSURLIsPackageKey])
            {
                value = [((S_ISDIR(s.st_mode) && [[[url lastPathComponent] pathExtension] length] > 0) ? @YES : @NO) retain];
            }
            else if ([key isEqualToString:NSURLIsUserImmutableKey])
            {

            }
            else if ([key isEqualToString:NSURLIsHiddenKey])
            {
                value = [([[url lastPathComponent] hasPrefix:NSPathDot] ? @YES : @NO) retain];
            }
            else if ([key isEqualToString:NSURLHasHiddenExtensionKey])
            {
                value = [@NO retain];
            }
            else if ([key isEqualToString:NSURLCreationDateKey])
            {
#ifdef ANDROID
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_ctime * NSEC_PER_SEC + s.st_ctime_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#elif defined(__APPLE__)
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_ctime * NSEC_PER_SEC + s.st_ctimespec.tv_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#else
#error Implementation needed for file time specs
#endif
            }
            else if ([key isEqualToString:NSURLContentAccessDateKey])
            {
#ifdef ANDROID
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_atime * NSEC_PER_SEC + s.st_atime_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#elif defined(__APPLE__)
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_atime * NSEC_PER_SEC + s.st_atimespec.tv_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#else
#error Implementation needed for file time specs
#endif
            }
            else if ([key isEqualToString:NSURLContentModificationDateKey])
            {
#ifdef ANDROID
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_mtime * NSEC_PER_SEC + s.st_mtime_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#elif defined(__APPLE__)
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_mtime * NSEC_PER_SEC + s.st_mtimespec.tv_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#else
#error Implementation needed for file time specs
#endif
            }
            else if ([key isEqualToString:NSURLAttributeModificationDateKey])
            {
#ifdef ANDROID
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_mtime * NSEC_PER_SEC + s.st_mtime_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#elif defined(__APPLE__)
                value = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)(s.st_mtime * NSEC_PER_SEC + s.st_mtimespec.tv_nsec) / (NSTimeInterval)NSEC_PER_SEC];
#else
#error Implementation needed for file time specs
#endif
            }
            else if ([key isEqualToString:NSURLParentDirectoryURLKey])
            {
                value = [[url URLByDeletingLastPathComponent] retain];
            }
            else if ([key isEqualToString:NSURLFileSizeKey])
            {
                value = [[NSNumber numberWithLongLong:s.st_size] retain];
            }
            else if ([key isEqualToString:NSURLFileAllocatedSizeKey])
            {
                value = [[NSNumber numberWithUnsignedLongLong:s.st_blksize * s.st_blocks] retain];
            }

            if (value)
            {
                CFErrorRef cfError = NULL;
                BOOL set = CFURLSetResourcePropertyForKey((CFURLRef)url, (CFStringRef)key, value, &cfError);

                CFRelease(value);

                if (!set)
                {
                    if (error)
                    {
                        *error = [(NSError*)cfError autorelease];
                    }
                    else if (cfError)
                    {
                        CFRelease(cfError);
                    }
                    return urls; // early escape out of both iterators
                }
            }
        }
    }
    return urls;
}

- (NSURL *)temporaryDirectory
{
    return [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
}

- (NSArray *)URLsForDirectory:(NSSearchPathDirectory)directory inDomains:(NSSearchPathDomainMask)domainMask {
    // Only NSUserDomain is supported on iOS
    if (domainMask != NSUserDomainMask)
    {
        return @[];
    }
    NSArray *pathsForDirectory = NSSearchPathForDirectoriesInDomains(directory, domainMask, YES);
    NSMutableArray *urls = [NSMutableArray arrayWithCapacity:[pathsForDirectory count]];

    for (NSString *s in pathsForDirectory) {
        [urls addObject:[NSURL fileURLWithPath:s]];
    }

    return [[urls copy] autorelease];
}

- (NSURL *)URLForDirectory:(NSSearchPathDirectory)directory inDomain:(NSSearchPathDomainMask)domain appropriateForURL:(NSURL *)url create:(BOOL)shouldCreate error:(NSError **)error
{
    // how is appropriateForURL come into play? it does not seem to be used...
    NSArray *paths = NSSearchPathForDirectoriesInDomains(directory, domain, YES);
    if ([paths count] == 0)
    {
        return nil;
    }

    NSString *path = [paths objectAtIndex:0];
    NSURL *dirUrl = [NSURL fileURLWithPath:path];
    if (shouldCreate && ![self fileExistsAtPath:path] &&
        ![self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error])
    {
        return nil;
    }

    return dirUrl;
}

// The directory apps in an app group share, where macOS keeps it:
// ~/Library/Group Containers/<identifier>. An application that holds no group entitlement still
// gets the URL on macOS, and the directory is not created by this call (macOS 10.14 and 26).
// An empty identifier names the Group Containers directory itself, as it does on macOS 10.14.
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier
{
    if (groupIdentifier == nil)
    {
        return nil;
    }
    NSString *path = [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Group Containers"] stringByAppendingPathComponent:groupIdentifier];
    return [NSURL fileURLWithPath:path isDirectory:YES];
}

- (BOOL)createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error
{
    if (createIntermediates)
    {
        NSArray *comps = [url pathComponents];
        NSURL *recomposed = nil;
        for (NSString *comp in comps)
        {
            if (recomposed == nil)
            {
                recomposed = [NSURL fileURLWithPath:comp];
            }
            else
            {
                recomposed = [recomposed URLByAppendingPathComponent:comp];
            }
            BOOL isDir = NO;
            BOOL exists = [self fileExistsAtPath:[recomposed path] isDirectory:&isDir];
            if (!exists)
            {
                isDir = YES;
                if (![self createDirectoryAtURL:recomposed withIntermediateDirectories:NO attributes:attributes error:error])
                {
                    return NO;
                }
            }
            else if (!isDir)
            {
                if (error)
                {
                    *error = [NSError errorWithDomain:NSFilePathErrorKey code:-1 userInfo:@{
                        NSLocalizedDescriptionKey: @"Found a file where a directory was expected"
                    }];
                }
                return NO;
            }
        }
        return YES;
    }
    else
    {
        mode_t mode = 0777;
        if (attributes[NSFilePosixPermissions])
        {
            mode = [attributes[NSFilePosixPermissions] intValue];
        }

        // NSFileOwnerAccountName
        // NSFileGroupOwnerAccountName
        // are possible, but not reasonable atm

        int err = mkdir([[url path] fileSystemRepresentation], mode);
        if (err == -1)
        {
            if (error)
            {
                *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
                }];
            }
            return NO;
        }

        return YES;
    }
}

- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error
{
    return [self createDirectoryAtURL:[NSURL fileURLWithPath:path] withIntermediateDirectories:createIntermediates attributes:attributes error:error];
}

- (BOOL)createDirectoryAtPath:(NSString *)path attributes:(NSDictionary *)attributes
{
    return [self createDirectoryAtPath:path withIntermediateDirectories:NO attributes:attributes error:nil];
}

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error
{
    if (path == nil) {
        if (error) {
            *error = [NSError errorWithDomain: NSCocoaErrorDomain
                                         code: NSFileReadUnknownError
                                     userInfo: @{ NSFilePathErrorKey: path }];
        }
        return nil;
    }
    struct stat s;
    int err = _NSFileManagerStat(path, &s, NO);
    if (err == -1)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
        }
        return nil;
    }
    return [NSFileAttributes attributesWithStat:&s];
}

- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data attributes:(NSDictionary *)attr
{
    if (data == nil) {
        data = [NSData data];
    }
    
    if (![data writeToFile:path atomically:YES])
    {
        return NO;
    }
    
    if (attr)
    {
        [self setAttributes:attr ofItemAtPath:path error:nil];
    }

    return YES;
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error
{
    if (path == NULL) {
        return NO;
    }

    NSFilesystemItemRemoveOperation *op = [NSFilesystemItemRemoveOperation filesystemItemRemoveOperationWithPath:path];
    [op setDelegate:self];
    [op start];
    if (error != NULL)
    {
        *error = [op error];
    }
    return [op error] == nil;
}

- (BOOL)removeItemAtURL:(NSURL *)URL error:(NSError **)error
{
    return [self removeItemAtPath:URL.path error:error];
}


#warning TODO implement remove with NSFilesystemItemRemoveOperation
    // NSFilesystemItemRemoveOperation *op = [NSFilesystemItemRemoveOperation filesystemItemRemoveOperationWithPath:path];
    // [op setDelegate:self];
    // [op start];
    // *error = [op error];

static NSError *_NSErrorWithFilePathAndErrno(id path, int code)
{
    NSString *pathKey = [path isKindOfClass:[NSURL class]] ? NSURLErrorKey : NSFilePathErrorKey;
    NSError *underlyingError = [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];
    NSDictionary *userInfo = path ? @{ pathKey: path, NSUnderlyingErrorKey: underlyingError } : @{ NSUnderlyingErrorKey: underlyingError };
    
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:userInfo];
}

- (BOOL)setAttributes:(NSDictionary *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error
{
    char buffer[BUG_COMPLIANT_PATH_MAX];
    
    if ([self getFileSystemRepresentation:buffer maxLength:BUG_COMPLIANT_PATH_MAX withPath:path])
    {
        NSNumber *posixPermissions = [attributes objectForKey:NSFilePosixPermissions];
        if (posixPermissions)
        {
            mode_t permissions = [posixPermissions shortValue];
            if (chmod(buffer, permissions) != 0)
            {
                if (error) {
                    *error = _NSErrorWithFilePathAndErrno(path, errno);
                }
                return NO;
            }
        }
        
        NSDate *creationDate = [attributes objectForKey:NSFileCreationDate];
        if (creationDate)
        {
            // Creation time is not stored by most Linux file systems.
            DEBUG_LOG("Setting file creation date is not supported (path: %s)", buffer);
        }
        
        NSDate *modificationDate = [attributes objectForKey:NSFileModificationDate];
        if (modificationDate)
        {
            NSTimeInterval modification = [modificationDate timeIntervalSince1970];
        
            struct timeval times[2];
            double wholeSeconds, fractionalSeconds = modf(modification, &wholeSeconds);
            times[0].tv_sec = wholeSeconds;
            times[0].tv_usec = lround(1000000.0 * fractionalSeconds);
            times[1] = times[0];

            if (utimes(buffer, times) != 0)
            {
                if (error) {
                    *error = _NSErrorWithFilePathAndErrno(path, errno);
                }
                return NO;
            }
        }
        
        return YES;
    }
    else
    {
        if (error) {
            *error = _NSErrorWithFilePathAndErrno(path, ENOENT);
        }
        return NO;
    }
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)path traverseLink:(BOOL)yorn
{
    struct stat s;
    int err = 0;
    if (yorn)
    {
        err = _NSFileManagerStat(path, &s, YES);
    }
    else
    {
        err = _NSFileManagerStat(path, &s, NO);
    }
    if (err == -1)
    {
        return nil;
    }
    else
    {
        return [NSFileAttributes attributesWithStat:&s];
    }
}

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error
{
    char pathbuf[BUG_COMPLIANT_PATH_MAX];
    if (![path getFileSystemRepresentation:pathbuf maxLength:BUG_COMPLIANT_PATH_MAX])
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:@{
                NSLocalizedDescriptionKey: @"file not found"
            }];
        }
        return nil;
    }
    
    struct statfs statbuf;
    if (statfs(pathbuf, &statbuf) != 0)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
        }
        return nil;
    }
    
    #define FILESYSTEM_NUM_ATTRIBUTES 5
    
    NSString *keys[FILESYSTEM_NUM_ATTRIBUTES] = {
        NSFileSystemNumber,
        NSFileSystemSize,
        NSFileSystemFreeSize,
        NSFileSystemNodes,
        NSFileSystemFreeNodes
    };
    
    unsigned long long blocksize = statbuf.f_bsize;
    long fsnumber;
    memcpy(&fsnumber, &statbuf.f_fsid, sizeof(fsnumber));
    
    NSNumber *objects[FILESYSTEM_NUM_ATTRIBUTES] = {
        [NSNumber numberWithUnsignedLong:fsnumber],
        [NSNumber numberWithUnsignedLongLong:blocksize * (unsigned long long)statbuf.f_blocks],
        [NSNumber numberWithUnsignedLongLong:blocksize * (unsigned long long)statbuf.f_bavail],
        [NSNumber numberWithLong:statbuf.f_files],
        [NSNumber numberWithLong:statbuf.f_ffree],
    };
    
    if (error)
    {
        *error = nil;
    }
    
    return [NSDictionary dictionaryWithObjects:objects forKeys:keys count:FILESYSTEM_NUM_ATTRIBUTES];
    #undef FILESYSTEM_NUM_ATTRIBUTES
}

- (NSString *)currentDirectoryPath
{
    char buffer[BUG_COMPLIANT_PATH_MAX];
    if (getcwd(buffer, BUG_COMPLIANT_PATH_MAX) != NULL)
    {
        return [self stringWithFileSystemRepresentation:buffer length:strlen(buffer)];
    }
    else
    {
        return nil;
    }
}

- (BOOL)changeCurrentDirectoryPath:(NSString*)path
{
    char buffer[BUG_COMPLIANT_PATH_MAX];
    if ([self getFileSystemRepresentation:buffer maxLength:BUG_COMPLIANT_PATH_MAX withPath:path])
    {
        return chdir(buffer) == 0;
    }
    else
    {
        return NO;
    }
}

- (BOOL)changeFileAttributes:(NSDictionary *)attributes atPath:(NSString *)path
{
    return [self setAttributes:attributes ofItemAtPath:path error:nil];
}

// Deprecated since macOS 10.5 but still part of the interface: the shallow contents of the
// directory, or nil when it cannot be read.
- (NSArray *)directoryContentsAtPath:(NSString *)path
{
    return [self contentsOfDirectoryAtPath:path error:NULL];
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error
{
    return [self directoryContentsAtPath:path matchingExtension:nil options:0 keepExtension:YES error:error];
}

- (NSArray *)subpathsOfDirectoryAtPath:(NSString *)path error:(NSError **)error
{
    return [self directoryContentsAtPath:path matchingExtension:nil options:NSDirectoryEnumerationRecursive keepExtension:YES error:error];
}

- (BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError **)error
{
    if (error)
    {
        *error = nil;
    }
    BOOL shouldLink = YES;
    if (_flags.shouldLinkItemAtPathToPath)
    {
        shouldLink = [_delegate fileManager:self shouldLinkItemAtPath:path toPath:destPath];
    }
    if (!shouldLink)
    {
        return NO;
    }
    int err = symlink([destPath UTF8String], [path fileSystemRepresentation]);
    if (err == -1)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
        }
        return NO;
    }
    return YES;
}

- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path error:(NSError **)error
{
    char destination[PATH_MAX];
    ssize_t length = readlink([path fileSystemRepresentation], destination, sizeof(destination));
    if (length < 0 || (size_t)length == sizeof(destination))
    {
        int savedError = length < 0 ? errno : ENAMETOOLONG;
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:savedError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(savedError)]
            }];
        }
        return nil;
    }
    return [self stringWithFileSystemRepresentation:destination length:(NSUInteger)length];
}

- (NSString *)pathContentOfSymbolicLinkAtPath:(NSString *)path
{
    return [self destinationOfSymbolicLinkAtPath:path error:NULL];
}


- (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error
{
    NSString *dstDir = [dstPath stringByDeletingLastPathComponent];
    BOOL isDir = NO;
    BOOL exists = [self fileExistsAtPath:dstDir isDirectory:&isDir];
    if (exists && !isDir)
    {
#warning TODO: Error should be populated here
        return NO;
    }
    else if (!exists)
    {
        if (![self createDirectoryAtPath:dstDir withIntermediateDirectories:YES attributes:nil error:error])
        {
            return NO;
        }
    }
    if ([self attributesOfItemAtPath:dstPath error:NULL] != nil)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteFileExistsError
                                     userInfo:@{NSFilePathErrorKey: dstPath,
                                                NSUnderlyingErrorKey: [NSError errorWithDomain:NSPOSIXErrorDomain code:EEXIST userInfo:nil]}];
        }
        return NO;
    }
    copyfile_flags_t flags = COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_NOFOLLOW_SRC | COPYFILE_EXCL;
    if (error != NULL)
    {
        *error = nil;
    }
    int err = copyfile([srcPath fileSystemRepresentation], [dstPath fileSystemRepresentation], NULL, flags);

    if (err != 0)
    {
        if (error)
        {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
        }
        return NO;
    }
    return YES;
}

- (BOOL)copyItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error
{
    return [self copyItemAtPath:srcURL.path toPath:dstURL.path error:error];
}

- (NSData *)contentsAtPath:(NSString *)path
{
    return [[[NSData alloc] initWithContentsOfFile:path] autorelease];
}

- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error
{
    if (error != NULL) {
        *error = nil;
    }

    BOOL exists = [self fileExistsAtPath:dstPath];
    if (exists)
    {
        if (error != NULL)
        {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteFileExistsError userInfo:@{
                NSLocalizedDescriptionKey: @"Item couldn't be moved because an item with the same name already exists.",
                NSFilePathErrorKey: dstPath,
            }];
        }
        return NO;
    }

    if (rename([srcPath fileSystemRepresentation], [dstPath fileSystemRepresentation]) != -1) {
        return YES;
    }

    if (error != NULL) {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:@{
            NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]
            }];
    }
    return NO;
}

- (BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error
{
    return [self moveItemAtPath:srcURL.path toPath:dstURL.path error:error];
}

- (NSDirectoryEnumerator *)enumeratorAtPath:(NSString *)path
{
    return [[NSAllDescendantPathsEnumerator newWithPath:path prepend:nil attributes:nil cross:YES depth:1] autorelease];
}

- (NSDirectoryEnumerator *)enumeratorAtURL:(NSURL *)url includingPropertiesForKeys:(NSArray *)keys options:(NSDirectoryEnumerationOptions)mask errorHandler:(BOOL (^)(NSURL *url, NSError *error))handler
{
    if (url == nil)
    {
        [NSException raise:NSInvalidArgumentException format:@"URL is nil"];
        return nil;
    }
    return [[[NSURLDirectoryEnumerator alloc] initWithURL:url includingPropertiesForKeys:keys options:mask errorHandler:handler] autorelease];
}

- (NSArray *)subpathsAtPath:(NSString *)path
{
    return [[self enumeratorAtPath:path] allObjects];
}

- (BOOL)getFileSystemRepresentation:(char *)buffer maxLength:(NSUInteger)maxLength withPath:(NSString *)path
{
    if ([path isEqual:@""])
    {
        // it is a known iOS bug (by unit test) to not zero out the buffer (or atleast zero index 0)
        return NO;
    }

    return CFStringGetFileSystemRepresentation((CFStringRef)path, buffer, maxLength);
}

static inline NSStringEncoding defaultEncoding()
{
    static NSStringEncoding encoding = 0;
    if (encoding == 0)
    {
        encoding = CFStringConvertEncodingToNSStringEncoding(CFStringFileSystemEncoding());
    }
    return encoding;
}

- (__strong const char *)fileSystemRepresentationWithPath:(NSString *)path
{
    CFIndex maxLen = CFStringGetMaximumSizeOfFileSystemRepresentation((CFStringRef)path);
    char *buffer = malloc(maxLen);
    if (buffer == NULL)
    {
        [NSException raise:NSMallocException format:@"unable to allocate to create representation"];
        return NULL;
    }

    if ([self getFileSystemRepresentation:buffer maxLength:maxLen withPath:path])
    {
        return [[NSData dataWithBytesNoCopy:buffer length:maxLen] bytes];
    }
    else
    {
        free(buffer);
        [NSException raise:NSInvalidArgumentException format:@"unable to convert path %@", path];
        return nil;
    }

}

- (NSString *)stringWithFileSystemRepresentation:(const char *)str length:(NSUInteger)len
{
    return [[[NSString alloc] initWithBytes:str length:len encoding:defaultEncoding()] autorelease];
}

#pragma mark - Hard links, content comparison and item replacement

// Cocoa-domain error for a failed file operation. Read failures of a missing item are reported
// as NSFileReadNoSuchFileError, write-side ones as NSFileNoSuchFileError, like the path-based
// calls of the same family.
static NSError *_NSCocoaErrorForErrno(int err, NSString *path, BOOL reading)
{
    NSInteger code;
    switch (err)
    {
        case ENOENT:
            code = reading ? NSFileReadNoSuchFileError : NSFileNoSuchFileError;
            break;
        case EEXIST:
            code = NSFileWriteFileExistsError;
            break;
        case EACCES:
        case EPERM:
            code = reading ? NSFileReadNoPermissionError : NSFileWriteNoPermissionError;
            break;
        case ENOSPC:
            code = NSFileWriteOutOfSpaceError;
            break;
        case EROFS:
            code = NSFileWriteVolumeReadOnlyError;
            break;
        default:
            code = reading ? NSFileReadUnknownError : NSFileWriteUnknownError;
            break;
    }
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (path)
    {
        [info setObject:path forKey:NSFilePathErrorKey];
    }
    [info setObject:[NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil] forKey:NSUnderlyingErrorKey];
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:info];
}

- (BOOL)_linkItemAtFileSystemPath:(const char *)src toFileSystemPath:(const char *)dst failedPath:(NSString **)failed
{
    struct stat st;
    if (lstat(src, &st) != 0)
    {
        *failed = [self stringWithFileSystemRepresentation:src length:strlen(src)];
        return NO;
    }
    if (S_ISDIR(st.st_mode))
    {
        // A directory is recreated and its entries are linked one by one.
        if (mkdir(dst, st.st_mode & 07777) != 0)
        {
            *failed = [self stringWithFileSystemRepresentation:dst length:strlen(dst)];
            return NO;
        }
        DIR *dir = opendir(src);
        if (dir == NULL)
        {
            *failed = [self stringWithFileSystemRepresentation:src length:strlen(src)];
            return NO;
        }
        BOOL ok = YES;
        int savedErrno = 0;
        struct dirent *entry;
        while (ok && (entry = readdir(dir)) != NULL)
        {
            if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            {
                continue;
            }
            char childSrc[BUG_COMPLIANT_PATH_MAX], childDst[BUG_COMPLIANT_PATH_MAX];
            if (snprintf(childSrc, sizeof(childSrc), "%s/%s", src, entry->d_name) >= (int)sizeof(childSrc) ||
                snprintf(childDst, sizeof(childDst), "%s/%s", dst, entry->d_name) >= (int)sizeof(childDst))
            {
                errno = ENAMETOOLONG;
                ok = NO;
                *failed = [self stringWithFileSystemRepresentation:src length:strlen(src)];
                break;
            }
            ok = [self _linkItemAtFileSystemPath:childSrc toFileSystemPath:childDst failedPath:failed];
        }
        if (!ok)
        {
            savedErrno = errno;
        }
        closedir(dir);
        if (!ok)
        {
            errno = savedErrno;
        }
        return ok;
    }
    if (link(src, dst) != 0)
    {
        *failed = [self stringWithFileSystemRepresentation:dst length:strlen(dst)];
        return NO;
    }
    return YES;
}

- (BOOL)linkItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error
{
    if (error)
    {
        *error = nil;
    }
    if (_flags.shouldLinkItemAtPathToPath && ![_delegate fileManager:self shouldLinkItemAtPath:srcPath toPath:dstPath])
    {
        return NO;
    }
    char src[BUG_COMPLIANT_PATH_MAX], dst[BUG_COMPLIANT_PATH_MAX];
    if (![self getFileSystemRepresentation:src maxLength:sizeof(src) withPath:srcPath] ||
        ![self getFileSystemRepresentation:dst maxLength:sizeof(dst) withPath:dstPath])
    {
        if (error)
        {
            *error = _NSCocoaErrorForErrno(ENOENT, srcPath, YES);
        }
        return NO;
    }
    struct stat st;
    if (lstat(src, &st) != 0)
    {
        if (error)
        {
            *error = _NSCocoaErrorForErrno(errno, srcPath, YES);
        }
        return NO;
    }
    NSString *failedPath = nil;
    if (![self _linkItemAtFileSystemPath:src toFileSystemPath:dst failedPath:&failedPath])
    {
        if (error)
        {
            *error = _NSCocoaErrorForErrno(errno, failedPath ?: dstPath, NO);
        }
        return NO;
    }
    return YES;
}

- (BOOL)linkItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error
{
    return [self linkItemAtPath:srcURL.path toPath:dstURL.path error:error];
}

- (BOOL)createSymbolicLinkAtPath:(NSString *)path pathContent:(NSString *)otherpath
{
    return [self createSymbolicLinkAtPath:path withDestinationPath:otherpath error:NULL];
}

- (BOOL)createSymbolicLinkAtURL:(NSURL *)url withDestinationURL:(NSURL *)destURL error:(NSError **)error
{
    return [self createSymbolicLinkAtPath:url.path withDestinationPath:destURL.path error:error];
}

- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)path
{
    return [self attributesOfFileSystemForPath:path error:NULL];
}

static BOOL _NSFileContentsEqual(const char *a, const char *b);

static BOOL _NSRegularFilesEqual(const char *a, const char *b)
{
    int fa = open(a, O_RDONLY);
    int fb = open(b, O_RDONLY);
    BOOL equal = fa >= 0 && fb >= 0;
    while (equal)
    {
        char bufA[16384], bufB[16384];
        ssize_t na = read(fa, bufA, sizeof(bufA));
        if (na < 0)
        {
            equal = NO;
            break;
        }
        // Fill bufB with exactly as many bytes as bufA got, so short reads cannot cause a false mismatch.
        ssize_t got = 0;
        while (got < na)
        {
            ssize_t n = read(fb, bufB + got, (size_t)(na - got));
            if (n <= 0)
            {
                break;
            }
            got += n;
        }
        if (got != na || memcmp(bufA, bufB, (size_t)na) != 0)
        {
            equal = NO;
        }
        else if (na == 0)
        {
            break;
        }
    }
    if (fa >= 0)
    {
        close(fa);
    }
    if (fb >= 0)
    {
        close(fb);
    }
    return equal;
}

static int _NSNameCompare(const void *x, const void *y)
{
    return strcmp(*(char *const *)x, *(char *const *)y);
}

static BOOL _NSDirectoriesEqual(const char *a, const char *b)
{
    char **namesA[2] = {NULL, NULL};
    size_t count[2] = {0, 0}, capacity[2] = {0, 0};
    const char *roots[2] = {a, b};
    BOOL ok = YES;
    for (int i = 0; i < 2 && ok; i++)
    {
        DIR *dir = opendir(roots[i]);
        if (dir == NULL)
        {
            ok = NO;
            break;
        }
        struct dirent *entry;
        while ((entry = readdir(dir)) != NULL)
        {
            if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            {
                continue;
            }
            if (count[i] == capacity[i])
            {
                size_t newCapacity = capacity[i] ? capacity[i] * 2 : 32;
                char **grown = realloc(namesA[i], newCapacity * sizeof(char *));
                if (grown == NULL)
                {
                    ok = NO;
                    break;
                }
                namesA[i] = grown;
                capacity[i] = newCapacity;
            }
            char *copy = strdup(entry->d_name);
            if (copy == NULL)
            {
                ok = NO;
                break;
            }
            namesA[i][count[i]++] = copy;
        }
        closedir(dir);
    }
    if (ok && count[0] != count[1])
    {
        ok = NO;
    }
    if (ok)
    {
        qsort(namesA[0], count[0], sizeof(char *), _NSNameCompare);
        qsort(namesA[1], count[1], sizeof(char *), _NSNameCompare);
        for (size_t i = 0; ok && i < count[0]; i++)
        {
            char pa[BUG_COMPLIANT_PATH_MAX], pb[BUG_COMPLIANT_PATH_MAX];
            if (strcmp(namesA[0][i], namesA[1][i]) != 0 ||
                snprintf(pa, sizeof(pa), "%s/%s", a, namesA[0][i]) >= (int)sizeof(pa) ||
                snprintf(pb, sizeof(pb), "%s/%s", b, namesA[1][i]) >= (int)sizeof(pb))
            {
                ok = NO;
                break;
            }
            ok = _NSFileContentsEqual(pa, pb);
        }
    }
    for (int i = 0; i < 2; i++)
    {
        for (size_t j = 0; j < count[i]; j++)
        {
            free(namesA[i][j]);
        }
        free(namesA[i]);
    }
    return ok;
}

// Items are equal when they are the same file, or of the same kind with equal contents. Symbolic
// links are compared by their destination text, not by what they point at.
static BOOL _NSFileContentsEqual(const char *a, const char *b)
{
    struct stat sa, sb;
    if (lstat(a, &sa) != 0 || lstat(b, &sb) != 0)
    {
        return NO;
    }
    if (sa.st_dev == sb.st_dev && sa.st_ino == sb.st_ino)
    {
        return YES;
    }
    if ((sa.st_mode & S_IFMT) != (sb.st_mode & S_IFMT))
    {
        return NO;
    }
    if (S_ISLNK(sa.st_mode))
    {
        char la[PATH_MAX], lb[PATH_MAX];
        ssize_t na = readlink(a, la, sizeof(la));
        ssize_t nb = readlink(b, lb, sizeof(lb));
        return na >= 0 && na == nb && memcmp(la, lb, (size_t)na) == 0;
    }
    if (S_ISREG(sa.st_mode))
    {
        return sa.st_size == sb.st_size && _NSRegularFilesEqual(a, b);
    }
    if (S_ISDIR(sa.st_mode))
    {
        return _NSDirectoriesEqual(a, b);
    }
    return NO;
}

- (BOOL)contentsEqualAtPath:(NSString *)path1 andPath:(NSString *)path2
{
    char a[BUG_COMPLIANT_PATH_MAX], b[BUG_COMPLIANT_PATH_MAX];
    if (![self getFileSystemRepresentation:a maxLength:sizeof(a) withPath:path1] ||
        ![self getFileSystemRepresentation:b maxLength:sizeof(b) withPath:path2])
    {
        return NO;
    }
    return _NSFileContentsEqual(a, b);
}

- (BOOL)replaceItemAtURL:(NSURL *)originalItemURL withItemAtURL:(NSURL *)newItemURL backupItemName:(NSString *)backupItemName options:(NSFileManagerItemReplacementOptions)options resultingItemURL:(NSURL **)resultingURL error:(NSError **)error
{
    if (error)
    {
        *error = nil;
    }
    if (resultingURL)
    {
        *resultingURL = nil;
    }
    NSString *original = originalItemURL.path;
    NSString *replacement = newItemURL.path;
    struct stat st;
    BOOL originalExists = YES;
    if (lstat([original fileSystemRepresentation], &st) != 0)
    {
        // Without an original there is nothing to move aside: the new item is moved into place.
        if (errno != ENOENT)
        {
            if (error)
            {
                *error = _NSCocoaErrorForErrno(errno, original, NO);
            }
            return NO;
        }
        originalExists = NO;
    }
    if (lstat([replacement fileSystemRepresentation], &st) != 0)
    {
        // A missing new item is reported as a generic write error rather than as "no such file".
        if (error)
        {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:@{
                NSFilePathErrorKey: replacement
            }];
        }
        return NO;
    }
    if (!originalExists)
    {
        if (rename([replacement fileSystemRepresentation], [original fileSystemRepresentation]) != 0)
        {
            if (error)
            {
                *error = _NSCocoaErrorForErrno(errno, original, NO);
            }
            return NO;
        }
        if (resultingURL)
        {
            *resultingURL = originalItemURL;
        }
        return YES;
    }

    // The original is first moved aside (to the backup name, or a unique temporary one next to it),
    // then the new item takes its place; the moved-aside item is deleted unless the caller asked
    // to keep the backup.
    NSString *directory = [original stringByDeletingLastPathComponent];
    BOOL keepAside = backupItemName != nil && (options & NSFileManagerItemReplacementWithoutDeletingBackupItem);
    NSString *aside;
    if (backupItemName != nil)
    {
        aside = [directory stringByAppendingPathComponent:backupItemName];
        // A stale backup with this name is replaced.
        if (lstat([aside fileSystemRepresentation], &st) == 0)
        {
            NSError *removeError = nil;
            if (![self removeItemAtPath:aside error:&removeError])
            {
                if (error)
                {
                    *error = removeError;
                }
                return NO;
            }
        }
    }
    else
    {
        char templ[BUG_COMPLIANT_PATH_MAX];
        snprintf(templ, sizeof(templ), "%s/.replaceItem.XXXXXX", [directory fileSystemRepresentation]);
        int fd = mkstemp(templ);
        if (fd < 0)
        {
            if (error)
            {
                *error = _NSCocoaErrorForErrno(errno, directory, NO);
            }
            return NO;
        }
        close(fd);
        aside = [self stringWithFileSystemRepresentation:templ length:strlen(templ)];
        unlink(templ);
    }

    if (rename([original fileSystemRepresentation], [aside fileSystemRepresentation]) != 0)
    {
        if (error)
        {
            *error = _NSCocoaErrorForErrno(errno, original, NO);
        }
        return NO;
    }
    if (rename([replacement fileSystemRepresentation], [original fileSystemRepresentation]) != 0)
    {
        int savedErrno = errno;
        rename([aside fileSystemRepresentation], [original fileSystemRepresentation]);
        if (error)
        {
            *error = _NSCocoaErrorForErrno(savedErrno, replacement, NO);
        }
        return NO;
    }
    if (!keepAside)
    {
        [self removeItemAtPath:aside error:NULL];
    }
    if (resultingURL)
    {
        *resultingURL = originalItemURL;
    }
    return YES;
}

- (BOOL)trashItemAtURL:(NSURL *)url resultingItemURL:(NSURL **)outResultingURL error:(NSError **)error
{
    if (error)
    {
        *error = nil;
    }
    if (outResultingURL)
    {
        *outResultingURL = nil;
    }
    NSString *path = url.path;
    struct stat st;
    if (lstat([path fileSystemRepresentation], &st) != 0)
    {
        if (error)
        {
            *error = _NSCocoaErrorForErrno(errno, path, NO);
        }
        return NO;
    }
    NSString *trash = [NSHomeDirectory() stringByAppendingPathComponent:@".Trash"];
    if (mkdir([trash fileSystemRepresentation], 0700) != 0 && errno != EEXIST)
    {
        if (error)
        {
            *error = _NSCocoaErrorForErrno(errno, trash, NO);
        }
        return NO;
    }
    NSString *name = [path lastPathComponent];
    NSString *base = [name stringByDeletingPathExtension];
    NSString *extension = [name pathExtension];
    NSString *target = [trash stringByAppendingPathComponent:name];
    // An existing trashed item of the same name is kept; the new one gets a counter in its name.
    for (int n = 2; lstat([target fileSystemRepresentation], &st) == 0; n++)
    {
        NSString *candidate = extension.length ? [NSString stringWithFormat:@"%@ %d.%@", base, n, extension]
                                               : [NSString stringWithFormat:@"%@ %d", base, n];
        target = [trash stringByAppendingPathComponent:candidate];
    }
    if (rename([path fileSystemRepresentation], [target fileSystemRepresentation]) != 0)
    {
        if (error)
        {
            *error = _NSCocoaErrorForErrno(errno, path, NO);
        }
        return NO;
    }
    if (outResultingURL)
    {
        *outResultingURL = [NSURL fileURLWithPath:target];
    }
    return YES;
}

#pragma mark - iCloud (no ubiquity containers exist)

- (id <NSObject, NSCopying, NSCoding>)ubiquityIdentityToken
{
    return nil;
}

- (NSURL *)URLForUbiquityContainerIdentifier:(NSString *)containerIdentifier
{
    return nil;
}

- (BOOL)isUbiquitousItemAtURL:(NSURL *)url
{
    return NO;
}

- (BOOL)setUbiquitous:(BOOL)flag itemAtURL:(NSURL *)url destinationURL:(NSURL *)destinationURL error:(NSError **)error
{
    if (error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
    }
    return NO;
}

- (BOOL)startDownloadingUbiquitousItemAtURL:(NSURL *)url error:(NSError **)error
{
    if (error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
    }
    return NO;
}

- (BOOL)evictUbiquitousItemAtURL:(NSURL *)url error:(NSError **)error
{
    if (error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
    }
    return NO;
}

- (NSURL *)URLForPublishingUbiquitousItemAtURL:(NSURL *)url expirationDate:(NSDate **)outDate error:(NSError **)error
{
    if (outDate)
    {
        *outDate = nil;
    }
    if (error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil];
    }
    return nil;
}

@end
