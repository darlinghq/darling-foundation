#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>

@class NSString, NSArray<ObjectType>, NSDictionary<KeyType, ObjectType>, NSURL;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const NSTaskDidTerminateNotification;

typedef NS_ENUM(NSInteger, NSTaskTerminationReason) {
    NSTaskTerminationReasonExit = 1,
    NSTaskTerminationReasonUncaughtSignal = 2
};

@interface NSTask : NSObject

@property (nullable, copy) NSURL *executableURL;
@property (nullable, copy) NSArray<NSString *> *arguments;
@property (nullable, copy) NSDictionary<NSString *, NSString *> *environment;
@property (nullable, copy) NSURL *currentDirectoryURL;

@property (nullable, retain) id standardInput;
@property (nullable, retain) id standardOutput;
@property (nullable, retain) id standardError;

@property (readonly) int processIdentifier;
@property (readonly, getter=isRunning) BOOL running;

@property (readonly) int terminationStatus;
@property (readonly) NSTaskTerminationReason terminationReason;

@property (nullable, copy) void (^terminationHandler)(NSTask *);

@property NSQualityOfService qualityOfService;

@property (nullable, copy) NSString *launchPath;
@property (copy) NSString *currentDirectoryPath;

- (instancetype)init;

- (BOOL)launchAndReturnError:(out NSError **_Nullable)error ;

- (void)interrupt;
- (void)terminate;

- (BOOL)suspend;
- (BOOL)resume;

+ (nullable NSTask *)launchedTaskWithExecutableURL:(NSURL *)url
	arguments:(NSArray<NSString *> *)arguments
	error:(out NSError ** _Nullable)error
	terminationHandler:(void (^_Nullable)(NSTask *))terminationHandler;

- (void)waitUntilExit;

- (void)launch;

+ (NSTask *)launchedTaskWithLaunchPath:(NSString *)path arguments:(NSArray<NSString *> *)arguments;

@end

NS_ASSUME_NONNULL_END
