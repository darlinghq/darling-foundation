#import <Foundation/NSObject.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSHTTPCookieStorage.h>

#include <Security/SecureTransport.h>

typedef NS_ENUM(NSInteger, NSURLSessionTaskState) {
    NSURLSessionTaskStateRunning = 0,
    NSURLSessionTaskStateSuspended = 1,
    NSURLSessionTaskStateCanceling = 2,
    NSURLSessionTaskStateCompleted = 3,
};

typedef NS_ENUM(NSInteger, NSURLSessionAuthChallengeDisposition) {
    NSURLSessionAuthChallengeUseCredential = 0,
    NSURLSessionAuthChallengePerformDefaultHandling = 1,
    NSURLSessionAuthChallengeCancelAuthenticationChallenge = 2,
    NSURLSessionAuthChallengeRejectProtectionSpace = 3,
};

typedef NS_ENUM(NSInteger, NSURLSessionResponseDisposition) {
    NSURLSessionResponseCancel = 0,
    NSURLSessionResponseAllow = 1,
    NSURLSessionResponseBecomeDownload = 2,
};

NS_ASSUME_NONNULL_BEGIN

@class NSArray<ObjectType>;
@class NSCachedURLResponse, NSData, NSDictionary, NSError;
@class NSHTTPCookie, NSHTTPURLResponse, NSInputStream, NSOperationQueue;
@class NSString, NSURL, NSURLAuthenticationChallenge, NSURLCache;
@class NSURLCredential, NSURLCredentialStorage, NSURLProtectionSpace;
@class NSURLResponse, NSURLSession, NSURLSessionConfiguration;
@class NSURLSessionTask, NSURLSessionDataTask, NSURLSessionDownloadTask;
@class NSURLSessionUploadTask, NSURLSessionTaskMetrics, NSDateInterval;
@class NSURLSessionWebSocketTask, NSURLSessionWebSocketMessage;

@protocol NSURLSessionDelegate <NSObject>
@optional

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error;
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session;

@end

@protocol NSURLSessionTaskDelegate <NSURLSessionDelegate>
@optional

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge  completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))completionHandler;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error;
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics;

@end

@protocol NSURLSessionDataDelegate <NSURLSessionTaskDelegate>
@optional

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data;
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse  completionHandler:(void (^)(NSCachedURLResponse * _Nullable cachedResponse))completionHandler;

@end

@protocol NSURLSessionDownloadDelegate <NSURLSessionTaskDelegate>

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location;
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes;

@end

FOUNDATION_EXPORT const int64_t NSURLSessionTransferSizeUnknown;
FOUNDATION_EXPORT NSString * const NSURLSessionDownloadTaskResumeData;

/* Task priorities, a value between 0.0 (lowest) and 1.0 (highest). */
FOUNDATION_EXPORT const float NSURLSessionTaskPriorityDefault;
FOUNDATION_EXPORT const float NSURLSessionTaskPriorityLow;
FOUNDATION_EXPORT const float NSURLSessionTaskPriorityHigh;

@interface NSURLSession : NSObject

@property (readonly, retain) NSOperationQueue *delegateQueue;
@property (nullable, readonly, retain) id <NSURLSessionDelegate> delegate;
@property (readonly, copy) NSURLSessionConfiguration *configuration;
@property (nullable, copy) NSString *sessionDescription;

@property (class, readonly, strong) NSURLSession *sharedSession;
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration;
+ (NSURLSession *)sessionWithConfiguration:(NSURLSessionConfiguration *)configuration delegate:(nullable id <NSURLSessionDelegate>)delegate delegateQueue:(nullable NSOperationQueue *)queue;
- (void)finishTasksAndInvalidate;
- (void)invalidateAndCancel;
- (void)resetWithCompletionHandler:(void (^)(void))completionHandler;
- (void)flushWithCompletionHandler:(void (^)(void))completionHandler;
- (void)getTasksWithCompletionHandler:(void (^)(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks))completionHandler;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData;
- (NSURLSessionUploadTask *)uploadTaskWithStreamedRequest:(NSURLRequest *)request;
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request;
- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url;
- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData;

@end

@interface NSURLSession (NSURLSessionAsynchronousConvenience)

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionDownloadTask *)downloadTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;
- (NSURLSessionDownloadTask *)downloadTaskWithResumeData:(NSData *)resumeData completionHandler:(void (^)(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

@interface NSURLSessionTask : NSObject <NSCopying>

@property (readonly) NSUInteger taskIdentifier;
@property (nullable, readonly, copy) NSURLRequest *originalRequest;
@property (nullable, readonly, copy) NSURLRequest *currentRequest;
@property (nullable, readonly, copy) NSURLResponse *response;
@property (readonly) int64_t countOfBytesReceived;
@property (readonly) int64_t countOfBytesSent;
@property (readonly) int64_t countOfBytesExpectedToSend;
@property (readonly) int64_t countOfBytesExpectedToReceive;
@property (nullable, copy) NSString *taskDescription;
@property (readonly) NSURLSessionTaskState state;
@property float priority;
@property (nullable, readonly, copy) NSError *error;
/* A delegate for this task alone, retained until the task completes: it gets
   the task's delegate messages that it implements, and the session's
   delegate gets the others. */
@property (nullable, retain) id <NSURLSessionTaskDelegate> delegate;

- (void)cancel;
- (void)suspend;
- (void)resume;

@end

@interface NSURLSessionDataTask : NSURLSessionTask
@end

@interface NSURLSessionUploadTask : NSURLSessionDataTask
@end

@interface NSURLSessionDownloadTask : NSURLSessionTask

- (void)cancelByProducingResumeData:(void (^)(NSData * _Nullable resumeData))completionHandler;

@end

typedef NS_ENUM(NSInteger, NSURLSessionMultipathServiceType) {
    NSURLSessionMultipathServiceTypeNone = 0,
    NSURLSessionMultipathServiceTypeHandover = 1,
    NSURLSessionMultipathServiceTypeInteractive = 2,
    NSURLSessionMultipathServiceTypeAggregate = 3,
};

@interface NSURLSessionConfiguration : NSObject <NSCopying>

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration;
+ (NSURLSessionConfiguration *)backgroundSessionConfiguration:(NSString *)identifier;

@property(class, readonly, strong) NSURLSessionConfiguration *defaultSessionConfiguration;

@property (nullable, readonly, copy) NSString *identifier;
@property NSURLRequestCachePolicy requestCachePolicy;
@property NSTimeInterval timeoutIntervalForRequest;
@property NSTimeInterval timeoutIntervalForResource;
@property NSURLRequestNetworkServiceType networkServiceType;
@property BOOL allowsCellularAccess;
@property (getter=isDiscretionary) BOOL discretionary;
@property BOOL sessionSendsLaunchEvents;
@property (nullable, copy) NSDictionary *connectionProxyDictionary;
@property SSLProtocol TLSMinimumSupportedProtocol;
@property SSLProtocol TLSMaximumSupportedProtocol;
@property BOOL HTTPShouldUsePipelining;
@property BOOL HTTPShouldSetCookies;
@property NSHTTPCookieAcceptPolicy HTTPCookieAcceptPolicy;
@property (nullable, copy) NSDictionary *HTTPAdditionalHeaders;
@property NSInteger HTTPMaximumConnectionsPerHost;
@property (nullable, retain) NSHTTPCookieStorage *HTTPCookieStorage;
@property (nullable, retain) NSURLCredentialStorage *URLCredentialStorage;
@property (nullable, retain) NSURLCache *URLCache;
@property (nullable, copy) NSArray *protocolClasses;
@property BOOL waitsForConnectivity;
@property BOOL allowsExpensiveNetworkAccess;
@property BOOL allowsConstrainedNetworkAccess;
@property BOOL requiresDNSSECValidation;
@property NSURLSessionMultipathServiceType multipathServiceType;
@property BOOL shouldUseExtendedBackgroundIdleMode;
@property (copy) NSString *sharedContainerIdentifier;
/* tls_protocol_version_t values (TLS 1.2 is 0x0303). */
@property uint16_t TLSMinimumSupportedProtocolVersion;
@property uint16_t TLSMaximumSupportedProtocolVersion;

@end

@interface NSURLSession (NSURLSessionDeprecated)

/* Use -dataTaskWithURL: instead */
- (NSURLSessionDataTask *)dataTaskWithHTTPGetRequest:(NSURL *)url;

/* Use -dataTaskWithURL:completionHandler: instead */
- (NSURLSessionDataTask *)dataTaskWithHTTPGetRequest:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler;

@end

typedef NS_ENUM(NSInteger, NSURLSessionWebSocketMessageType) {
    NSURLSessionWebSocketMessageTypeData = 0,
    NSURLSessionWebSocketMessageTypeString = 1,
};

/* A message sent or received on a WebSocket connection: binary data or a string. */
@interface NSURLSessionWebSocketMessage : NSObject {
@private
    NSURLSessionWebSocketMessageType _type;
    NSData *_data;
    NSString *_string;
}

- (instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithString:(NSString *)string NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (readonly) NSURLSessionWebSocketMessageType type;
@property (nullable, readonly, copy) NSData *data;
@property (nullable, readonly, copy) NSString *string;

@end

typedef NS_ENUM(NSInteger, NSURLSessionTaskMetricsResourceFetchType) {
    NSURLSessionTaskMetricsResourceFetchTypeUnknown,
    NSURLSessionTaskMetricsResourceFetchTypeNetworkLoad,
    NSURLSessionTaskMetricsResourceFetchTypeServerPush,
    NSURLSessionTaskMetricsResourceFetchTypeLocalCache,
};

typedef NS_ENUM(NSInteger, NSURLSessionTaskMetricsDomainResolutionProtocol) {
    NSURLSessionTaskMetricsDomainResolutionProtocolUnknown,
    NSURLSessionTaskMetricsDomainResolutionProtocolUDP,
    NSURLSessionTaskMetricsDomainResolutionProtocolTCP,
    NSURLSessionTaskMetricsDomainResolutionProtocolTLS,
    NSURLSessionTaskMetricsDomainResolutionProtocolHTTPS,
};

/* Timings and details of one request-response transaction of a task. A value
   that was not measured is nil, or 0 for the counts. */
@interface NSURLSessionTaskTransactionMetrics : NSObject

@property (copy, readonly) NSURLRequest *request;
@property (nullable, copy, readonly) NSURLResponse *response;
@property (nullable, copy, readonly) NSDate *fetchStartDate;
@property (nullable, copy, readonly) NSDate *domainLookupStartDate;
@property (nullable, copy, readonly) NSDate *domainLookupEndDate;
@property (nullable, copy, readonly) NSDate *connectStartDate;
@property (nullable, copy, readonly) NSDate *secureConnectionStartDate;
@property (nullable, copy, readonly) NSDate *secureConnectionEndDate;
@property (nullable, copy, readonly) NSDate *connectEndDate;
@property (nullable, copy, readonly) NSDate *requestStartDate;
@property (nullable, copy, readonly) NSDate *requestEndDate;
@property (nullable, copy, readonly) NSDate *responseStartDate;
@property (nullable, copy, readonly) NSDate *responseEndDate;
@property (nullable, copy, readonly) NSString *networkProtocolName;
@property (assign, readonly, getter=isProxyConnection) BOOL proxyConnection;
@property (assign, readonly, getter=isReusedConnection) BOOL reusedConnection;
@property (assign, readonly) NSURLSessionTaskMetricsResourceFetchType resourceFetchType;
@property (readonly) int64_t countOfRequestHeaderBytesSent;
@property (readonly) int64_t countOfRequestBodyBytesSent;
@property (readonly) int64_t countOfRequestBodyBytesBeforeEncoding;
@property (readonly) int64_t countOfResponseHeaderBytesReceived;
@property (readonly) int64_t countOfResponseBodyBytesReceived;
@property (readonly) int64_t countOfResponseBodyBytesAfterDecoding;
@property (nullable, copy, readonly) NSString *localAddress;
@property (nullable, copy, readonly) NSNumber *localPort;
@property (nullable, copy, readonly) NSString *remoteAddress;
@property (nullable, copy, readonly) NSNumber *remotePort;
@property (nullable, copy, readonly) NSNumber *negotiatedTLSProtocolVersion;
@property (nullable, copy, readonly) NSNumber *negotiatedTLSCipherSuite;
@property (readonly, getter=isCellular) BOOL cellular;
@property (readonly, getter=isExpensive) BOOL expensive;
@property (readonly, getter=isConstrained) BOOL constrained;
@property (readonly, getter=isMultipath) BOOL multipath;
@property (readonly) NSURLSessionTaskMetricsDomainResolutionProtocol domainResolutionProtocol;

@end

/* What a task's delegate is given when the task finishes. */
@interface NSURLSessionTaskMetrics : NSObject {
    // i386 has no synthesized instance variables; CFNetwork implements this.
    NSDateInterval *_taskInterval;
    NSUInteger _redirectCount;
}

@property (copy, readonly) NSArray<NSURLSessionTaskTransactionMetrics *> *transactionMetrics;
@property (copy, readonly) NSDateInterval *taskInterval;
@property (assign, readonly) NSUInteger redirectCount;

@end

/* Close codes of RFC 6455, section 7.4.1. */
typedef NS_ENUM(NSInteger, NSURLSessionWebSocketCloseCode) {
    NSURLSessionWebSocketCloseCodeInvalid = 0,
    NSURLSessionWebSocketCloseCodeNormalClosure = 1000,
    NSURLSessionWebSocketCloseCodeGoingAway = 1001,
    NSURLSessionWebSocketCloseCodeProtocolError = 1002,
    NSURLSessionWebSocketCloseCodeUnsupportedData = 1003,
    NSURLSessionWebSocketCloseCodeNoStatusReceived = 1005,
    NSURLSessionWebSocketCloseCodeAbnormalClosure = 1006,
    NSURLSessionWebSocketCloseCodeInvalidFramePayloadData = 1007,
    NSURLSessionWebSocketCloseCodePolicyViolation = 1008,
    NSURLSessionWebSocketCloseCodeMessageTooBig = 1009,
    NSURLSessionWebSocketCloseCodeMandatoryExtensionMissing = 1010,
    NSURLSessionWebSocketCloseCodeInternalServerError = 1011,
    NSURLSessionWebSocketCloseCodeTLSHandshakeFailure = 1015,
};

/* A task that talks WebSocket (RFC 6455) with a server. Messages sent before
   the connection opens wait for it; the handlers of the methods below are
   called on the session's delegate queue. */
@interface NSURLSessionWebSocketTask : NSURLSessionTask

- (void)sendMessage:(NSURLSessionWebSocketMessage *)message completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)receiveMessageWithCompletionHandler:(void (^)(NSURLSessionWebSocketMessage * _Nullable message, NSError * _Nullable error))completionHandler;
- (void)sendPingWithPongReceiveHandler:(void (^)(NSError * _Nullable error))pongReceiveHandler;
- (void)cancelWithCloseCode:(NSURLSessionWebSocketCloseCode)closeCode reason:(nullable NSData *)reason;

/* The largest message the task receives, in bytes; a larger one ends the task. */
@property NSInteger maximumMessageSize;
/* The code and reason of the close: the server's, or those of cancelWithCloseCode:reason:. */
@property (readonly) NSURLSessionWebSocketCloseCode closeCode;
@property (nullable, readonly, copy) NSData *closeReason;

@end

@protocol NSURLSessionWebSocketDelegate <NSURLSessionTaskDelegate>
@optional

- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didOpenWithProtocol:(nullable NSString *)protocol;
- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didCloseWithCode:(NSURLSessionWebSocketCloseCode)closeCode reason:(nullable NSData *)reason;

@end

@interface NSURLSession (NSURLSessionWebSocket)

/* The URL's scheme is ws or wss. */
- (NSURLSessionWebSocketTask *)webSocketTaskWithURL:(NSURL *)url;
/* Offers the subprotocols to the server, in order of preference. */
- (NSURLSessionWebSocketTask *)webSocketTaskWithURL:(NSURL *)url protocols:(NSArray<NSString *> *)protocols;
- (NSURLSessionWebSocketTask *)webSocketTaskWithRequest:(NSURLRequest *)request;

@end

NS_ASSUME_NONNULL_END
