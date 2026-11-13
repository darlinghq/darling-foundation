// Darling's own NSFileCoordinator (Darling's Foundation, no dyld shared cache) coordinates a write and a read of a file
// through filecoordinationd: the accessors run, nothing fails, and two coordinations in a row work. This must keep
// working while the daemon also answers Apple's NSXPC protocol for clients on Apple's Foundation.
#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString* what)
{
	if (!condition) {
		NSLog(@"FAIL: %@", what);
		exit(1);
	}
}

int main(void)
{
	@autoreleasepool {
		NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent: [[NSProcessInfo processInfo] globallyUniqueString]];
		NSURL* url = [NSURL fileURLWithPath: path];
		NSFileCoordinator* coordinator = [[[NSFileCoordinator alloc] initWithFilePresenter: nil] autorelease];

		for (int round = 0; round < 2; round++) {
			NSError* error = nil;
			__block BOOL wrote = NO;
			NSString* text = [NSString stringWithFormat: @"round %d", round];
			[coordinator coordinateWritingItemAtURL: url options: 0 error: &error byAccessor: ^(NSURL* writeURL) {
				wrote = [text writeToURL: writeURL atomically: NO encoding: NSUTF8StringEncoding error: NULL];
			}];
			expect(error == nil, [NSString stringWithFormat: @"coordinated write %d failed: %@", round, error]);
			expect(wrote, @"the write accessor ran and wrote");

			__block NSString* read = nil;
			[coordinator coordinateReadingItemAtURL: url options: 0 error: &error byAccessor: ^(NSURL* readURL) {
				read = [NSString stringWithContentsOfURL: readURL encoding: NSUTF8StringEncoding error: NULL];
			}];
			expect(error == nil, [NSString stringWithFormat: @"coordinated read %d failed: %@", round, error]);
			expect([read isEqualToString: text], [NSString stringWithFormat: @"the read accessor saw %@, expected %@", read, text]);
		}
		[[NSFileManager defaultManager] removeItemAtPath: path error: NULL];
		NSLog(@"PASS: NSFileCoordinator coordinated writes and reads through filecoordinationd");
	}
	return 0;
}
