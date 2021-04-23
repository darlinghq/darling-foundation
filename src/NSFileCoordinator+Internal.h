#import <Foundation/NSFileCoordinator.h>
#include <stdint.h>
#include <xpc/xpc.h>

#define DAEMON_SERVICE_NAME "com.apple.FileCoordination"

//
// daemon message types
//

typedef NS_ENUM(uint64_t, DaemonMessageType) {
	// dummy type just to make default return value of `xpc_uint64_get_value` an invalid type
	DaemonMessageTypeInvalid = 0,

	// client to server -- a request to gain access to the given file
	DaemonMessageTypeIntent,

	// server to client -- a response to the client's earlier `DaemonMessageTypeIntent` message
	DaemonMessageTypeIntentReply,

	// client to server -- a notification that the client has completed their operation on the file
	DaemonMessageTypeIntentCompletion,

	// server to client -- an acknowledgement of the client's earlier `DaemonMessageTypeIntentCompletion` message
	DaemonMessageTypeIntentCompletionReply,

	// client to server -- a notification to the server about an action that occured with the given file
	DaemonMessageTypeNotification,

	// server to client -- an acknowledgement of the client's earlier `DaemonMessageTypeNotification` message
	DaemonMessageTypeNotificationReply,

	// client to server -- a request to cancel a pending file access
	DaemonMessageTypeCancellation,

	// server to client -- a notification to all the presenters in the client that someone wants to use the given file
	DaemonMessageTypePresenterNotification,

	// client to server -- a notification to the server informing it on what the presenters in this client said about the file
	DaemonMessageTypePresenterReply,

	// also an invalid type; indicates the end of valid types
	DaemonMessageTypeLAST,
};

//
// daemon intent options
//
typedef NS_OPTIONS(NSUInteger, DaemonIntentOperationKind) {
	DaemonIntentOperationKindReading = 1 << 0,
	DaemonIntentOperationKindWriting = 1 << 1,
};

#define DaemonIntentOperationKindMask (DaemonIntentOperationKindReading | DaemonIntentOperationKindWriting)
#define DaemonIntentReadingOptionMask ((\
		NSFileCoordinatorReadingWithoutChanges |\
		NSFileCoordinatorReadingResolvesSymbolicLink |\
		NSFileCoordinatorReadingImmediatelyAvailableMetadataOnly |\
		NSFileCoordinatorReadingForUploading \
	) << 2)
#define DaemonIntentWritingOptionMask ((\
		NSFileCoordinatorWritingForDeleting |\
		NSFileCoordinatorWritingForMoving |\
		NSFileCoordinatorWritingForMerging |\
		NSFileCoordinatorWritingForReplacing |\
		NSFileCoordinatorWritingContentIndependentMetadataOnly \
	) << 2)
#define DaemonIntentOptionsMask (DaemonIntentOperationKindMask | DaemonIntentReadingOptionMask | DaemonIntentWritingOptionMask)

//
// daemon notification types
//

typedef NS_ENUM(uint64_t, DaemonNotificationType) {
	DaemonNotificationTypeInvalid = 0,
	DaemonNotificationTypeWillMoveToURL,
	DaemonNotificationTypeDidMoveToURL,
	DaemonNotificationTypeDidChangeUbiquityAttributes,
	DaemonNotificationTypeLAST,
};

//
// daemon presenter notification types
//
// these are used by both the server-to-client notification and the client-to-server response
//
typedef NS_ENUM(uint64_t, DaemonPresenterNotificationItemType) {
	DaemonPresenterNotificationItemTypeInvalid = 0,
	DaemonPresenterNotificationItemTypeRelinquishToReader,
	DaemonPresenterNotificationItemTypeRelinquishToWriter,
	DaemonPresenterNotificationItemTypeReacquireAccess,
	DaemonPresenterNotificationItemTypeSave,
	DaemonPresenterNotificationItemTypePrepareForDeletion,
	DaemonPresenterNotificationItemTypeDidMove,
	DaemonPresenterNotificationItemTypeDidChange,
	DaemonPresenterNotificationItemTypeDidGainVersion,
	DaemonPresenterNotificationItemTypeDidLoseVersion,
	DaemonPresenterNotificationItemTypeDidResolveVersionConflict,
	DaemonPresenterNotificationItemTypeDidChangeUbiquity,
	DaemonPresenterNotificationItemTypeNewChildDidAppear,
	DaemonPresenterNotificationItemTypeLAST,
};

//
// daemon presenter reply results
//
typedef NS_ENUM(uint64_t, DaemonPresenterReplyItemResult) {
	DaemonPresenterReplyItemResultInvalid = 0,
	DaemonPresenterReplyItemResultOk,
	DaemonPresenterReplyItemResultError,
	DaemonPresenterReplyItemResultLAST,
};

//
// daemon intent reply results
//
typedef NS_ENUM(uint64_t, DaemonIntentReplyResult) {
	DaemonIntentReplyResultInvalid = 0,
	DaemonIntentReplyResultOk,
	DaemonIntentReplyResultError,
	DaemonIntentReplyResultLAST,
};

//
// daemon message keys
//

#define DaemonMessageTypeKey "type"

#define DaemonIntentPathKey "path"
#define DaemonIntentOptionsKey "options"
#define DaemonIntentCancellationTokenKey "cancellation-token"
#define DaemonIntentPurposeIdentifierKey "purpose-identifier"

#define DaemonIntentReplyResultKey "result"

#define DaemonNotificationTypeKey "notification-type"
#define DaemonNotificationPathKey "path"
#define DaemonNotificationDetailsKey "details"
#define DaemonNotificationDetailsNewPathKey "new-path"
#define DaemonNotificationDetailsChangedAttributesKey "changed-attributes"

#define DaemonCancellationCancellationTokenKey "cancellation-token"

#define DaemonPresenterNotificationArrayKey "notifications"
#define DaemonPresenterNotificationItemTypeKey "notification-type"
#define DaemonPresenterNotificationItemPathKey "path"

#define DaemonPresenterReplyArrayKey "responses"
#define DaemonPresenterReplyItemTypeKey "notification-type"
#define DaemonPresenterReplyItemResultKey "result"

//
// other typedefs
//

typedef NSString NSFileAccessCancellationToken;

typedef NS_OPTIONS(NSUInteger, NSFileCoordinatorFlags) {
	NSFileCoordinatorPurposeIdentifierAlreadyAssigned = 1 << 0,
};

//
// NSFileAccessIntent internal
//

@interface NSFileAccessIntent (Internal)

@property() NSUInteger options;
@property(copy) NSString* identifier;

- (instancetype)initWithURL: (NSURL*)url andOptions: (NSUInteger)options;

@end

//
// NSFileCoordinator internal
//

typedef void (^NSFileAccessIntentBlock)(NSError* error);

@interface NSFileCoordinator (Internal)

/**
 * Submits a file access intent to the daemon.
 * If `queue` is `nil`, the entire operation executes synchronously.
 * Otherwise, the operation executes asynchronously and the queue is used to execute the block when access is acquired.
 *
 * Returns a token that can be submitted later to cancel the file access. The token is autoreleased on return.
 */
- (NSFileAccessCancellationToken*)submitIntent: (NSFileAccessIntent*)intent onQueue: (NSOperationQueue*)queue withBlock: (NSFileAccessIntentBlock)block;

/**
 * Submits a notification to the daemon, asychronously.
 *
 * `notificationDetails` should be a dictionary containing the information to submit along with the notification, if any.
 */
- (void)submitNotificationForURL: (NSURL*)url ofType: (DaemonNotificationType)type withDetails: (xpc_object_t)notificationDetails;

- (void)submitCancellationWithToken: (NSFileAccessCancellationToken*)cancellationToken;

@end
