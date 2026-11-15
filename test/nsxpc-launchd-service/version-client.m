// Run against the nsxpc-launchd-service (launchd must have it loaded). Two checks of the NSXPC version and error handling
// that need a service in another process:
// - a connection that has been told its peer speaks bplist17 sends 7 and gets its reply in 7: the connection remembers
//   the digit of the last data it received, so it reads 7 after the reply only if both the request and the reply were
//   written in 7 (7 is what Apple's Foundation speaks); an ordinary connection stays on 6;
// - a message the service's interface does not know (an unknown selector) invalidates that connection only: another
//   connection is still answered afterwards, by the same process (a crashed service would be restarted with a new ID).
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#import "common.m"

@interface NSXPCConnection (VersionPrivate)
- (unsigned char)_peerBplistVersion;
- (void)_setPeerBplistVersion: (unsigned char)version;
@end

@protocol NotExported
- (void)thisSelectorIsNotExportedByTheService;
@end

static void expect(BOOL condition, NSString* what)
{
	if (!condition) {
		NSLog(@"FAIL: %@", what);
		exit(1);
	}
}

static NSXPCConnection* connect(Protocol* protocol, NSXPCInterface* interface)
{
	NSXPCConnection* connection = [[NSXPCConnection alloc] initWithMachServiceName: @NSXPC_TEST_LAUNCHD_SERVICE_NAME];
	connection.remoteObjectInterface = interface != nil ? interface : [NSXPCInterface interfaceWithProtocol: protocol];
	[connection resume];
	return connection;
}

static BOOL askForNonsense(NSXPCConnection* connection)
{
	dispatch_semaphore_t answered = dispatch_semaphore_create(0);
	__block BOOL got = NO;
	[[connection remoteObjectProxy] generateNonsense: ^(NSString* nonsense) {
		got = nonsense.length > 0;
		dispatch_semaphore_signal(answered);
	}];
	return dispatch_semaphore_wait(answered, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0 && got;
}

int main(void)
{
	@autoreleasepool {
		NSXPCConnection* plain = connect(nil, generateServiceInterface());
		expect(askForNonsense(plain), @"an ordinary request is answered");
		pid_t servicePid = plain.processIdentifier;
		expect(servicePid > 0, @"the service's process ID is known");
		expect([plain _peerBplistVersion] == '6', [NSString stringWithFormat: @"Darling to Darling stays on version 6, saw %c", [plain _peerBplistVersion]]);

		NSXPCConnection* seven = connect(nil, generateServiceInterface());
		[seven _setPeerBplistVersion: '7'];
		expect(askForNonsense(seven), @"a version 7 request is understood and answered");
		expect([seven _peerBplistVersion] == '7', [NSString stringWithFormat: @"request and reply were written in version 7, the client read %c after the reply", [seven _peerBplistVersion]]);

		dispatch_semaphore_t closed = dispatch_semaphore_create(0);
		NSXPCConnection* bad = connect(@protocol(NotExported), nil);
		bad.invalidationHandler = ^{ dispatch_semaphore_signal(closed); };
		bad.interruptionHandler = ^{ dispatch_semaphore_signal(closed); };
		[[bad remoteObjectProxy] thisSelectorIsNotExportedByTheService];
		expect(dispatch_semaphore_wait(closed, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)) == 0,
		       @"the connection that sent an unknown selector was closed by the service");

		NSXPCConnection* after = connect(nil, generateServiceInterface());
		expect(askForNonsense(after), @"the service still answers other clients");
		expect(after.processIdentifier == servicePid, [NSString stringWithFormat: @"the same service process answers (it did not crash and restart): %d then %d", servicePid, after.processIdentifier]);
		NSLog(@"PASS: the NSXPC version is kept per connection and a bad message closes only its connection");
	}
	return 0;
}
