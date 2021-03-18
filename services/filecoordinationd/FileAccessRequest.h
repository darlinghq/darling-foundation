#import <Foundation/NSObject.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSFileCoordinator.h>

#import "XPCObject.h"

typedef NS_OPTIONS(NSUInteger, FileAccessRequestState) {
	FileAccessRequestIsOngoing  = 1 << 0,
	FileAccessRequestIsQueued   = 1 << 1,
	FileAccessRequestIsComplete = 1 << 2,
	FileAccessRequestDidFail    = 1 << 3,
};

typedef void (^FileAccessRequestWaiter)();
typedef void (^FileAccessQueueMemberWaiter)();

/**
 * Represents an individual request to access a file or directory to perform a given operation.
 *
 * Completion for this class fires when the operation has completed in the client.
 * Note that after completion fires, the class is still in use (we have to wait for presenters to be notified of completion).
 */
@interface FileAccessRequest : NSObject {
	BOOL _didFire;
	NSString* _path;
	NSUInteger _options;
	XPCMessage* _reply;
	NSString* _purposeIdentifier;
	FileAccessRequestState _state;
	BOOL _isDirectoryOperation;
	NSMutableSet<FileAccessRequestWaiter>* _waiters;
}

@property(copy) NSString* path;
@property() NSUInteger options;
@property(strong) XPCMessage* reply;
@property(copy) NSString* purposeIdentifier;
@property(readonly) BOOL isDirectoryOperation;
@property(readonly) BOOL isReadOperation;
@property(readonly) BOOL isWriteOperation;
@property() BOOL isOngoing;
@property() BOOL isQueued;
@property() BOOL isComplete;
@property() BOOL accessDidFail;
@property(readonly) XPCObject* initialPresenterMessageDetails;
@property(readonly) XPCObject* finalPresenterMessageDetails;
@property(readonly) NSFileCoordinatorReadingOptions readingOptions;
@property(readonly) NSFileCoordinatorWritingOptions writingOptions;

- (instancetype)initForPath: (NSString*)path withOptions: (NSUInteger)options reply: (XPCMessage*)reply purposeIdentifier: (NSString*)purposeIdentifier;
+ (instancetype)requestForPath: (NSString*)path withOptions: (NSUInteger)options reply: (XPCMessage*)reply purposeIdentifier: (NSString*)purposeIdentifier;

- (void)start;
- (void)cancel;
- (void)complete;

- (void)didFinishWaitingInQueue;
- (void)didFinishWaitingForOtherRequests;
- (void)didFinishWaitingForPresenters;
- (void)didFinishWaitingForPresentersAgain;

- (BOOL)needsToWaitFor: (FileAccessRequest*)request;
- (void)registerWaiter: (FileAccessRequestWaiter)waiter;

- (BOOL)isMoreRestrictiveThan: (FileAccessRequest*)request;
- (BOOL)canCooperateWith: (FileAccessRequest*)request;

/**
 * Indicates whether the given response from a presenter for the initial notification is 
 */
- (BOOL)canProceedWithPresenterResponse: (XPCObject*)presenterResponse;

@end

/**
 * Represents one or more cooperating requests that want to access a file or directory.
 *
 * Only certain operations can cooperate, and the conditions are different depending on whether we are waiting in the queue or are the ongoing operation.
 *
 * Completion for this class fires after all cooperating requests have completed their operations AND presenters have been notified of this.
 */
@interface FileAccessQueueMember : NSObject {
	BOOL _didFire;
	BOOL _isComplete;
	BOOL _isOngoing;
	BOOL _isAcceptingNewRequests;
	BOOL _didFinishWaitingForOthers;
	BOOL _didFinishWaitingForPresenters;
	BOOL _accessDidFail;
	NSUInteger _completedCount;
	NSMutableSet<FileAccessRequest*>* _cooperatingRequests;
	NSMutableSet<FileAccessRequestWaiter>* _waiters;
}

@property(readonly) BOOL isComplete;
@property(readonly) BOOL isOngoing;
@property(readonly) BOOL isAcceptingNewRequests;
@property(readonly) BOOL isDirectoryOperation;
@property(readonly) NSString* path;
@property(readonly) NSSet<FileAccessRequest*>* cooperatingRequests;
@property(readonly) FileAccessRequest* mostRestrictiveRequest;

- (BOOL)tryAddingRequest: (FileAccessRequest*)request;

// to be called by `FileAccessQueue` once this member is dequeued and should start performing operations
- (void)didFinishWaitingInQueue;
- (void)didFinishWaitingForOtherRequests;
- (void)didFinishWaitingForPresenters;
- (void)didFinishPerformingOperations;
- (void)didFinishWaitingForPresentersAgain;

- (void)singleOperationDidComplete;

- (BOOL)needsToWaitFor: (FileAccessQueueMember*)queueMember;
- (void)registerWaiter: (FileAccessRequestWaiter)waiter;

- (void)complete;

@end

/**
 * Represents a queue to wait for access to a file or directory.
 */
@interface FileAccessQueue : NSObject {
	NSString* _path;
	FileAccessQueueMember* _ongoingMember;
	NSMutableArray<FileAccessQueueMember*>* _members;
	NSMutableSet<FileAccessQueue*>* _children;
}

@property(readonly) FileAccessQueueMember* ongoingMember;
@property(readonly) NSString* path;
@property(readonly) NSSet<FileAccessQueue*>* immediateChildren;
@property(readonly) NSSet<FileAccessQueue*>* recursiveChildren;
@property(readonly) FileAccessQueue* parentQueue;

/**
 * Array of all parent queues, from most immediate to most distant (e.g. ["/foo/bar", "/foo", "/"]).
 */
@property(readonly) NSArray<FileAccessQueue*>* parentQueues;

/**
 * Initializes the queue for the given path. If a queue for the given path already exists, this method will
 * release `self` and return the existing queue.
 */
- (instancetype)initForPath: (NSString*)path;

/**
 * Returns the existing queue for the given path or creates it if it doesn't exist yet.
 */
+ (instancetype)queueForPath: (NSString*)path;

- (void)addRequest: (FileAccessRequest*)request;
- (FileAccessQueueMember*)peek;
- (void)enqueue: (FileAccessQueueMember*)member;
- (void)ongoingRequestDidFinish;

@end
