#import <Foundation/Foundation.h>

#if __OBJC2__

NS_ASSUME_NONNULL_BEGIN

typedef void (^NSItemProviderCompletionHandler)(__nullable id <NSSecureCoding> item, NSError * __null_unspecified error);
typedef void (^NSItemProviderLoadHandler)(__null_unspecified NSItemProviderCompletionHandler completionHandler, __null_unspecified Class expectedValueClass, NSDictionary * __null_unspecified options);

NS_CLASS_AVAILABLE(10_10, 8_0)
@interface NSItemProvider : NSObject <NSCopying>

- (instancetype)initWithItem:(nullable id <NSSecureCoding>)item typeIdentifier:(nullable NSString *)typeIdentifier NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithContentsOfURL:(null_unspecified NSURL *)fileURL;

- (void)registerItemForTypeIdentifier:(NSString *)typeIdentifier loadHandler:(NSItemProviderLoadHandler)loadHandler;

@property(copy, readonly, NS_NONATOMIC_IOSONLY) NSArray *registeredTypeIdentifiers;

- (BOOL)hasItemConformingToTypeIdentifier:(NSString *)typeIdentifier;

- (void)loadItemForTypeIdentifier:(NSString *)typeIdentifier options:(nullable NSDictionary *)options completionHandler:(nullable NSItemProviderCompletionHandler)completionHandler;

@end

FOUNDATION_EXTERN NSString * __null_unspecified const NSItemProviderPreferredImageSizeKey NS_AVAILABLE(10_10, 8_0);

@interface NSItemProvider(NSPreviewSupport)

@property(nullable, copy, NS_NONATOMIC_IOSONLY) NSItemProviderLoadHandler previewImageHandler NS_AVAILABLE(10_10, 8_0);

- (void)loadPreviewImageWithOptions:(null_unspecified NSDictionary *)options completionHandler:(null_unspecified NSItemProviderCompletionHandler)completionHandler NS_AVAILABLE(10_10, 8_0);

@end

FOUNDATION_EXTERN NSString * __null_unspecified const NSExtensionJavaScriptPreprocessingResultsKey NS_AVAILABLE(10_10, 8_0);

FOUNDATION_EXTERN NSString * __null_unspecified const NSExtensionJavaScriptFinalizeArgumentKey NS_AVAILABLE_IOS(8_0);

FOUNDATION_EXTERN NSString * __null_unspecified const NSItemProviderErrorDomain NS_AVAILABLE(10_10, 8_0);

typedef NS_ENUM(NSInteger, NSItemProviderErrorCode) {
    NSItemProviderUnknownError                                      = -1,
    NSItemProviderItemUnavailableError                              = -1000,
    NSItemProviderUnexpectedValueClassError                         = -1100,
    NSItemProviderUnavailableCoercionError NS_AVAILABLE(10_11, 9_0) = -1200
} NS_ENUM_AVAILABLE(10_10, 8_0);

NS_ASSUME_NONNULL_END

#endif

