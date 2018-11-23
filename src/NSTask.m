#import <Foundation/NSTask.h>

const NSNotificationName NSTaskDidTerminateNotification = @"NSTaskDidTerminateNotification";

@implementation NSTask

- (instancetype)init
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return [super init];
}

- (BOOL)launchAndReturnError:(out NSError **_Nullable)error
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return NO;
}

- (void)interrupt
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
}

- (void)terminate
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
}

- (BOOL)suspend
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return NO;
}

- (BOOL)resume
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return NO;
}

+ (nullable NSTask *)launchedTaskWithExecutableURL:(NSURL *)url
	arguments:(NSArray<NSString *> *)arguments
	error:(out NSError ** _Nullable)error
	terminationHandler:(void (^_Nullable)(NSTask *))terminationHandler
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return nil;
}

- (void)waitUntilExit
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
}

- (void)launch
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
}

+ (NSTask *)launchedTaskWithLaunchPath:(NSString *)path arguments:(NSArray<NSString *> *)arguments
{
	NSLog(@"NSTask %@", NSStringFromSelector(_cmd));
	return nil;
}

@end
