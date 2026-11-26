#import <Foundation/NSObject.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSPathUtilities.h>
#import <CoreFoundation/CFBase.h>

#define NSFoundationVersionWithFileManagerResourceForkSupport 412

typedef NS_OPTIONS(NSUInteger, NSVolumeEnumerationOptions) {
    NSVolumeEnumerationSkipHiddenVolumes        = 1UL << 1,
    NSVolumeEnumerationProduceFileReferenceURLs = 1UL << 2
};

typedef NS_OPTIONS(NSUInteger, NSDirectoryEnumerationOptions) {
    NSDirectoryEnumerationSkipsSubdirectoryDescendants = 1UL << 0,
    NSDirectoryEnumerationSkipsPackageDescendants      = 1UL << 1,
    NSDirectoryEnumerationSkipsHiddenFiles             = 1UL << 2
};

typedef NS_OPTIONS(NSUInteger, NSFileManagerItemReplacementOptions) {
    NSFileManagerItemReplacementUsingNewMetadataOnly = 1UL << 0,
    NSFileManagerItemReplacementWithoutDeletingBackupItem = 1UL << 1
};

// The keys of a file's attributes, the types of file, and the protection a file has.
typedef NSString *NSFileAttributeKey NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString *NSFileAttributeType NS_TYPED_ENUM;
typedef NSString *NSFileProtectionType NS_TYPED_ENUM;

FOUNDATION_EXPORT NSString * const NSUbiquityIdentityDidChangeNotification;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileType;
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeDirectory;
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeRegular;
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeSymbolicLink;
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeSocket;
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeCharacterSpecial;
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeBlockSpecial;
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeUnknown;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSize;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileModificationDate;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileReferenceCount;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileDeviceIdentifier;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileOwnerAccountName;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileGroupOwnerAccountName;
FOUNDATION_EXPORT NSFileAttributeKey const NSFilePosixPermissions;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemNumber;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemFileNumber;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileExtensionHidden;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileHFSCreatorCode;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileHFSTypeCode;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileImmutable;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileAppendOnly;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileCreationDate;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileOwnerAccountID;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileGroupOwnerAccountID;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileBusy;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileProtectionKey;
FOUNDATION_EXPORT NSFileProtectionType const NSFileProtectionNone;
FOUNDATION_EXPORT NSFileProtectionType const NSFileProtectionComplete;
FOUNDATION_EXPORT NSFileProtectionType const NSFileProtectionCompleteUnlessOpen;
FOUNDATION_EXPORT NSFileProtectionType const NSFileProtectionCompleteUntilFirstUserAuthentication;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemSize;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemFreeSize;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemNodes;
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemFreeNodes;

@class NSArray, NSData, NSDate, NSDirectoryEnumerator, NSError, NSNumber, NSFileManager;

@protocol NSFileManagerDelegate <NSObject>
@optional

- (BOOL)fileManager:(NSFileManager *)fileManager shouldCopyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldCopyItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error copyingItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error copyingItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldMoveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldMoveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error movingItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error movingItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldLinkItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldLinkItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error linkingItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error linkingItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldRemoveItemAtPath:(NSString *)path;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldRemoveItemAtURL:(NSURL *)URL;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error removingItemAtPath:(NSString *)path;
- (BOOL)fileManager:(NSFileManager *)fileManager shouldProceedAfterError:(NSError *)error removingItemAtURL:(NSURL *)URL;

@end

@interface NSFileManager : NSObject
{
    id _delegate;
    struct {
        int shouldCopyItemAtPathToPath:1;
        int shouldCopyItemAtURLToURL:1;
        int shouldProceedAfterErrorCopyingItemAtPathToPath:1;
        int shouldProceedAfterErrorCopyingItemAtURLToURL:1;
        int shouldMoveItemAtPathToPath:1;
        int shouldMoveItemAtURLToURL:1;
        int shouldProceedAfterErrorMovingItemAtPathToPath:1;
        int shouldProceedAfterErrorMovingItemAtURLToURL:1;
        int shouldLinkItemAtPathToPath:1;
        int shouldLinkItemAtURLToURL:1;
        int shouldProceedAfterErrorLinkingItemAtPathToPath:1;
        int shouldProceedAfterErrorLinkingItemAtURLToURL:1;
        int shouldRemoveItemAtPath:1;
        int shouldRemoveItemAtURL:1;
        int shouldProceedAfterErrorRemovingItemAtPath:1;
        int shouldProceedAfterErrorRemovingItemAtURL:1;
    } _flags;
}

@property (class, readonly, retain) NSFileManager * _Nonnull defaultManager;
@property (readonly) NSURL *temporaryDirectory;
- (NSArray *)mountedVolumeURLsIncludingResourceValuesForKeys:(NSArray *)propertyKeys options:(NSVolumeEnumerationOptions)options;
- (NSArray *)contentsOfDirectoryAtURL:(NSURL *)url includingPropertiesForKeys:(NSArray *)keys options:(NSDirectoryEnumerationOptions)mask error:(NSError **)error;
- (NSArray *)URLsForDirectory:(NSSearchPathDirectory)directory inDomains:(NSSearchPathDomainMask)domainMask;
- (NSURL *)URLForDirectory:(NSSearchPathDirectory)directory inDomain:(NSSearchPathDomainMask)domain appropriateForURL:(NSURL *)url create:(BOOL)shouldCreate error:(NSError **)error;
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier;
- (BOOL)createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
- (BOOL)createSymbolicLinkAtURL:(NSURL *)url withDestinationURL:(NSURL *)destURL error:(NSError **)error;
@property (weak) id delegate;
- (BOOL)setAttributes:(NSDictionary *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error;
- (NSArray *)subpathsOfDirectoryAtPath:(NSString *)path error:(NSError **)error;
- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error;
- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error;
- (BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError **)error;
- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
- (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
- (BOOL)linkItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)copyItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error;
- (BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error;
- (BOOL)linkItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error;
- (BOOL)removeItemAtURL:(NSURL *)URL error:(NSError **)error;
- (BOOL)trashItemAtURL:(NSURL *)url resultingItemURL:(NSURL **)outResultingURL error:(NSError **)error;
- (NSDictionary *)fileAttributesAtPath:(NSString *)path traverseLink:(BOOL)yorn;
- (BOOL)changeFileAttributes:(NSDictionary *)attributes atPath:(NSString *)path;
- (NSArray *)directoryContentsAtPath:(NSString *)path;
- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)path;
- (NSString *)pathContentOfSymbolicLinkAtPath:(NSString *)path;
- (BOOL)createSymbolicLinkAtPath:(NSString *)path pathContent:(NSString *)otherpath;
- (BOOL)createDirectoryAtPath:(NSString *)path attributes:(NSDictionary *)attributes;
- (BOOL)copyPath:(NSString *)src toPath:(NSString *)dest handler:(id)handler;
- (NSString *)currentDirectoryPath;
- (BOOL)changeCurrentDirectoryPath:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory;
- (BOOL)isReadableFileAtPath:(NSString *)path;
- (BOOL)isWritableFileAtPath:(NSString *)path;
- (BOOL)isExecutableFileAtPath:(NSString *)path;
- (BOOL)isDeletableFileAtPath:(NSString *)path;
- (BOOL)contentsEqualAtPath:(NSString *)path1 andPath:(NSString *)path2;
- (NSString *)displayNameAtPath:(NSString *)path;
- (NSArray *)componentsToDisplayForPath:(NSString *)path;
- (NSDirectoryEnumerator *)enumeratorAtPath:(NSString *)path;
#if NS_BLOCKS_AVAILABLE
- (NSDirectoryEnumerator *)enumeratorAtURL:(NSURL *)url includingPropertiesForKeys:(NSArray *)keys options:(NSDirectoryEnumerationOptions)mask errorHandler:(BOOL (^)(NSURL *url, NSError *error))handler;
#endif
- (NSArray *)subpathsAtPath:(NSString *)path;
- (NSData *)contentsAtPath:(NSString *)path;
- (BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data attributes:(NSDictionary *)attr;
- (const char *)fileSystemRepresentationWithPath:(NSString *)path NS_RETURNS_INNER_POINTER;
- (NSString *)stringWithFileSystemRepresentation:(const char *)str length:(NSUInteger)len;
- (BOOL)replaceItemAtURL:(NSURL *)originalItemURL withItemAtURL:(NSURL *)newItemURL backupItemName:(NSString *)backupItemName options:(NSFileManagerItemReplacementOptions)options resultingItemURL:(NSURL **)resultingURL error:(NSError **)error;
- (BOOL)setUbiquitous:(BOOL)flag itemAtURL:(NSURL *)url destinationURL:(NSURL *)destinationURL error:(NSError **)error;
- (BOOL)isUbiquitousItemAtURL:(NSURL *)url;
- (BOOL)startDownloadingUbiquitousItemAtURL:(NSURL *)url error:(NSError **)error;
- (BOOL)evictUbiquitousItemAtURL:(NSURL *)url error:(NSError **)error;
- (NSURL *)URLForUbiquityContainerIdentifier:(NSString *)containerIdentifier;
- (NSURL *)URLForPublishingUbiquitousItemAtURL:(NSURL *)url expirationDate:(NSDate **)outDate error:(NSError **)error;
- (id <NSObject, NSCopying, NSCoding>)ubiquityIdentityToken;

@end

@interface NSObject (NSCopyLinkMoveHandler)
- (BOOL)fileManager:(NSFileManager *)fm shouldProceedAfterError:(NSDictionary *)errorInfo;
- (void)fileManager:(NSFileManager *)fm willProcessPath:(NSString *)path;
@end

@interface NSDirectoryEnumerator : NSEnumerator

- (NSDictionary *)fileAttributes;
- (NSDictionary *)directoryAttributes;
- (void)skipDescendents;
- (NSUInteger)level;
- (void)skipDescendants;

@end

@interface NSDictionary (NSFileAttributes)

- (unsigned long long)fileSize;
- (NSDate *)fileModificationDate;
- (NSString *)fileType;
- (NSUInteger)filePosixPermissions;
- (NSString *)fileOwnerAccountName;
- (NSString *)fileGroupOwnerAccountName;
- (NSInteger)fileSystemNumber;
- (NSUInteger)fileSystemFileNumber;
- (BOOL)fileExtensionHidden;
- (OSType)fileHFSCreatorCode;
- (OSType)fileHFSTypeCode;
- (BOOL)fileIsImmutable;
- (BOOL)fileIsAppendOnly;
- (NSDate *)fileCreationDate;
- (NSNumber *)fileOwnerAccountID;
- (NSNumber *)fileGroupOwnerAccountID;

@end
