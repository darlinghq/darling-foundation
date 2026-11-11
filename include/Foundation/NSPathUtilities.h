#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (NSStringPathExtensions)

+ (NSString *)pathWithComponents:(NSArray<NSString *> *)components;
@property (readonly, copy) NSArray<NSString *> *pathComponents;
@property (readonly, getter=isAbsolutePath) BOOL absolutePath;
@property (readonly, copy) NSString *lastPathComponent;
@property (readonly, copy) NSString *stringByDeletingLastPathComponent;
- (NSString *)stringByAppendingPathComponent:(NSString *)str;
@property (readonly, copy) NSString *pathExtension;
@property (readonly, copy) NSString *stringByDeletingPathExtension;
- (nullable NSString *)stringByAppendingPathExtension:(NSString *)str;
@property (readonly, copy) NSString *stringByAbbreviatingWithTildeInPath;
@property (readonly, copy) NSString *stringByExpandingTildeInPath;
@property (readonly, copy) NSString *stringByStandardizingPath;
@property (readonly, copy) NSString *stringByResolvingSymlinksInPath;
- (NSArray<NSString *> *)stringsByAppendingPaths:(NSArray<NSString *> *)paths;
- (NSUInteger)completePathIntoString:(NSString * _Nullable * _Nullable)outputName caseSensitive:(BOOL)flag matchesIntoArray:(NSArray<NSString *> * _Nullable * _Nullable)outputArray filterTypes:(nullable NSArray<NSString *> *)filterTypes;
@property (readonly) const char *fileSystemRepresentation NS_RETURNS_INNER_POINTER;
- (BOOL)getFileSystemRepresentation:(char *)cname maxLength:(NSUInteger)max;

@end

NS_ASSUME_NONNULL_END

@interface NSArray (NSArrayPathExtensions)

- (NSArray *)pathsMatchingExtensions:(NSArray *)filterTypes;

@end

FOUNDATION_EXPORT NSString *NSUserName(void);
FOUNDATION_EXPORT NSString *NSFullUserName(void);
FOUNDATION_EXPORT NSString *NSHomeDirectory(void);
FOUNDATION_EXPORT NSString *NSHomeDirectoryForUser(NSString *userName);
FOUNDATION_EXPORT NSString *NSTemporaryDirectory(void);
FOUNDATION_EXPORT NSString *NSOpenStepRootDirectory(void);

typedef NS_ENUM(NSUInteger, NSSearchPathDirectory) {
    NSApplicationDirectory = 1,
    NSDemoApplicationDirectory,
    NSDeveloperApplicationDirectory,
    NSAdminApplicationDirectory,
    NSLibraryDirectory,
    NSDeveloperDirectory,
    NSUserDirectory,
    NSDocumentationDirectory,
    NSDocumentDirectory,
    NSCoreServiceDirectory,
    NSAutosavedInformationDirectory = 11,
    NSDesktopDirectory = 12,
    NSCachesDirectory = 13,
    NSApplicationSupportDirectory = 14,
    NSDownloadsDirectory = 15,
    NSInputMethodsDirectory = 16,
    NSMoviesDirectory = 17,
    NSMusicDirectory = 18,
    NSPicturesDirectory = 19,
    NSPrinterDescriptionDirectory = 20,
    NSSharedPublicDirectory = 21,
    NSPreferencePanesDirectory = 22,
    NSApplicationScriptsDirectory = 23,
    NSItemReplacementDirectory = 99,
    NSAllApplicationsDirectory = 100,
    NSAllLibrariesDirectory = 101
};

typedef NS_OPTIONS(NSUInteger, NSSearchPathDomainMask) {
    NSUserDomainMask = 1,
    NSLocalDomainMask = 2,
    NSNetworkDomainMask = 4,
    NSSystemDomainMask = 8,
    NSAllDomainsMask = 0x0ffff
};

FOUNDATION_EXPORT NSArray *NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directory, NSSearchPathDomainMask domainMask, BOOL expandTilde);
