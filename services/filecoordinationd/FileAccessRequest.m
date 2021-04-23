#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileManager.h>

#include <stdatomic.h>

#import "FileAccessRequest.h"
#import "daemon.h"
#import "logging.h"

// TODO: treat packages as files
// TODO: handle file/directory moving

// TODO: invoke most methods asynchronously
//       everything is mostly already set up to enable this, we're just not doing it

static NSMutableDictionary<NSString*, FileAccessQueue*>* queuesByPath = nil;

@interface NSString (PathAdditions)

@property(readonly) NSString* standardizedPath;

- (BOOL)isParentDirectoryOf: (NSString*)path;

@end

@implementation NSString (PathAdditions)

- (NSString*)standardizedPath
{
	NSURL* selfURL = [NSURL fileURLWithPath: self];
	return selfURL.URLByStandardizingPath.URLByResolvingSymlinksInPath.path;
}

- (BOOL)isParentDirectoryOf: (NSString*)path
{
	NSString* withSlash = [self stringByAppendingString: @"/"];
	return [path hasPrefix: withSlash];
}

@end


@implementation FileAccessRequest

@synthesize path = _path;
@synthesize options = _options;
@synthesize reply = _reply;
@synthesize purposeIdentifier = _purposeIdentifier;
@synthesize isDirectoryOperation = _isDirectoryOperation;

- (void)dealloc
{
	[_path release];
	[_reply release];
	[_purposeIdentifier release];
	[_waiters release];
	[super dealloc];
}

- (instancetype)initForPath: (NSString*)path withOptions: (NSUInteger)options reply: (XPCMessage*)reply purposeIdentifier: (NSString*)purposeIdentifier
{
	if (self = [super init]) {
		self.path = path.standardizedPath;
		self.options = options;
		self.reply = reply;
		self.purposeIdentifier = purposeIdentifier;
		_waiters = [NSMutableSet new];

		BOOL isDir = NO;
		_isDirectoryOperation = [[NSFileManager defaultManager] fileExistsAtPath: _path isDirectory: &isDir] && isDir;
	}
	return self;
}

+ (instancetype)requestForPath: (NSString*)path withOptions: (NSUInteger)options reply: (XPCMessage*)reply purposeIdentifier: (NSString*)purposeIdentifier
{
	return [[[FileAccessRequest alloc] initForPath: path withOptions: options reply: reply purposeIdentifier: purposeIdentifier] autorelease];
}

- (void)didFinishWaitingInQueue
{
	// nothing to do
	FCDDebug(@"request %@ did finish waiting in queue", self);
}

- (void)didFinishWaitingForOtherRequests
{
	// nothing to do
	FCDDebug(@"request %@ did finish waiting for other requests", self);
}

- (void)didFinishWaitingForPresenters
{
	FCDDebug(@"request %@ did finish waiting for presenters", self);
	// we can tell our requester whether or not they can go ahead with their operation now
	xpc_dictionary_set_uint64(self.reply.object, DaemonMessageTypeKey, DaemonMessageTypeIntentReply);
	xpc_dictionary_set_uint64(self.reply.object, DaemonIntentReplyResultKey, self.accessDidFail ? DaemonIntentReplyResultError : DaemonIntentReplyResultOk);
	[self.reply sendWithReply: ^(NSError* error, XPCMessage* completionMessage) {
		if (error) {
			if ([error.domain isEqualToString: XPCMessageErrorDomain] && error.code == XPCMessageConnectionInvalidated) {
				FCDDebug(@"client died before they could reply to request %@; continuing...", self);
			} else {
				FCDLog(@"request %@ received error %@ while waiting for reply from client", self, error);
			}
			self.reply = nil;
		} else {
			FCDDebug(@"request %@ received completion message from client with content: %@", self, completionMessage);
			FCDAssert(xpc_dictionary_get_uint64(completionMessage.object, DaemonMessageTypeKey) == DaemonMessageTypeIntentCompletion);
			self.reply = [XPCMessage messageInReplyTo: completionMessage];
		}
		self.isComplete = YES;
		[self complete];
	}];
}


- (void)didFinishWaitingForPresentersAgain
{
	FCDDebug(@"request %@ did finish waiting for presenters again", self);
	if (self.reply == nil) {
		FCDDebug(@"request %@ did not have a reply object pending. this means the client died before they could send an operation completion message; continuing...", self);
	} else {
		// and now, the final message to our requester: everything is done
		xpc_dictionary_set_uint64(self.reply.object, DaemonMessageTypeKey, DaemonMessageTypeIntentCompletionReply);
		FCDDebug(@"request %@ sending message to client with content %@", self, self.reply);
		[self.reply send];
	}
}

- (BOOL)isReadOperation
{
	return (self.options & DaemonIntentOperationKindMask) == DaemonIntentOperationKindReading;
}

- (BOOL)isWriteOperation
{
	return (self.options & DaemonIntentOperationKindMask) == DaemonIntentOperationKindWriting;
}

- (BOOL)isOngoing
{
	return (_state & FileAccessRequestIsOngoing);
}

- (void)setIsOngoing: (BOOL)isOngoing
{
	if (isOngoing) {
		_state |= FileAccessRequestIsOngoing;
	} else {
		_state &= ~FileAccessRequestIsOngoing;
	}
}

- (BOOL)isQueued
{
	return (_state & FileAccessRequestIsQueued);
}

- (void)setIsQueued: (BOOL)isQueued
{
	if (isQueued) {
		_state |= FileAccessRequestIsQueued;
	} else {
		_state &= ~FileAccessRequestIsQueued;
	}
}

- (BOOL)isComplete
{
	@synchronized(self) {
		return (_state & FileAccessRequestIsComplete);
	}
}

- (void)setIsComplete: (BOOL)isComplete
{
	@synchronized(self) {
		if (isComplete) {
			_state |= FileAccessRequestIsComplete;
		} else {
			_state &= ~FileAccessRequestIsComplete;
		}
	}
}

- (BOOL)accessDidFail
{
	@synchronized(self) {
		return (_state & FileAccessRequestDidFail);
	}
}

- (void)setAccessDidFail: (BOOL)accessDidFail
{
	@synchronized(self) {
		if (accessDidFail) {
			_state |= FileAccessRequestDidFail;
		} else {
			_state &= ~FileAccessRequestDidFail;
		}
	}
}

- (NSFileCoordinatorReadingOptions)readingOptions
{
	return _options >> 2;
}

- (NSFileCoordinatorWritingOptions)writingOptions
{
	return _options >> 2;
}

- (BOOL)isMoreRestrictiveThan: (FileAccessRequest*)request
{
	// these cases should never occur, since this method is only meant to be used for operations that are cooperating
	// (and writes can't cooperate), but just in case...
	if (self.isWriteOperation && !request.isWriteOperation) {
		// write operations are always more restrictive than read operations
		return YES;
	} else if (request.isWriteOperation) {
		// we're a read operation and they're a write operation
		// they're more restrictive
		return NO;
	}

	if ((self.readingOptions & NSFileCoordinatorReadingWithoutChanges) == 0 && (request.readingOptions & NSFileCoordinatorReadingWithoutChanges) != 0) {
		// waiting for changes is more restrictive
		return YES;
	}

	// we're either equally restrictive or less restrictive
	return NO;
}

// assumes that `self` the ongoing/queued operation and `request` is the request that wants to cooperate (and is not currently ongoing/queued).
// note that the criteria for who we can cooperate with changes slightly depending on whether or not we're an ongoing operation
//
// the documentation says that coordinated reads and writes with the same purpose identifier never block each other, but that doesn't make sense.
// (e.g. how can you allow a write to occur simultaneously with a read?)
- (BOOL)canCooperateWith: (FileAccessRequest*)request
{
	// write operations can't cooperate--ever
	if (self.isWriteOperation || request.isWriteOperation) {
		return NO;
	}

	// at this point, both of us are read operations

	// if we're already ongoing and we're a read operation that waits for changes to be saved,
	// we can cooperate with all other read operations
	if (self.isOngoing && (self.readingOptions & NSFileCoordinatorReadingWithoutChanges) == 0) {
		return YES;
	} else if ((self.readingOptions & NSFileCoordinatorReadingWithoutChanges) == (request.readingOptions & NSFileCoordinatorReadingWithoutChanges)) {
		// if we both require changes to be written or we both don't, we can cooperate
		return YES;
	}

	// otherwise, nope; we won't get along
	return NO;
}

- (BOOL)needsToWaitFor: (FileAccessRequest*)request
{
	if ([self.path isParentDirectoryOf: request.path]) {
		// parents always need to wait for their children to finish
		// possible BUG: do parents have to wait for children for all their operations? even for directory read operations?
		return YES;
	} else if ([request.path isParentDirectoryOf: self.path]) {
		if ((request->_options & (NSFileCoordinatorWritingForDeleting | NSFileCoordinatorWritingForMoving)) != 0) {
			// children have to wait for parents to be deleted or moved
			return YES;
		}
		// ...but not for anything else
		return NO;
	} else {
		return NO;
	}
}

- (void)registerWaiter: (FileAccessRequestWaiter)waiter
{
	@synchronized(self) {
		if (_didFire) {
			FCDDebug(@"request %@ is already complete; calling waiter %p immediately", self, (void*)waiter);
			waiter();
			return;
		}
		FCDDebug(@"request %@ is registering waiter %p", self, (void*)waiter);
		[_waiters addObject: [[waiter copy] autorelease]];
	}
}

- (void)complete
{
	NSSet<FileAccessRequestWaiter>* waiters;
	@synchronized(self) {
		if (_didFire) {
			FCDDebug(@"someone tried to mark request %@ as complete, but it was already complete", self);
			return;
		}
		FCDDebug(@"marking request %@ as complete", self);
		_didFire = YES;
		self.isComplete = YES;
		waiters = [NSSet setWithSet: _waiters];
		[_waiters removeAllObjects];
	}
	for (FileAccessRequestWaiter waiter in waiters) {
		FCDDebug(@"request %@ is calling waiter %p", self, (void*)waiter);
		waiter();
	}
}

- (void)start
{
	[[FileAccessQueue queueForPath: _path] addRequest: self];
}

- (void)cancel
{
	// TODO
	// cancelling stuff is hard
	FCDUnimplementedMethod();
}

- (BOOL)canProceedWithPresenterResponse: (XPCObject*)presenterResponse
{
	FCDAssert(xpc_dictionary_get_uint64(presenterResponse.object, DaemonMessageTypeKey) == DaemonMessageTypePresenterReply);
	xpc_object_t responseArray = xpc_dictionary_get_value(presenterResponse.object, DaemonPresenterReplyArrayKey);
	size_t nextResponseIndex = 0;

	if (self.isReadOperation && (self.readingOptions & NSFileCoordinatorReadingWithoutChanges) == 0) {
		FCDAssert(xpc_array_get_count(responseArray) == 2);
		xpc_object_t saveDict = xpc_array_get_value(responseArray, nextResponseIndex++);
		FCDAssert(xpc_dictionary_get_uint64(saveDict, DaemonPresenterReplyItemTypeKey) == DaemonPresenterNotificationItemTypeSave);
		if (xpc_dictionary_get_uint64(saveDict, DaemonPresenterReplyItemResultKey) != DaemonPresenterReplyItemResultOk) {
			FCDDebug(@"request %@ can NOT proceed with presenter notification response %@", self, xpc_nsdescription(saveDict));
			return NO;
		}
	} else if (self.isWriteOperation && (self.writingOptions & NSFileCoordinatorWritingForDeleting) != 0) {
		FCDAssert(xpc_array_get_count(responseArray) == 2);
		xpc_object_t deleteDict = xpc_array_get_value(responseArray, nextResponseIndex++);
		FCDAssert(xpc_dictionary_get_uint64(deleteDict, DaemonPresenterReplyItemTypeKey) == DaemonPresenterNotificationItemTypePrepareForDeletion);
		if (xpc_dictionary_get_uint64(deleteDict, DaemonPresenterReplyItemResultKey) != DaemonPresenterReplyItemResultOk) {
			FCDDebug(@"request %@ can NOT proceed with presenter notification response %@", self, xpc_nsdescription(deleteDict));
			return NO;
		}
	} else {
		FCDAssert(xpc_array_get_count(responseArray) == 1);
	}

	xpc_object_t relinquishDict = xpc_array_get_value(responseArray, nextResponseIndex++);
	++nextResponseIndex;
	FCDAssert(xpc_dictionary_get_uint64(relinquishDict, DaemonPresenterReplyItemTypeKey) == (self.isReadOperation ? DaemonPresenterNotificationItemTypeRelinquishToReader : DaemonPresenterNotificationItemTypeRelinquishToWriter));
	if (xpc_dictionary_get_uint64(relinquishDict, DaemonPresenterReplyItemResultKey) != DaemonPresenterReplyItemResultOk) {
		FCDDebug(@"request %@ can NOT proceed with presenter notification response %@", self, xpc_nsdescription(relinquishDict));
		return NO;
	}

	FCDDebug(@"request %@ can proceed with presenter response", self);
	return YES;
}

- (XPCObject*)initialPresenterMessageDetails
{
	xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_uint64(message, DaemonMessageTypeKey, DaemonMessageTypePresenterNotification);

	xpc_object_t notificationArray = xpc_array_create(NULL, 0);

	if (self.isReadOperation && (self.readingOptions & NSFileCoordinatorReadingWithoutChanges) == 0) {
		xpc_object_t saveDict = xpc_dictionary_create(NULL, NULL, 0);
		xpc_dictionary_set_uint64(saveDict, DaemonPresenterNotificationItemTypeKey, DaemonPresenterNotificationItemTypeSave);
		xpc_dictionary_set_string(saveDict, DaemonPresenterNotificationItemPathKey, self.path.UTF8String);
		xpc_array_append_value(notificationArray, saveDict);
		xpc_release(saveDict);
	} else if (self.isWriteOperation && (self.writingOptions & NSFileCoordinatorWritingForDeleting) != 0) {
		xpc_object_t deleteDict = xpc_dictionary_create(NULL, NULL, 0);
		xpc_dictionary_set_uint64(deleteDict, DaemonPresenterNotificationItemTypeKey, DaemonPresenterNotificationItemTypePrepareForDeletion);
		xpc_dictionary_set_string(deleteDict, DaemonPresenterNotificationItemPathKey, self.path.UTF8String);
		xpc_array_append_value(notificationArray, deleteDict);
		xpc_release(deleteDict);
	}

	xpc_object_t relinquishDict = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_uint64(relinquishDict, DaemonPresenterNotificationItemTypeKey, self.isReadOperation ? DaemonPresenterNotificationItemTypeRelinquishToReader : DaemonPresenterNotificationItemTypeRelinquishToWriter);
	xpc_dictionary_set_string(relinquishDict, DaemonPresenterNotificationItemPathKey, self.path.UTF8String);
	xpc_array_append_value(notificationArray, relinquishDict);
	xpc_release(relinquishDict);

	xpc_dictionary_set_value(message, DaemonPresenterNotificationArrayKey, notificationArray);
	xpc_release(notificationArray);

	XPCObject* messageObject = [XPCObject objectWithXPCObject: message];
	xpc_release(message);
	return messageObject;
}

- (XPCObject*)finalPresenterMessageDetails
{
	xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_uint64(message, DaemonMessageTypeKey, DaemonMessageTypePresenterNotification);

	xpc_object_t notificationArray = xpc_array_create(NULL, 0);

	xpc_dictionary_set_value(message, DaemonPresenterNotificationArrayKey, notificationArray);
	xpc_release(notificationArray);

	xpc_object_t regainDict = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_uint64(regainDict, DaemonPresenterNotificationItemTypeKey, DaemonPresenterNotificationItemTypeReacquireAccess);
	xpc_dictionary_set_string(regainDict, DaemonPresenterNotificationItemPathKey, self.path.UTF8String);
	xpc_array_append_value(notificationArray, regainDict);
	xpc_release(regainDict);

	if (self.isWriteOperation && (self.writingOptions & (NSFileCoordinatorWritingForMoving | NSFileCoordinatorWritingForDeleting)) == 0) {
		xpc_object_t modDict = xpc_dictionary_create(NULL, NULL, 0);
		xpc_dictionary_set_uint64(modDict, DaemonPresenterNotificationItemTypeKey, DaemonPresenterNotificationItemTypeDidChange);
		xpc_dictionary_set_string(modDict, DaemonPresenterNotificationItemPathKey, self.path.UTF8String);
		xpc_array_append_value(notificationArray, modDict);
		xpc_release(modDict);
	}

	XPCObject* messageObject = [XPCObject objectWithXPCObject: message];
	xpc_release(message);
	return messageObject;
}

@end

@implementation FileAccessQueueMember

@synthesize isComplete = _isComplete;
@synthesize isOngoing = _isOngoing;
@synthesize isAcceptingNewRequests = _isAcceptingNewRequests;

- (BOOL)isDirectoryOperation
{
	// they should all have the same result for this, since they're operating on the same path
	return ((FileAccessRequest*)[_cooperatingRequests anyObject]).isDirectoryOperation;
}

- (NSString*)path
{
	// same here
	return ((FileAccessRequest*)[_cooperatingRequests anyObject]).path;
}

- (NSSet<FileAccessRequest*>*)cooperatingRequests
{
	@synchronized(_cooperatingRequests) {
		return [NSSet setWithSet: _cooperatingRequests];
	}
}

- (FileAccessRequest*)mostRestrictiveRequest
{
	FileAccessRequest* mostRestrictiveRequest = nil;
	for (FileAccessRequest* request in self.cooperatingRequests) {
		if (mostRestrictiveRequest == nil || [request isMoreRestrictiveThan: mostRestrictiveRequest]) {
			mostRestrictiveRequest = request;
		}
	}
	return mostRestrictiveRequest;
}

- (instancetype)init
{
	if (self = [super init]) {
		_cooperatingRequests = [NSMutableSet new];
		_waiters = [NSMutableSet new];
		_isAcceptingNewRequests = YES;
	}
	return self;
}

- (void)dealloc
{
	[_cooperatingRequests release];
	[_waiters release];
	[super dealloc];
}

- (BOOL)tryAddingRequest: (FileAccessRequest*)request
{
	BOOL compatible = NO;
	@synchronized(self) {
		if (!self.isAcceptingNewRequests) {
			FCDDebug(@"someone tried to add request %@ to queue member %@, but it is not accepting new requests", request, self);
			return NO;
		}
		// keep `self` locked here until we (maybe) add our object
		// as long as we have it locked, we can't become complete.
		// if we do add our object, we guarantee that we don't become complete.
		// (if we don't add our object, then we just return, so we don't care about whether we complete or not)
		@synchronized(_cooperatingRequests) {
			if ([_cooperatingRequests count] > 0) {
				for (FileAccessRequest* myRequest in _cooperatingRequests) {
					if ([myRequest canCooperateWith: request]) {
						compatible = YES;
						break;
					}
				}
				if (!compatible) {
					return NO;
				}
			}
			FCDDebug(@"queue member %@ is adding request %@", self, request);
			[_cooperatingRequests addObject: request];
		}
	}

	[request registerWaiter: ^{
		[self singleOperationDidComplete];
	}];

	// we don't need to lock this next part because we can't become complete until the completion count matches the request count
	if (self.isOngoing) {
		// if we're ongoing, we've already waited in the queue
		[request didFinishWaitingInQueue];
		// ... we might still be waiting for other requests or for presenters, though, so check for those
		
		// we do need to lock these to prevent them from being updated under us
		@synchronized(self) {
			if (_didFinishWaitingForOthers) {
				[request didFinishWaitingForOtherRequests];
			}
			if (_didFinishWaitingForPresenters) {
				[request didFinishWaitingForPresenters];
			}
		}
	}

	return YES;
}

- (void)didFinishWaitingInQueue
{
	FCDDebug(@"queue member %@ did finish waiting in queue", self);
	@synchronized(self) {
		_isOngoing = YES;
	}

	// use the property, which is a copy of our internal set,
	// because the internal set could be copied while we're iterating it
	for (FileAccessRequest* request in self.cooperatingRequests) {
		[request didFinishWaitingInQueue];
	}

	// they should all have the same restrictions for waiting for other requests, so just pick one
	FileAccessRequest* request = _cooperatingRequests.anyObject;
	FileAccessQueue* myQueue = [FileAccessQueue queueForPath: request.path];
	NSArray<FileAccessQueue*>* parentQueues = myQueue.parentQueues;
	NSSet<FileAccessQueue*>* childQueues = myQueue.recursiveChildren;
	NSUInteger total = [parentQueues count] + [childQueues count];
	__block _Atomic NSUInteger completedTotal = 0;

	void (^completionCallback)(void) = [[^{
		FCDDebug(@"queue member %@ finished waiting for a single queue member", self);
		if (atomic_fetch_add(&completedTotal, 1) + 1 == total) {
			[self didFinishWaitingForOtherRequests];
		}
	} copy] autorelease];

	for (FileAccessQueue* parentQueue in parentQueues) {
		BOOL alreadyCompleted = NO;
		@synchronized(parentQueue) {
			FileAccessQueueMember* ongoingParentMember = parentQueue.ongoingMember;
			if (ongoingParentMember == nil) {
				alreadyCompleted = YES;
			} else {
				@synchronized(ongoingParentMember) {
					if ([self needsToWaitFor: ongoingParentMember]) {
						FCDDebug(@"queue member %@ needs to wait for parent queue member %@", self, ongoingParentMember);
						[ongoingParentMember registerWaiter: ^{
							completionCallback();
						}];
					} else {
						alreadyCompleted = YES;
					}
				}
			}
		}
		if (alreadyCompleted) {
			completionCallback();
		}
	}

	for (FileAccessQueue* childQueue in childQueues) {
		BOOL alreadyCompleted = NO;
		@synchronized(childQueue) {
			FileAccessQueueMember* ongoingChildMember = childQueue.ongoingMember;
			if (ongoingChildMember == nil) {
				alreadyCompleted = YES;
			} else {
				@synchronized(ongoingChildMember) {
					if ([self needsToWaitFor: ongoingChildMember]) {
						FCDDebug(@"queue member %@ needs to wait for child queue member %@", self, ongoingChildMember);
						[ongoingChildMember registerWaiter: ^{
							completionCallback();
						}];
					} else {
						alreadyCompleted = YES;
					}
				}
			}
		}
		if (alreadyCompleted) {
			completionCallback();
		}
	}
}

- (void)didFinishWaitingForOtherRequests
{
	FCDDebug(@"queue member %@ did finish waiting for other requests", self);
	@synchronized(self) {
		_didFinishWaitingForOthers = YES;
	}

	// notify the requests that we're done waiting for other requests.
	// at the same time, find which one is the most restrictive
	// we can guarantee that the requirements for most restrictive one also satisfies the requirements for the less restrictive ones,
	// so we'll do all the presenter notification according to that one
	FileAccessRequest* mostRestrictiveRequest = nil;
	for (FileAccessRequest* request in self.cooperatingRequests) {
		if (mostRestrictiveRequest == nil || [request isMoreRestrictiveThan: mostRestrictiveRequest]) {
			mostRestrictiveRequest = request;
		}
		[request didFinishWaitingForOtherRequests];
	}

	FCDDebug(@"most restrictive request in queue member %@ is %@", self, mostRestrictiveRequest);

	// now comes the long wait: we have to ask all presenters to let us have the file and wait for them to respond

	NSSet<XPCObject*>* currentClients = nil;
	@synchronized(clients) {
		currentClients = [NSSet setWithSet: clients];
	}

	__block _Atomic NSUInteger responsesReceived = 0;
	__block BOOL canProceed = YES;
	size_t total = [currentClients count];
	FCDDebug(@"queue member %@ needs to wait for %zu clients to respond to presenter notification(s)", self, total);
	void (^replyHandler)(NSError*, XPCMessage*) = [[^(NSError* error, XPCMessage* reply) {
		if (error) {
			if ([error.domain isEqualToString: XPCMessageErrorDomain] && error.code == XPCMessageConnectionInvalidated) {
				FCDDebug(@"client died before they could reply to queue member %@; continuing...", self);
			} else {
				FCDLog(@"queue member %@ received error %@ while waiting for reply from client", self, error);
			}
			FCDDebug(@"queue member %@ received error while waiting for reply from client, but assuming success and continuing", self);
		} else {
			FCDDebug(@"queue member %@ received reply from client with content %@", self, reply);
			if (![mostRestrictiveRequest canProceedWithPresenterResponse: reply]) {
				FCDDebug(@"queue member %@ can NOT proceed with reply", self);
				canProceed = NO;
			}
		}
		if (atomic_fetch_add(&responsesReceived, 1) + 1 == total) {
			if (!canProceed) {
				@synchronized(self) {
					_accessDidFail = YES;
					_isAcceptingNewRequests = NO;
				}
			}
			[self didFinishWaitingForPresenters];
		}
	} copy] autorelease];

	XPCObject* messageDict = mostRestrictiveRequest.initialPresenterMessageDetails;
	FCDDebug(@"queue member %@ will send message to clients with content: %@", self, messageDict);
	for (XPCObject* client in currentClients) {
		XPCMessage* message = [XPCMessage messageForConnection: client withRawMessage: messageDict];
		[message sendWithReply: replyHandler];
	}
}

- (void)didFinishWaitingForPresenters
{
	FCDDebug(@"queue member %@ did finish waiting for presenters", self);
	@synchronized(self) {
		_didFinishWaitingForPresenters = YES;
	}

	for (FileAccessRequest* request in self.cooperatingRequests) {
		// we should have already registered a waiter when we added the request in tryAddingRequest
		/*[request registerWaiter: ^{
			[self singleOperationDidComplete];
		}];*/
		if (_accessDidFail) {
			request.accessDidFail = YES;
		}
		[request didFinishWaitingForPresenters];
	}

	// we have nothing else to do; operations will let us know once they complete
}


- (void)didFinishPerformingOperations
{
	FCDDebug(@"queue member %@ did finish performing operations", self);
	@synchronized(self) {
		// should already be set, but just in case
		_isAcceptingNewRequests = NO;
	}

	// now we have another round of waiting: we have to notify presenters that we did something and wait for them to acknowledge it

	FileAccessRequest* mostRestrictiveRequest = self.mostRestrictiveRequest;

	FCDDebug(@"most restrictive request in queue member %@ is %@", self, mostRestrictiveRequest);

	NSSet<XPCObject*>* currentClients = nil;
	@synchronized(clients) {
		currentClients = [NSSet setWithSet: clients];
	}

	__block _Atomic NSUInteger responsesReceived = 0;
	size_t total = [currentClients count];
	FCDDebug(@"queue member %@ needs to wait for %zu clients to respond to presenter notification(s)", self, total);
	void (^replyHandler)(NSError*, XPCMessage*) = [[^(NSError* error, XPCMessage* reply) {
		if (error) {
			if ([error.domain isEqualToString: XPCMessageErrorDomain] && error.code == XPCMessageConnectionInvalidated) {
				FCDDebug(@"client died before they could reply to queue member %@; continuing...", self);
			} else {
				FCDLog(@"queue member %@ received error %@ while waiting for reply from client", self, error);
			}
			FCDDebug(@"queue member %@ received error while waiting for reply from client, but assuming success and continuing", self);
		} else {
			FCDDebug(@"queue member %@ received reply from client with content %@", self, reply);
			FCDAssert(xpc_dictionary_get_uint64(reply.object, DaemonMessageTypeKey) == DaemonMessageTypePresenterReply);
		}
		if (atomic_fetch_add(&responsesReceived, 1) + 1 == total) {
			[self didFinishWaitingForPresentersAgain];
		}
	} copy] autorelease];

	XPCObject* messageDict = mostRestrictiveRequest.finalPresenterMessageDetails;
	FCDDebug(@"queue member %@ will send message to clients with content: %@", self, messageDict);
	for (XPCObject* client in currentClients) {
		XPCMessage* message = [XPCMessage messageForConnection: client withRawMessage: messageDict];
		[message sendWithReply: replyHandler];
	}
}

- (void)didFinishWaitingForPresentersAgain
{
	FCDDebug(@"queue member %@ did finish waiting for presenters again", self);
	// *so* close: we have to tell our requesters that we are completely done and they can carry on with their lives
	for (FileAccessRequest* request in self.cooperatingRequests) {
		[request didFinishWaitingForPresentersAgain];
	}

	// finally, we're done; tell all our waiters
	[self complete];
}

- (void)singleOperationDidComplete
{
	BOOL allOperationsCompleted = NO;
	@synchronized(self) {
		// no need to make `_completedCount` atomic; we're already locked
		++_completedCount;
		if (_completedCount >= [_cooperatingRequests count]) {
			_isComplete = YES;
			_isOngoing = NO;
			_isAcceptingNewRequests = NO;
			allOperationsCompleted = YES;
		}
	}
	if (allOperationsCompleted) {
		[self didFinishPerformingOperations];
	}
}

- (BOOL)needsToWaitFor: (FileAccessQueueMember*)queueMember
{
	@synchronized(self) {
		if (self.isComplete) {
			return NO;
		}
		@synchronized(queueMember) {
			if (queueMember.isComplete) {
				return NO;
			}
			// all of our members should have the same restrictions when it comes to waiting for other requests
			if ([_cooperatingRequests.anyObject needsToWaitFor: queueMember->_cooperatingRequests.anyObject]) {
				return YES;
			}
		}
	}
	return NO;
}

- (void)registerWaiter: (FileAccessQueueMemberWaiter)waiter
{
	@synchronized(self) {
		if (_didFire) {
			FCDDebug(@"queue member %@ is already complete; invoking waiter %p immediately", self, (void*)waiter);
			waiter();
			return;
		}
		FCDDebug(@"queue member %@ is registering waiter %p", self, (void*)waiter);
		[_waiters addObject: [[waiter copy] autorelease]];
	}
}

- (void)complete
{
	NSSet<FileAccessQueueMemberWaiter>* waiters;
	@synchronized(self) {
		if (_didFire) {
			FCDDebug(@"someone tried to mark queue member %@ as complete, but it was already complete", self);
			return;
		}
		FCDDebug(@"marking queue member %@ as complete", self);
		_didFire = YES;
		_isComplete = YES;
		_isOngoing = NO;
		waiters = [NSSet setWithSet: _waiters];
		[_waiters removeAllObjects];
	}
	for (FileAccessQueueMemberWaiter waiter in waiters) {
		waiter();
	}
}

@end

@implementation FileAccessQueue

@synthesize ongoingMember = _ongoingMember;
@synthesize path = _path;

+ (void)initialize
{
	queuesByPath = [NSMutableDictionary new];
}

- (instancetype)initForPath: (NSString*)path
{
	if (self = [super init]) {
		_path = [path.standardizedPath copy];
		_members = [NSMutableArray new];
		_children = [NSMutableSet new];

		FileAccessQueue* existingQueue = nil;
		@synchronized(queuesByPath) {
			existingQueue = [queuesByPath[path.standardizedPath] retain];
			if (existingQueue == nil) {
				queuesByPath[path.standardizedPath] = self;
			}
		}

		if (existingQueue != nil) {
			[self release];
			return existingQueue;
		}

		// if we're the root directory, we have no parents
		if (![_path.stringByDeletingLastPathComponent isEqualToString: @"/"]) {
			// register ourselves with parents
			NSString* currentPath = _path.stringByDeletingLastPathComponent;
			FileAccessQueue* currentQueue = self;
			while (YES) {
				FileAccessQueue* parentQueue = [FileAccessQueue queueForPath: currentPath];
				@synchronized(parentQueue->_children) {
					[parentQueue->_children addObject: currentQueue];
				}
				currentQueue = parentQueue;
				if ([currentPath isEqualToString: @"/"]) {
					// once we reach the root dir, we're done (the root dir has no parents)
					break;
				}
				currentPath = currentPath.stringByDeletingLastPathComponent;
			}
		}
	}
	return self;
}

+ (instancetype)queueForPath: (NSString*)path
{
	FileAccessQueue* existingQueue = nil;
	@synchronized(queuesByPath) {
		existingQueue = queuesByPath[path.standardizedPath];
		if (existingQueue == nil) {
			existingQueue = [[[FileAccessQueue alloc] initForPath: path] autorelease];
			/*queuesByPath[path.standardizedPath] = existingQueue;*/ // the queue will automatically register itself
		} else {
			existingQueue = [[existingQueue retain] autorelease];
		}
	}
	return existingQueue;
}

- (void)dealloc
{
	[_path release];
	[_members release];
	[_children release];
	[super dealloc];
}

- (NSSet<FileAccessQueue*>*)immediateChildren
{
	@synchronized(_children) {
		return [NSSet setWithSet: _children];
	}
}

- (NSSet<FileAccessQueue*>*)recursiveChildren
{
	NSSet<FileAccessQueue*>* immediateChildren = self.immediateChildren;
	NSMutableSet<FileAccessQueue*>* allChildren = [NSMutableSet setWithSet: immediateChildren];
	for (FileAccessQueue* child in immediateChildren) {
		[allChildren unionSet: child.recursiveChildren];
	}
	return [NSSet setWithSet: allChildren];
}

- (FileAccessQueue*)parentQueue
{
	if ([_path isEqualToString: @"/"]) {
		// root directory can't have a parent directory
		return nil;
	}
	return [FileAccessQueue queueForPath: _path.stringByDeletingLastPathComponent];
}

- (NSArray<FileAccessQueue*>*)parentQueues
{
	NSMutableArray<FileAccessQueue*>* parentQueues = [NSMutableArray array];
	FileAccessQueue* parentQueue = self.parentQueue;
	if (parentQueue != nil) {
		[parentQueues addObject: parentQueue];
		[parentQueues addObjectsFromArray: parentQueue.parentQueues];
	}
	return [NSArray arrayWithArray: parentQueues];
}

- (void)addRequest: (FileAccessRequest*)request
{
	@synchronized(self) {
		FCDDebug(@"request %@ wants to add itself to queue %@", request, self);
		if (_ongoingMember == nil) {
			FCDDebug(@"no current ongoing member; setting request %@ as ongoing member of queue %@", request, self);
			FileAccessQueueMember* newQueueMember = [FileAccessQueueMember new];
			[newQueueMember tryAddingRequest: request];
			_ongoingMember = newQueueMember;
		} else {
			@synchronized(_ongoingMember) {
				if (_ongoingMember.isAcceptingNewRequests && [_ongoingMember tryAddingRequest: request]) {
					FCDDebug(@"added request %@ to ongoing member %@ of queue %@", request, _ongoingMember, self);
					return;
				}
			}
			@synchronized(_members) {
				for (FileAccessQueueMember* member in _members) {
					if ([member tryAddingRequest: request]) {
						FCDDebug(@"added request %@ to queued member %@ of queue %@", request, member, self);
						return;
					}
				}
				FileAccessQueueMember* newQueueMember = [[FileAccessQueueMember new] autorelease];
				[newQueueMember tryAddingRequest: request];
				FCDDebug(@"created new queue member %@ for request %@ on queue %@", newQueueMember, request, self);
				[self enqueue: newQueueMember];
			}
			return;
		}
	}

	// if we got here, we have to setup the new ongoing member
	FCDDebug(@"setting up new ongoing queue member %@ on queue %@", _ongoingMember, self);
	[_ongoingMember registerWaiter: ^{
		[self ongoingRequestDidFinish];
	}];
	[_ongoingMember didFinishWaitingInQueue];
}

- (FileAccessQueueMember*)peek
{
	@synchronized(_members) {
		return [_members firstObject];
	}
}

- (void)enqueue: (FileAccessQueueMember*)member
{
	@synchronized(_members) {
		[_members addObject: member];
	}
}

- (void)ongoingRequestDidFinish
{
	@synchronized(self) {
		FCDDebug(@"ongoing queue member %@ did finish on queue %@", _ongoingMember, self);
		[_ongoingMember release];
		@synchronized(_members) {
			if ([_members count] == 0) {
				FCDDebug(@"no more queue members in queue %@", self);
				_ongoingMember = nil;
				return;
			}
			_ongoingMember = [[_members firstObject] retain];
			[_members removeObjectAtIndex: 0];
		}
	}
	FCDDebug(@"setting up new ongoing queue member %@ on queue %@", _ongoingMember, self);
	[_ongoingMember registerWaiter: ^{
		[self ongoingRequestDidFinish];
	}];
	[_ongoingMember didFinishWaitingInQueue];
}

@end
