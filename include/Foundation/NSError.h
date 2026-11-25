#import <Foundation/NSObject.h>

@class NSDictionary, NSArray<ObjectType>;

typedef NSString *NSErrorDomain;

FOUNDATION_EXPORT NSString *const NSCocoaErrorDomain;
FOUNDATION_EXPORT NSString *const NSPOSIXErrorDomain;
FOUNDATION_EXPORT NSString *const NSOSStatusErrorDomain;
FOUNDATION_EXPORT NSString *const NSMachErrorDomain;
FOUNDATION_EXPORT NSString *const NSUnderlyingErrorKey;
FOUNDATION_EXPORT NSString *const NSLocalizedDescriptionKey;
FOUNDATION_EXPORT NSString *const NSLocalizedFailureReasonErrorKey;
FOUNDATION_EXPORT NSString *const NSLocalizedRecoverySuggestionErrorKey;
FOUNDATION_EXPORT NSString *const NSLocalizedRecoveryOptionsErrorKey;
FOUNDATION_EXPORT NSString *const NSRecoveryAttempterErrorKey;
FOUNDATION_EXPORT NSString *const NSHelpAnchorErrorKey;
FOUNDATION_EXPORT NSString *const NSStringEncodingErrorKey;
FOUNDATION_EXPORT NSString *const NSURLErrorKey;
FOUNDATION_EXPORT NSString *const NSFilePathErrorKey;
FOUNDATION_EXPORT NSString *const NSDebugDescriptionErrorKey;
FOUNDATION_EXPORT NSString *const NSLocalizedFailureErrorKey;
// Value: an NSArray of NSError, the errors behind this one (macOS 11.3).
FOUNDATION_EXPORT NSString *const NSMultipleUnderlyingErrorsKey;

typedef NSString *NSErrorUserInfoKey;

@interface NSError : NSObject <NSCopying, NSSecureCoding> {
// NOTE: This is brittle - the ivar layout MUST be the same as CFErrorRef
    void *_reserved;
    NSUInteger _code;
    NSString *_domain;
    NSDictionary *_userInfo;
}

+ (instancetype)errorWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict;
- (instancetype)initWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)dict;
- (NSString *)domain;
- (NSInteger)code;
- (NSDictionary *)userInfo;
- (NSString *)localizedDescription;
- (NSString *)localizedFailureReason;
- (NSString *)localizedRecoverySuggestion;
- (NSArray *)localizedRecoveryOptions;
- (id)recoveryAttempter;
- (NSString *)helpAnchor;

// A block that gives the value of a user info key that an error of the domain
// lacks; the accessors above, and the descriptions, ask it
// (https://developer.apple.com/documentation/foundation/nserror/setuserinfovalueproviderfordomain(_:provider:)).
+ (void)setUserInfoValueProviderForDomain:(NSString *)errorDomain provider:(id (^)(NSError *err, NSString *userInfoKey))provider;
+ (id (^)(NSError *err, NSString *userInfoKey))userInfoValueProviderForDomain:(NSString *)errorDomain;

// The error under NSUnderlyingErrorKey, then those under
// NSMultipleUnderlyingErrorsKey (macOS 11.3); an empty array if there are none.
@property (readonly, copy) NSArray<NSError *> *underlyingErrors;

@end

@interface NSObject(NSErrorRecoveryAttempting)

- (void)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex delegate:(id)delegate didRecoverSelector:(SEL)didRecoverSelector contextInfo:(void *)contextInfo;
- (BOOL)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex;

@end
