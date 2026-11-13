#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@class NSNumber, NSData, NSDictionary, NSCharacterSet;

typedef NSString * NSURLResourceKey;

FOUNDATION_EXPORT NSString * const NSURLFileScheme;
FOUNDATION_EXPORT NSURLResourceKey const NSURLKeysOfUnsetValuesKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLNameKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLLocalizedNameKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsRegularFileKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsDirectoryKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsSymbolicLinkKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsVolumeKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsPackageKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsSystemImmutableKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsUserImmutableKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsHiddenKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLHasHiddenExtensionKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLCreationDateKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLContentAccessDateKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLContentModificationDateKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLAttributeModificationDateKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLLinkCountKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLParentDirectoryURLKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeURLKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLTypeIdentifierKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLContentTypeKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLLocalizedTypeDescriptionKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLLabelNumberKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLLabelColorKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLLocalizedLabelKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLEffectiveIconKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLCustomIconKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLFileResourceIdentifierKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeIdentifierKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLPreferredIOBlockSizeKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsReadableKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsWritableKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsExecutableKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLFileSecurityKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsExcludedFromBackupKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLPathKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsMountTriggerKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLFileResourceTypeKey;
FOUNDATION_EXPORT NSString * const NSURLFileResourceTypeNamedPipe;
FOUNDATION_EXPORT NSString * const NSURLFileResourceTypeCharacterSpecial;
FOUNDATION_EXPORT NSString * const NSURLFileResourceTypeDirectory;
FOUNDATION_EXPORT NSString * const NSURLFileResourceTypeBlockSpecial;
FOUNDATION_EXPORT NSString * const NSURLFileResourceTypeRegular;
FOUNDATION_EXPORT NSString * const NSURLFileResourceTypeSymbolicLink;
FOUNDATION_EXPORT NSString * const NSURLFileResourceTypeSocket;
FOUNDATION_EXPORT NSString * const NSURLFileResourceTypeUnknown;
FOUNDATION_EXPORT NSURLResourceKey const NSURLFileSizeKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLFileAllocatedSizeKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLTotalFileSizeKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLTotalFileAllocatedSizeKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsAliasFileKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeLocalizedFormatDescriptionKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeTotalCapacityKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeAvailableCapacityKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeResourceCountKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsPersistentIDsKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsSymbolicLinksKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsHardLinksKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsJournalingKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeIsJournalingKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsSparseFilesKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsZeroRunsKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsCaseSensitiveNamesKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsCasePreservedNamesKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsRootDirectoryDatesKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsVolumeSizesKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsRenamingKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsAdvisoryFileLockingKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsExtendedSecurityKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsCompressionKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsFileCloningKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsSwapRenamingKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsExclusiveRenamingKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsImmutableFilesKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsAccessPermissionsKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeSupportsFileProtectionKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeIsBrowsableKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeMaximumFileSizeKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeIsEjectableKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeIsRemovableKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeIsInternalKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeIsAutomountedKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeIsLocalKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeIsReadOnlyKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeCreationDateKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeURLForRemountingKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeUUIDStringKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeNameKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLVolumeLocalizedNameKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsUbiquitousItemKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLUbiquitousItemHasUnresolvedConflictsKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLUbiquitousItemIsDownloadedKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLUbiquitousItemIsDownloadingKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLUbiquitousItemIsUploadedKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLUbiquitousItemIsUploadingKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLUbiquitousItemPercentDownloadedKey;
FOUNDATION_EXPORT NSURLResourceKey const NSURLUbiquitousItemPercentUploadedKey;

typedef NSString* NSURLUbiquitousItemDownloadingStatus;

FOUNDATION_EXPORT NSURLUbiquitousItemDownloadingStatus const NSURLUbiquitousItemDownloadingStatusNotDownloaded;

typedef NS_OPTIONS(NSUInteger, NSURLBookmarkCreationOptions) {
    NSURLBookmarkCreationPreferFileIDResolution           = ( 1UL << 8 ),
    NSURLBookmarkCreationMinimalBookmark                  = ( 1UL << 9 ),
    NSURLBookmarkCreationSuitableForBookmarkFile          = ( 1UL << 10 ),
    NSURLBookmarkCreationWithSecurityScope                = ( 1 << 11 ),
    NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess = ( 1 << 12 ),
};

typedef NS_OPTIONS(NSUInteger, NSURLBookmarkResolutionOptions) {
    NSURLBookmarkResolutionWithoutUI         = ( 1UL << 8 ),
    NSURLBookmarkResolutionWithoutMounting   = ( 1UL << 9 ),
    NSURLBookmarkResolutionWithSecurityScope = ( 1 << 10 )
};

typedef NSUInteger NSURLBookmarkFileCreationOptions;

@interface NSURL: NSObject <NSSecureCoding, NSCopying> {
    NSString *_urlString;
    NSURL *_baseURL;
    void *_clients;
    void *_reserved;
}

+ (id)fileURLWithPath:(NSString *)path isDirectory:(BOOL) isDir;
+ (id)fileURLWithPath:(NSString *)path;
+ (id)fileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL;
+ (id)fileURLWithPath:(NSString *)path relativeToURL:(NSURL *)baseURL;
+ (id)fileURLWithFileSystemRepresentation:(const char *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL;
+ (id)URLWithString:(NSString *)URLString;
+ (id)URLWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL;
+ (id)URLByResolvingBookmarkData:(NSData *)bookmarkData options:(NSURLBookmarkResolutionOptions)options relativeToURL:(NSURL *)relativeURL bookmarkDataIsStale:(BOOL *)isStale error:(NSError **)error;
+ (NSDictionary *)resourceValuesForKeys:(NSArray *)keys fromBookmarkData:(NSData *)bookmarkData;
+ (BOOL)writeBookmarkData:(NSData *)bookmarkData toURL:(NSURL *)bookmarkFileURL options:(NSURLBookmarkFileCreationOptions)options error:(NSError **)error;
+ (NSData *)bookmarkDataWithContentsOfURL:(NSURL *)bookmarkFileURL error:(NSError **)error;
- (id)initWithScheme:(NSString *)scheme host:(NSString *)host path:(NSString *)path;
- (id)initFileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir;
- (id)initFileURLWithPath:(NSString *)path;
- (id)initFileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir relativeToURL:(NSURL *)baseURL;
- (id)initFileURLWithPath:(NSString *)path relativeToURL:(NSURL *)baseURL;
- (id)initWithString:(NSString *)URLString;
- (id)initWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL;
- (NSString *)absoluteString;
- (NSString *)relativeString;
- (NSURL *)baseURL;
- (NSURL *)absoluteURL;
- (NSString *)scheme;
- (NSString *)resourceSpecifier;
- (NSString *)host;
- (NSNumber *)port;
- (NSString *)user;
- (NSString *)password;
- (NSString *)path;
- (NSString *)fragment;
- (NSString *)parameterString;
- (NSString *)query;
- (NSString *)relativePath;
- (BOOL)getFileSystemRepresentation:(char *)buffer maxLength:(NSUInteger)maxBufferLength;
- (const char *)fileSystemRepresentation NS_RETURNS_INNER_POINTER;
- (BOOL)isFileURL;
- (NSURL *)standardizedURL;
- (BOOL)checkResourceIsReachableAndReturnError:(NSError **)error;
- (BOOL)isFileReferenceURL;
- (NSURL *)fileReferenceURL;
- (NSURL *)filePathURL;
- (BOOL)getResourceValue:(out id *)value forKey:(NSString *)key error:(out NSError **)error;
- (NSDictionary *)resourceValuesForKeys:(NSArray *)keys error:(NSError **)error;
- (BOOL)setResourceValue:(id)value forKey:(NSString *)key error:(NSError **)error;
- (BOOL)setResourceValues:(NSDictionary *)keyedValues error:(NSError **)error;
- (NSData *)bookmarkDataWithOptions:(NSURLBookmarkCreationOptions)options includingResourceValuesForKeys:(NSArray *)keys relativeToURL:(NSURL *)relativeURL error:(NSError **)error;
- (id)initByResolvingBookmarkData:(NSData *)bookmarkData options:(NSURLBookmarkResolutionOptions)options relativeToURL:(NSURL *)relativeURL bookmarkDataIsStale:(BOOL *)isStale error:(NSError **)error;
- (BOOL)startAccessingSecurityScopedResource;
- (void)stopAccessingSecurityScopedResource;

@end

@interface NSString (NSURLUtilities)

- (NSString *)stringByAddingPercentEncodingWithAllowedCharacters:(NSCharacterSet *)allowedCharacters;
- (NSString *)stringByRemovingPercentEncoding;
- (NSString *)stringByAddingPercentEscapesUsingEncoding:(NSStringEncoding)enc;
- (NSString *)stringByReplacingPercentEscapesUsingEncoding:(NSStringEncoding)enc;

@end

@interface NSURL (NSURLPathUtilities)

+ (NSURL *)fileURLWithPathComponents:(NSArray *)components;
- (NSArray *)pathComponents;
- (NSString *)lastPathComponent;
- (NSString *)pathExtension;
- (NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent;
- (NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent isDirectory:(BOOL)isDirectory;
- (NSURL *)URLByDeletingLastPathComponent;
- (NSURL *)URLByAppendingPathExtension:(NSString *)pathExtension;
- (NSURL *)URLByDeletingPathExtension;
- (NSURL *)URLByStandardizingPath;
- (NSURL *)URLByResolvingSymlinksInPath;

@end

@interface NSFileSecurity : NSObject <NSCopying, NSSecureCoding>

@end

@interface NSURLQueryItem : NSObject <NSSecureCoding, NSCopying> {
    NSString *_name;
    NSString *_value;
}

@property (readonly, copy) NSString * _Nonnull name;
@property (readonly, copy) NSString * _Nullable value;
+ (instancetype)queryItemWithName:(NSString * _Nonnull)name value:(NSString * _Nullable)value;
- (instancetype)initWithName:(NSString * _Nonnull)name value:(NSString * _Nullable)value;

@end
