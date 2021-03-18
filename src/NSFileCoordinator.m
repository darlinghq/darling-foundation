//
//  NSFileCoordinator.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSFileCoordinator+Internal.h"
#import <Foundation/NSFilePresenter.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSRaise.h>
#import <Foundation/NSMutableSet.h>
#import <Foundation/NSString.h>
#import <Foundation/NSUUID.h>
#import <Foundation/NSFileManager.h>

#import <objc/runtime.h>

#include <xpc/xpc.h>
#include <stdatomic.h>
#include <dispatch/dispatch.h>
#include <stdlib.h>

// threading behavior around NSFileCoordinator is a little unclear
// TODO: check if we're doing it correctly

// ugly hack to prevent the compiler from interpreting XPC objects as Objective-C objects
// because our libxpc currently defines them in plain C
typedef void* block_safe_xpc_object_t;

//
// logging and debugging function adapted from the file coordination daemon
//

static void _FCLog(const char* file, size_t line, NSString* format, ...);
static void _FCLogv(const char* file, size_t line, NSString* format, va_list args);
static BOOL _FCDebugLogEnabled(void);

#define FCLog(...) do {\
		_FCLog(__FILE__, __LINE__, ## __VA_ARGS__); \
	} while (0);

#define FCLogv(...) do {\
		_FCLogv(__FILE__, __LINE__, ## __VA_ARGS__); \
	} while (0);

#define FCDebug(...) do { \
		if (_FCDebugLogEnabled()) FCLog(__VA_ARGS__); \
	} while (0);

static void _FCLog(const char* file, size_t line, NSString* format, ...) {
	va_list args;
	va_start(args, format);
	_FCLogv(file, line, format, args);
	va_end(args);
};

static void _FCLogv(const char* file, size_t line, NSString* format, va_list args) {
	// just defer to `NSLogv` for now
	NSLogv([NSString stringWithFormat: @"%s:%zu: %@", file, line, format], args);
};

static BOOL _FCDebugLogEnabled(void) {
	static BOOL enabled = NO;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		const char* envVar = getenv("FC_DEBUG");
		if (envVar != NULL) {
			enabled = [NSString stringWithUTF8String: envVar].boolValue;
		}
	});

	return enabled;
};

// returns the description of the object as an autoreleased NSString
static NSString* xpc_nsdescription(xpc_object_t object) {
	char* desc = xpc_copy_description(object);
	NSString* nsdesc = [NSString stringWithUTF8String: desc];
	free(desc);
	return nsdesc;
};

//
// end of logging and debugging functions
//

static const char kFilePresenterAssociatedPurposeIdentifierKey = 0;
static const char kFilePresenterAssociatedCompletionHandlerKey = 0;
static NSMutableDictionary<NSString*, NSMutableSet<id<NSFilePresenter>>*>* filePresentersByPath = nil;
static xpc_connection_t daemonConnection = NULL;
static dispatch_queue_t notificationQueue = NULL;
static dispatch_queue_t replyQueue = NULL;

static void handle_xpc_error(xpc_object_t error) {
	// do nothing with it for now
};

static SEL presenterNotificationTypeToSelector(DaemonPresenterNotificationItemType notificationType, BOOL forParent) {
	SEL theSelector = 0;

	switch (notificationType) {
		case DaemonPresenterNotificationItemTypeRelinquishToReader: {
			theSelector = @selector(relinquishPresentedItemToReader:);
		} break;
		case DaemonPresenterNotificationItemTypeRelinquishToWriter: {
			theSelector = @selector(relinquishPresentedItemToWriter:);
		} break;
		/*case DaemonPresenterNotificationItemTypeReacquireAccess:*/ // not missing; doesn't correspond to protocol method
		case DaemonPresenterNotificationItemTypeSave: {
			theSelector = @selector(savePresentedItemChangesWithCompletionHandler:);
		} break;
		case DaemonPresenterNotificationItemTypePrepareForDeletion: {
			theSelector = forParent ? @selector(accommodatePresentedSubitemDeletionAtURL:completionHandler:) : @selector(accommodatePresentedItemDeletionWithCompletionHandler:);
		} break;
		case DaemonPresenterNotificationItemTypeDidMove: {
			theSelector = forParent ? @selector(presentedSubitemAtURL:didMoveToURL:) : @selector(presentedItemDidMoveToURL:);
		} break;
		case DaemonPresenterNotificationItemTypeDidChange: {
			theSelector = forParent ? @selector(presentedSubitemDidChangeAtURL:) : @selector(presentedItemDidChange);
		} break;
		case DaemonPresenterNotificationItemTypeDidGainVersion: {
			theSelector = forParent ? @selector(presentedSubitemAtURL:didGainVersion:) : @selector(presentedItemDidGainVersion:);
		} break;
		case DaemonPresenterNotificationItemTypeDidLoseVersion: {
			theSelector = forParent ? @selector(presentedSubitemAtURL:didLoseVersion:) : @selector(presentedItemDidLoseVersion:);
		} break;
		case DaemonPresenterNotificationItemTypeDidResolveVersionConflict: {
			theSelector = forParent ? @selector(presentedSubitemAtURL:didResolveConflictVersion:) : @selector(presentedItemDidResolveConflictVersion:);
		} break;
		case DaemonPresenterNotificationItemTypeDidChangeUbiquity: {
			theSelector = @selector(presentedItemDidChangeUbiquityAttributes:);
		} break;
		case DaemonPresenterNotificationItemTypeNewChildDidAppear: {
			theSelector = @selector(presentedSubitemDidAppearAtURL:);
		} break;
	}

	return theSelector;
};

// TODO: we need to notify parents as well
static void handle_xpc_notification(xpc_object_t message) {
	FCDebug(@"Recieved notification: %@", xpc_nsdescription(message));

	xpc_object_t notifications = xpc_dictionary_get_value(message, DaemonPresenterNotificationArrayKey);
	block_safe_xpc_object_t reply = xpc_dictionary_create_reply(message);
	block_safe_xpc_object_t responseArray = xpc_array_create(NULL, 0);
	size_t notificationCount = xpc_array_get_count(notifications);
	__block _Atomic size_t completedNotifications = 0;

	block_safe_xpc_object_t _daemonConnection = daemonConnection;
	void (^singleNotificationDelivered)(void) = [[^{
		FCDebug(@"single notification was delivered");
		if (atomic_fetch_add(&completedNotifications, 1) + 1 >= notificationCount) {
			FCDebug(@"all notifications have been delivered; replying to daemon now with message: %@", xpc_nsdescription(reply));
			xpc_connection_send_message(_daemonConnection, reply);
			xpc_release(reply);
		}
	} copy] autorelease];

	xpc_dictionary_set_value(reply, DaemonPresenterReplyArrayKey, responseArray);
	xpc_release(responseArray);

	xpc_dictionary_set_uint64(reply, DaemonMessageTypeKey, DaemonMessageTypePresenterReply);

	if (notificationCount == 0) {
		FCDebug(@"no notifications to deliver");
		singleNotificationDelivered();
	}

	xpc_array_apply(notifications, ^bool (size_t index, xpc_object_t notification) {
		DaemonPresenterNotificationItemType itemType = xpc_dictionary_get_uint64(notification, DaemonPresenterNotificationItemTypeKey);
		NSString* path = [NSString stringWithUTF8String: xpc_dictionary_get_string(notification, DaemonPresenterNotificationItemPathKey)];
		block_safe_xpc_object_t response = xpc_dictionary_create(NULL, NULL, 0);
		NSMutableSet<id<NSFilePresenter>>* mutablePresentersForPath = nil;
		NSSet<id<NSFilePresenter>>* presentersForPath = nil;
		NSUInteger presenterCount = 0;
		__block _Atomic NSUInteger presentersNotified = 0;
		SEL notificationSelector = presenterNotificationTypeToSelector(itemType, NO);

		FCDebug(@"processing notification with type %llu and selector %@", itemType, NSStringFromSelector(notificationSelector));

		@synchronized(filePresentersByPath) {
			mutablePresentersForPath = filePresentersByPath[path];
		}

		if (mutablePresentersForPath != nil) {
			@synchronized(mutablePresentersForPath) {
				presentersForPath = [NSSet setWithSet: mutablePresentersForPath];
			}
			presenterCount = [presentersForPath count];
		}

		FCDebug(@"notifying %zu presenters", presenterCount);

		xpc_dictionary_set_uint64(response, DaemonPresenterReplyItemTypeKey, itemType);
		xpc_dictionary_set_uint64(response, DaemonPresenterReplyItemResultKey, DaemonIntentReplyResultOk); // by default, report success
		xpc_array_append_value(responseArray, response);
		xpc_release(response);

		void (^singlePresenterFinished)(void) = [[^{
			FCDebug(@"single presenter finished");
			if (atomic_fetch_add(&presentersNotified, 1) + 1 >= presenterCount) {
				singleNotificationDelivered();
			}
		} copy] autorelease];

		if (presenterCount == 0) {
			singlePresenterFinished();
		}

		for (id<NSFilePresenter> presenter in presentersForPath) {
			NSOperation* operation = nil;

			switch (itemType) {
				case DaemonPresenterNotificationItemTypeRelinquishToReader: /* fallthrough */
				case DaemonPresenterNotificationItemTypeRelinquishToWriter: {
					void (^relinquished)(void (^)(void)) = [[^(void (^reacquirer)(void)) {
						if (reacquirer != nil) {
							FCDebug(@"saving reacquirer block %p for presenter %p", (void*)reacquirer, (void*)presenter);
							objc_setAssociatedObject(presenter, &kFilePresenterAssociatedCompletionHandlerKey, reacquirer, OBJC_ASSOCIATION_COPY);
						}
						singlePresenterFinished();
					} copy] autorelease];
					operation = [[[NSInvocationOperation alloc] initWithTarget: presenter selector: notificationSelector object: relinquished] autorelease];
				} break;

				case DaemonPresenterNotificationItemTypeReacquireAccess: {
					void (^reacquirer)(void) = objc_getAssociatedObject(presenter, &kFilePresenterAssociatedCompletionHandlerKey);
					if (reacquirer != nil) {
						FCDebug(@"invoking reacquirer block %p for presenter %p", (void*)reacquirer, (void*)presenter);
						operation = [NSBlockOperation blockOperationWithBlock: reacquirer];
						operation.completionBlock = singlePresenterFinished;
					}
				} break;

				case DaemonPresenterNotificationItemTypeSave: /* fallthrough */
				case DaemonPresenterNotificationItemTypePrepareForDeletion: {
					void (^completed)(NSError*) = [[^(NSError* error) {
						if (error != nil) {
							FCDebug(@"presenter returned an error; marking notification failure and continuing");
							xpc_dictionary_set_uint64(response, DaemonPresenterReplyItemResultKey, DaemonIntentReplyResultError);
							// TODO: maybe add some extra information about why we failed
						}
						singlePresenterFinished();
					} copy] autorelease];
					operation = [[[NSInvocationOperation alloc] initWithTarget: presenter selector: notificationSelector object: completed] autorelease];
				} break;

				case DaemonPresenterNotificationItemTypeDidMove: /* fallthrough */
				case DaemonPresenterNotificationItemTypeDidChange: /* fallthrough */
				case DaemonPresenterNotificationItemTypeDidGainVersion: /* fallthrough */
				case DaemonPresenterNotificationItemTypeDidLoseVersion: /* fallthrough */
				case DaemonPresenterNotificationItemTypeDidResolveVersionConflict: /* fallthrough */
				case DaemonPresenterNotificationItemTypeDidChangeUbiquity: {
					id arg = nil;
					// TODO: arguments for these notifications
					operation = [[[NSInvocationOperation alloc] initWithTarget: presenter selector: notificationSelector object: arg] autorelease];
					operation.completionBlock = singlePresenterFinished;
				} break;
			}

			if (operation == nil) {
				FCDebug(@"no operation needs to be scheduled; assuming presenter notification is complete");
				singlePresenterFinished();
			} else {
				[presenter.presentedItemOperationQueue addOperation: operation];
			}
		}

		return true;
	});

	xpc_release(message);

	FCDebug(@"notification handler returning (this does NOT mean the notification(s) has/have been fully processed)");
};

@implementation NSFileAccessIntent (Internal)

- (NSUInteger)options
{
	return _options;
}

- (void)setOptions: (NSUInteger)options
{
	_options = options;
}

- (NSString*)identifier
{
	return _id;
}

- (void)setIdentifier: (NSString*)identifier
{
	[_id release];
	_id = [identifier copy];
}

- (instancetype)initWithURL: (NSURL*)url andOptions: (NSUInteger)options
{
	if (self = [super init]) {
		_url = [url copy];
		self.options = options;
	}
	return self;
}

@end

@implementation NSFileAccessIntent

@synthesize URL = _url;

+ (instancetype)readingIntentWithURL: (NSURL*)url options: (NSFileCoordinatorReadingOptions)options
{
	return [[[NSFileAccessIntent alloc] initWithURL: url andOptions: DaemonIntentOperationKindReading | (options << 2)] autorelease];
}

+ (instancetype)writingIntentWithURL: (NSURL*)url options: (NSFileCoordinatorWritingOptions)options
{
	return [[[NSFileAccessIntent alloc] initWithURL: url andOptions: DaemonIntentOperationKindWriting | (options << 2)] autorelease];
}

- (void)dealloc
{
	[_url release];
	[_id release];
	[super dealloc];
}

@end

@implementation NSFileCoordinator (Internal)

- (NSFileAccessCancellationToken*)submitIntent: (NSFileAccessIntent*)intent onQueue: (NSOperationQueue*)queue withBlock: (NSFileAccessIntentBlock)block
{
	xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
	NSFileAccessCancellationToken* cancellationToken = [[NSUUID UUID] UUIDString];
	dispatch_semaphore_t waiter = NULL;
	BOOL blocking = queue == nil;
	__block NSError* errorPointer = nil;
	__block block_safe_xpc_object_t replyObject = NULL;
	block = [[block copy] autorelease];

	FCDebug(@"submitting intent for path %@ with options %llu", [intent.URL path], (long long unsigned)intent.options);

	if (blocking) {
		waiter = dispatch_semaphore_create(0);
	}

	void (^completeBlock)() = [[^{
		FCDebug(@"operation completed; notifying daemon...");
		xpc_object_t message2 = xpc_dictionary_create_reply(replyObject);
		xpc_release(replyObject);
		xpc_dictionary_set_uint64(message2, DaemonMessageTypeKey, DaemonMessageTypeIntentCompletion);
		FCDebug(@"sending completion notification message: %@", xpc_nsdescription(message2));
		xpc_connection_send_message_with_reply(daemonConnection, message2, replyQueue, ^(xpc_object_t reply) {
			FCDebug(@"daemon acknowledged completion with message: %@", xpc_nsdescription(reply));
			if (blocking) {
				dispatch_semaphore_signal(waiter);
			}
		});
		xpc_release(message2);
	} copy] autorelease];

	@synchronized(_pendingCancellationTokens) {
		[_pendingCancellationTokens addObject: cancellationToken];
	}

	xpc_dictionary_set_uint64(message, DaemonMessageTypeKey, DaemonMessageTypeIntent);
	xpc_dictionary_set_string(message, DaemonIntentPathKey, [[NSFileManager defaultManager] fileSystemRepresentationWithPath: [intent.URL path]]);
	xpc_dictionary_set_uint64(message, DaemonIntentOptionsKey, intent.options);
	xpc_dictionary_set_string(message, DaemonIntentCancellationTokenKey, [cancellationToken UTF8String]);
	xpc_dictionary_set_string(message, DaemonIntentPurposeIdentifierKey, [_purposeIdentifier UTF8String]);

	FCDebug(@"sending intent message: %@", xpc_nsdescription(message));

	xpc_connection_send_message_with_reply(daemonConnection, message, replyQueue, ^(xpc_object_t reply) {
		// we can no longer be cancelled
		@synchronized(_pendingCancellationTokens) {
			[_pendingCancellationTokens removeObject: cancellationToken];
		}

		FCDebug(@"daemon replied to intent message with message: %@", xpc_nsdescription(reply));

		replyObject = xpc_retain(reply);

		if (xpc_dictionary_get_uint64(reply, DaemonIntentReplyResultKey) != DaemonIntentReplyResultOk) {
			FCDebug(@"daemon indicated failure/denial to perform operation");
			// TODO: more detailed errors
			errorPointer = [[NSError alloc] initWithDomain: @"org.darlinghq.Foundation.FileCoordination" // bogus error domain
			                                          code: 1
			                                      userInfo: nil];
		}

		if (blocking) {
			dispatch_semaphore_signal(waiter);
		} else {
			[queue addOperationWithBlock: ^{
				FCDebug(@"invoking user block %p on user queue %p with error %p", (void*)block, (void*)queue, (void*)errorPointer);
				block(errorPointer);
				[errorPointer release];
				FCDebug(@"user block complete");
				completeBlock();
			}];
		}
	});
	xpc_release(message);

	if (blocking) {
		dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);

		FCDebug(@"invoking user block %p synchronously with error %p", (void*)block, (void*)errorPointer);
		block(errorPointer);
		[errorPointer release];
		FCDebug(@"user block complete");
		completeBlock();

		dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);
		dispatch_release(waiter);
	}

	return cancellationToken;
}

- (void)submitNotificationForURL: (NSURL*)url ofType: (DaemonNotificationType)type withDetails: (xpc_object_t)notificationDetails
{
	xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);

	xpc_dictionary_set_uint64(message, DaemonMessageTypeKey, DaemonMessageTypeNotification);
	xpc_dictionary_set_uint64(message, DaemonNotificationTypeKey, type);
	xpc_dictionary_set_string(message, DaemonNotificationPathKey, [[NSFileManager defaultManager] fileSystemRepresentationWithPath: [url path]]);
	xpc_dictionary_set_value(message, DaemonNotificationDetailsKey, notificationDetails);

	FCDebug(@"submitting notification with message: %@", xpc_nsdescription(message));

	xpc_object_t reply = xpc_connection_send_message_with_reply_sync(daemonConnection, message);
	xpc_release(message);
	// TODO: error handling
	FCDebug(@"daemon replied with notification acknowledgement message: %@", xpc_nsdescription(message));
	xpc_release(reply);
}

- (void)submitCancellationWithToken: (NSFileAccessCancellationToken*)cancellationToken
{
	FCDebug(@"received request to cancel operation with cancellation token %@", cancellationToken);

	BOOL wasPresent = NO;
	@synchronized(_pendingCancellationTokens) {
		wasPresent = [_pendingCancellationTokens containsObject: cancellationToken];
		if (wasPresent) {
			[_pendingCancellationTokens removeObject: cancellationToken];
		}
	}

	if (!wasPresent) {
		FCDebug(@"no pending operation was found for cancellation token %@", cancellationToken);
		return;
	}

	xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);

	xpc_dictionary_set_uint64(message, DaemonMessageTypeKey, DaemonMessageTypeCancellation);
	xpc_dictionary_set_string(message, DaemonCancellationCancellationTokenKey, [cancellationToken UTF8String]);

	FCDebug(@"submitting cancellation message: %@", xpc_nsdescription(message));

	xpc_connection_send_message(daemonConnection, message);
	xpc_release(message);
}

@end

@implementation NSFileCoordinator

+ (void)initialize
{
	filePresentersByPath = [[NSMutableDictionary alloc] init];
	daemonConnection = xpc_connection_create_mach_service(DAEMON_SERVICE_NAME, NULL, 0);
	notificationQueue = dispatch_queue_create("org.darlinghq.Foundation.NSFileCoordinator.notification-queue", DISPATCH_QUEUE_CONCURRENT);
	replyQueue = dispatch_queue_create("org.darlinghq.Foundation.NSFileCoordinator.reply-queue", DISPATCH_QUEUE_CONCURRENT);

	xpc_connection_set_event_handler(daemonConnection, ^(xpc_object_t object) {
		xpc_type_t type = xpc_get_type(object);
		if (type == XPC_TYPE_ERROR) {
			handle_xpc_error(object);
		} else {
			// all other messages are not replies, so they should be about notifying presenters
			xpc_retain(object);
			block_safe_xpc_object_t _object = object;
			dispatch_async(notificationQueue, ^{
				handle_xpc_notification(_object);
			});
		}
	});
	xpc_connection_resume(daemonConnection);
}

+ (void)addFilePresenter: (id<NSFilePresenter>)filePresenter
{
	NSMutableSet<id<NSFilePresenter>>* presentersForPath = nil;
	@synchronized(filePresentersByPath) {
		presentersForPath = filePresentersByPath[filePresenter.presentedItemURL.URLByStandardizingPath.URLByResolvingSymlinksInPath.path];
		if (presentersForPath == nil) {
			FCDebug(@"no existing set for path %@; creating...", filePresenter.presentedItemURL.URLByStandardizingPath.URLByResolvingSymlinksInPath.path);
			filePresentersByPath[filePresenter.presentedItemURL.URLByStandardizingPath.URLByResolvingSymlinksInPath.path] = [NSMutableSet set];
		}
	}
	@synchronized(presentersForPath) {
		FCDebug(@"adding presenter %@ for path %@", filePresenter, filePresenter.presentedItemURL.URLByStandardizingPath.URLByResolvingSymlinksInPath.path);
		[presentersForPath addObject: filePresenter];
	}
}

+ (void)removeFilePresenter: (id<NSFilePresenter>)filePresenter
{
	NSMutableSet<id<NSFilePresenter>>* presentersForPath = nil;
	@synchronized(filePresentersByPath) {
		presentersForPath = filePresentersByPath[filePresenter.presentedItemURL.URLByStandardizingPath.URLByResolvingSymlinksInPath.path];
	}
	if (presentersForPath != nil) {
		@synchronized(presentersForPath) {
			FCDebug(@"removing presenter %@ for path %@", filePresenter, filePresenter.presentedItemURL.URLByStandardizingPath.URLByResolvingSymlinksInPath.path);
			[presentersForPath removeObject: filePresenter];
		}
	}
}

+ (NSArray<id<NSFilePresenter>>*)filePresenters
{
	NSMutableArray<id<NSFilePresenter>>* presenters = [NSMutableArray array];
	@synchronized(filePresentersByPath) {
		for (NSMutableSet<id<NSFilePresenter>>* presentersForPath in filePresentersByPath) {
			@synchronized(presentersForPath) {
				[presenters addObjectsFromArray: presentersForPath.allObjects];
			}
		}
	}
	return [NSArray arrayWithArray: presenters];
}

- (instancetype)init
{
	if (self = [super init]) {
		_purposeIdentifier = [[[NSUUID UUID] UUIDString] copy];
	}
	return self;
}

- (void)dealloc
{
	[_purposeIdentifier release];
	[super dealloc];
}

- (instancetype)initWithFilePresenter: (id<NSFilePresenter>)filePresenterOrNil
{
	if ((self = [self init]) && filePresenterOrNil != nil) {
		NSString* existingIdentifier = objc_getAssociatedObject(filePresenterOrNil, &kFilePresenterAssociatedPurposeIdentifierKey);
		if (existingIdentifier == nil) {
			objc_setAssociatedObject(filePresenterOrNil, &kFilePresenterAssociatedPurposeIdentifierKey, _purposeIdentifier, OBJC_ASSOCIATION_COPY);
		} else {
			[_purposeIdentifier release];
			_purposeIdentifier = [existingIdentifier copy];
		}
		_flags |= NSFileCoordinatorPurposeIdentifierAlreadyAssigned;
	}
	return self;
}

- (NSString*)purposeIdentifier
{
	return [[_purposeIdentifier copy] autorelease];
}

- (void)setPurposeIdentifier: (NSString*)newIdentifier
{
	if (_flags & NSFileCoordinatorPurposeIdentifierAlreadyAssigned) {
		// TODO: we have to throw an exception if it's already been assigned
		return;
	}

	_purposeIdentifier = [newIdentifier copy];
	_flags |= NSFileCoordinatorPurposeIdentifierAlreadyAssigned;
}

- (void)coordinateAccessWithIntents: (NSArray<NSFileAccessIntent*>*)intents queue: (NSOperationQueue*)queue byAccessor: (void (^)(NSError* error))accessor
{
	NSMutableArray<NSFileAccessCancellationToken*>* cancellationTokens = [[NSMutableArray alloc] init];
	NSUInteger totalCount = [intents count];
	__block _Atomic NSUInteger finishedCount = 0;
	__block _Atomic BOOL errored = NO;
	__block NSError* errorPointer = nil;
	accessor = [[accessor copy] autorelease];

	void (^intentComplete)(NSError*) = [[^(NSError* error) {
		if (error != nil) {
			if (!errored) {
				errored = YES;
				for (NSFileAccessCancellationToken* cancellationToken in cancellationTokens) {
					[self submitCancellationWithToken: cancellationToken];
				}
				errorPointer = [error retain];
			}
		}

		if (atomic_fetch_add(&finishedCount, 1) + 1 == totalCount) {
			// since this block is called on the user's queue, just call out to the user's block directly
			accessor([errorPointer autorelease]);
			[cancellationTokens release];
		}
	} copy] autorelease];

	for (NSFileAccessIntent* intent in intents) {
		// not sure if we should allocate our own operation queue or if its okay to use the user's queue
		// for our own access completion blocks
		[cancellationTokens addObject: [self submitIntent: intent onQueue: queue withBlock: intentComplete]];
		if (errored) {
			break;
		}
	}
}

- (void)coordinateReadingItemAtURL: (NSURL*)url options:(NSFileCoordinatorReadingOptions)options error: (NSError**)outError byAccessor: (void (^)(NSURL* newURL))reader
{
	// no need to copy `reader` block because we are synchronous
	NSFileAccessIntent* intent = [NSFileAccessIntent readingIntentWithURL: url options: options];
	[self submitIntent: intent onQueue: nil withBlock: ^(NSError* error) {
		if (error) {
			if (outError) {
				*outError = error;
			}
			return;
		} else {
			reader(intent.URL);
		}
	}];
}

- (void)coordinateWritingItemAtURL: (NSURL*)url options:(NSFileCoordinatorWritingOptions)options error: (NSError**)outError byAccessor: (void (^)(NSURL* newURL))writer
{
	// ditto
	NSFileAccessIntent* intent = [NSFileAccessIntent writingIntentWithURL: url options: options];
	[self submitIntent: intent onQueue: nil withBlock: ^(NSError* error) {
		if (error) {
			if (outError) {
				*outError = error;
			}
			return;
		} else {
			writer(intent.URL);
		}
	}];
}

- (void)coordinateReadingItemAtURL: (NSURL*)readingURL options:(NSFileCoordinatorReadingOptions)readingOptions writingItemAtURL: (NSURL*)writingURL options: (NSFileCoordinatorWritingOptions)writingOptions error: (NSError**)outError byAccessor: (void (^)(NSURL* newReadingURL, NSURL* newWritingURL))readerWriter
{
	// the documentation for this method is really confusing
	NSUnimplementedMethod();
}

- (void)coordinateWritingItemAtURL: (NSURL*)url1 options:(NSFileCoordinatorWritingOptions)options1 writingItemAtURL: (NSURL*)url2 options: (NSFileCoordinatorWritingOptions)options2 error: (NSError**)outError byAccessor: (void (^)(NSURL* newURL1, NSURL* newURL2))writer
{
	// ditto
	NSUnimplementedMethod();
}

- (void)prepareForReadingItemsAtURLs: (NSArray*)readingURLs options:(NSFileCoordinatorReadingOptions)readingOptions writingItemsAtURLs: (NSArray*)writingURLs options:(NSFileCoordinatorWritingOptions)writingOptions error: (NSError**)outError byAccessor: (void (^)(void (^completionHandler)(void)))batchAccessor
{
	// i'm pretty sure this isn't implemented correctly

	// summary of what we're doing here:
	// first, we asynchronously submit intents for each of the urls to the daemon
	// if we encounter an error, we cancel all the intents, wait for all of them to be cancelled, and then return
	// otherwise, if everything goes smoothly, we wait until all the intents have been processed, and then call the user's block
	// the user has to call our completion block, which unblocks us and then we return

	NSOperationQueue* operationQueue = [[NSOperationQueue alloc] init];
	NSMutableArray<NSFileAccessCancellationToken*>* cancellationTokens = [NSMutableArray array];
	NSUInteger totalCount = [readingURLs count] + [writingURLs count];
	__block _Atomic NSUInteger finishedCount = 0;
	__block _Atomic BOOL errored = NO;
	dispatch_semaphore_t waiter = dispatch_semaphore_create(0);

	void (^intentComplete)(NSError*) = [[^(NSError* error) {
		if (error != nil) {
			if (!errored) {
				errored = YES;
				for (NSFileAccessCancellationToken* cancellationToken in cancellationTokens) {
					[self submitCancellationWithToken: cancellationToken];
				}
				*outError = error;
			}
		}

		if (atomic_fetch_add(&finishedCount, 1) + 1 == totalCount) {
			if (errored) {
				dispatch_semaphore_signal(waiter);
			} else {
				batchAccessor(^{
					dispatch_semaphore_signal(waiter);
				});
			}
		}
	} copy] autorelease];

	for (NSURL* url in readingURLs) {
		NSFileAccessIntent* intent = [NSFileAccessIntent readingIntentWithURL: url options: readingOptions];
		[cancellationTokens addObject: [self submitIntent: intent onQueue: operationQueue withBlock: intentComplete]];
		if (errored) {
			break;
		}
	}
	for (NSURL* url in writingURLs) {
		NSFileAccessIntent* intent = [NSFileAccessIntent writingIntentWithURL: url options: writingOptions];
		[cancellationTokens addObject: [self submitIntent: intent onQueue: operationQueue withBlock: intentComplete]];
		if (errored) {
			break;
		}
	}

	dispatch_semaphore_wait(waiter, DISPATCH_TIME_FOREVER);
	dispatch_release(waiter);
	[operationQueue release];
}

- (void)itemAtURL: (NSURL*)oldURL willMoveToURL: (NSURL*)newURL
{
	xpc_object_t details = xpc_dictionary_create(NULL, NULL, 0);

	xpc_dictionary_set_string(details, DaemonNotificationDetailsNewPathKey, [[NSFileManager defaultManager] fileSystemRepresentationWithPath: [newURL path]]);

	[self submitNotificationForURL: oldURL ofType: DaemonNotificationTypeWillMoveToURL withDetails: details];
	xpc_release(details);
}

- (void)itemAtURL: (NSURL*)oldURL didMoveToURL: (NSURL*)newURL
{
	xpc_object_t details = xpc_dictionary_create(NULL, NULL, 0);

	xpc_dictionary_set_string(details, DaemonNotificationDetailsNewPathKey, [[NSFileManager defaultManager] fileSystemRepresentationWithPath: [newURL path]]);

	[self submitNotificationForURL: oldURL ofType: DaemonNotificationTypeDidMoveToURL withDetails: details];
	xpc_release(details);
}

- (void)itemAtURL: (NSURL*)url didChangeUbiquityAttributes: (NSSet<NSURLResourceKey>*)attributes
{
	xpc_object_t details = xpc_dictionary_create(NULL, NULL, 0);
	xpc_object_t attrs = xpc_array_create(NULL, 0);

	for (NSURLResourceKey key in attributes) {
		xpc_object_t value = xpc_string_create([key UTF8String]);
		xpc_array_append_value(attrs, value);
		xpc_release(value);
	}

	xpc_dictionary_set_value(details, DaemonNotificationDetailsChangedAttributesKey, attrs);
	xpc_release(attrs);

	[self submitNotificationForURL: url ofType: DaemonNotificationTypeDidChangeUbiquityAttributes withDetails: details];
	xpc_release(details);
}

- (void)cancel
{
	NSSet<NSFileAccessCancellationToken*>* cancellationTokens = nil;
	@synchronized(_pendingCancellationTokens) {
		cancellationTokens = [NSSet setWithSet: _pendingCancellationTokens];
	}

	for (NSFileAccessCancellationToken* cancellationToken in cancellationTokens) {
		[self submitCancellationWithToken: cancellationToken];
	}
}

@end
