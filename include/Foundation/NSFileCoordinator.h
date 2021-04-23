#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSError.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSString.h>
#import <Foundation/NSFilePresenter.h>

typedef NS_OPTIONS(NSUInteger, NSFileCoordinatorReadingOptions) {
    NSFileCoordinatorReadingWithoutChanges                   = 1 << 0,
    NSFileCoordinatorReadingResolvesSymbolicLink             = 1 << 1,
    NSFileCoordinatorReadingImmediatelyAvailableMetadataOnly = 1 << 2,
    NSFileCoordinatorReadingForUploading                     = 1 << 3
};

typedef NS_OPTIONS(NSUInteger, NSFileCoordinatorWritingOptions) {
    NSFileCoordinatorWritingForDeleting                    = 1 << 0,
    NSFileCoordinatorWritingForMoving                      = 1 << 1,
    NSFileCoordinatorWritingForMerging                     = 1 << 2,
    NSFileCoordinatorWritingForReplacing                   = 1 << 3,
    NSFileCoordinatorWritingContentIndependentMetadataOnly = 1 << 4
};

@interface NSFileAccessIntent : NSObject {
    NSURL *_url;
    NSUInteger _options;
    NSString *_id;
}

@property(readonly, copy) NSURL *URL;

+ (instancetype)readingIntentWithURL:(NSURL *)url options:(NSFileCoordinatorReadingOptions)options;
+ (instancetype)writingIntentWithURL:(NSURL *)url options:(NSFileCoordinatorWritingOptions)options;

@end

@interface NSFileCoordinator : NSObject {
    NSString *_purposeIdentifier;
    NSUInteger _flags;
    NSMutableSet<NSString *> *_pendingCancellationTokens;
}

@property(class, readonly, copy) NSArray<id<NSFilePresenter>> *filePresenters;

@property(copy) NSString *purposeIdentifier;

+ (void)addFilePresenter:(id<NSFilePresenter>)filePresenter;
+ (void)removeFilePresenter:(id<NSFilePresenter>)filePresenter;

- (id)initWithFilePresenter:(id<NSFilePresenter>)filePresenterOrNil;

#if NS_BLOCKS_AVAILABLE
- (void)coordinateAccessWithIntents:(NSArray<NSFileAccessIntent *> *)intents queue:(NSOperationQueue *)queue byAccessor:(void (^)(NSError *error))accessor;
- (void)coordinateReadingItemAtURL:(NSURL *)url options:(NSFileCoordinatorReadingOptions)options error:(NSError **)outError byAccessor:(void (^)(NSURL *newURL))reader;
- (void)coordinateWritingItemAtURL:(NSURL *)url options:(NSFileCoordinatorWritingOptions)options error:(NSError **)outError byAccessor:(void (^)(NSURL *newURL))writer;
- (void)coordinateReadingItemAtURL:(NSURL *)readingURL options:(NSFileCoordinatorReadingOptions)readingOptions writingItemAtURL:(NSURL *)writingURL options:(NSFileCoordinatorWritingOptions)writingOptions error:(NSError **)outError byAccessor:(void (^)(NSURL *newReadingURL, NSURL *newWritingURL))readerWriter;
- (void)coordinateWritingItemAtURL:(NSURL *)url1 options:(NSFileCoordinatorWritingOptions)options1 writingItemAtURL:(NSURL *)url2 options:(NSFileCoordinatorWritingOptions)options2 error:(NSError **)outError byAccessor:(void (^)(NSURL *newURL1, NSURL *newURL2))writer;
- (void)prepareForReadingItemsAtURLs:(NSArray *)readingURLs options:(NSFileCoordinatorReadingOptions)readingOptions writingItemsAtURLs:(NSArray *)writingURLs options:(NSFileCoordinatorWritingOptions)writingOptions error:(NSError **)outError byAccessor:(void (^)(void (^completionHandler)(void)))batchAccessor;
#endif
- (void)itemAtURL:(NSURL *)oldURL willMoveToURL:(NSURL *)newURL;
- (void)itemAtURL:(NSURL *)oldURL didMoveToURL:(NSURL *)newURL;
- (void)itemAtURL:(NSURL *)url didChangeUbiquityAttributes:(NSSet<NSURLResourceKey> *)attributes;
- (void)cancel;

@end
