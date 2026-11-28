#import <Foundation/NSObject.h>

@class NSData, NSMutableDictionary, NSDictionary, NSError, NSURL;

typedef NS_OPTIONS(NSUInteger, NSFileWrapperReadingOptions) {
    NSFileWrapperReadingImmediate = 1 << 0,
    NSFileWrapperReadingWithoutMapping = 1 << 1
};

typedef NS_OPTIONS(NSUInteger, NSFileWrapperWritingOptions) {
    NSFileWrapperWritingAtomic = 1 << 0,
    NSFileWrapperWritingWithNameUpdating = 1 << 1
};

@interface NSFileWrapper : NSObject<NSCoding> {
    @protected
    NSString *_path;
    NSMutableDictionary *_fileAttributes;
    NSString *_filename;
    NSString *_preferredFilename;
    id _icon;
}

- (id)initWithURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError **)outError;
- (id)initDirectoryWithFileWrappers:(NSDictionary *)childrenByPreferredName;
- (id)initRegularFileWithContents:(NSData *)contents;
- (id)initSymbolicLinkWithDestinationURL:(NSURL *)url;
- (id)initWithSerializedRepresentation:(NSData *)serializeRepresentation;
@property (readonly, getter=isDirectory) BOOL directory;
@property (readonly, getter=isRegularFile) BOOL regularFile;
@property (readonly, getter=isSymbolicLink) BOOL symbolicLink;
@property (copy) NSString *preferredFilename;
@property (copy) NSString *filename;
@property (copy) NSDictionary *fileAttributes;
- (BOOL)matchesContentsOfURL:(NSURL *)url;
- (BOOL)readFromURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError **)outError;
- (BOOL)writeToURL:(NSURL *)url options:(NSFileWrapperWritingOptions)options originalContentsURL:(NSURL *)originalContentsURL error:(NSError **)outError;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)atomicFlag updateFilenames:(BOOL)updateFilenamesFlag NS_DEPRECATED_MAC(10_0, 10_6, "Use -writeToURL:options:originalContentsURL:error: instead");
@property (readonly, copy) NSData *serializedRepresentation;
- (NSString *)addFileWrapper:(NSFileWrapper *)child;
- (NSString *)addRegularFileWithContents:(NSData *)data preferredFilename:(NSString *)fileName;
- (void)removeFileWrapper:(NSFileWrapper *)child;
- (NSDictionary *)fileWrappers;
- (NSString *)keyForFileWrapper:(NSFileWrapper *)child NS_SWIFT_NAME(keyForChildFileWrapper(_:));
- (NSData *)regularFileContents;
- (NSURL *)symbolicLinkDestinationURL;

@end
