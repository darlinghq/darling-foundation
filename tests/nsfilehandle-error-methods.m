/*
 * This file is part of Darling.
 *
 * Copyright (C) 2026 Lubos Dolezel
 *
 * Darling is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Darling is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Darling.  If not, see <http://www.gnu.org/licenses/>.

/*
 * NSFileHandle's error-returning methods (macOS 10.15).
 *
 * Expected results were observed on macOS 26.7.3: failures are NSCocoaErrorDomain errors whose
 * only user info entry is NSUnderlyingError, the POSIX error of the failed call. The Cocoa code
 * is NSFileReadUnknownError (256) for reading and positioning and NSFileWriteUnknownError (512)
 * for writing, truncating and synchronizing, or the dedicated file error code for the POSIX
 * error (a closed handle makes macOS report whatever errno held, observed as ENOENT mapping to
 * 260 and as 256). Closing never fails, also when repeated.
 * macOS 10.14 has no such methods: the test passes there without checking anything (it
 * is skipped when the reported system version is older than 10.15).
 */
#import <Foundation/Foundation.h>
#include <errno.h>
#include <unistd.h>

@interface NSFileHandle (Probe)
- (NSData *)readDataToEndOfFileAndReturnError:(NSError **)e;
- (NSData *)readDataUpToLength:(NSUInteger)l error:(NSError **)e;
- (BOOL)writeData:(NSData *)d error:(NSError **)e;
- (BOOL)getOffset:(unsigned long long *)o error:(NSError **)e;
- (BOOL)seekToEndReturningOffset:(unsigned long long *)o error:(NSError **)e;
- (BOOL)seekToOffset:(unsigned long long)o error:(NSError **)e;
- (BOOL)truncateAtOffset:(unsigned long long)o error:(NSError **)e;
- (BOOL)synchronizeAndReturnError:(NSError **)e;
- (BOOL)closeAndReturnError:(NSError **)e;
@end

static int failures;
#define CHECK(cond, ...) do { if (cond) printf("PASS "); else { printf("FAIL "); failures++; } printf(__VA_ARGS__); printf("\n"); } while (0)

/* posix 0: any POSIX underlying error (macOS reports whatever errno held for a closed handle,
   and maps it to the Cocoa code, so the code can be one of those for the reading or writing side) */
static BOOL isError(NSError *e, NSInteger cocoaCode, int posix)
{
	NSError *u = e.userInfo[NSUnderlyingErrorKey];
	BOOL codeOk = posix != 0 ? e.code == cocoaCode :
	              cocoaCode == NSFileReadUnknownError ? (e.code == 256 || e.code == 257 || e.code == 260) :
	                                                    (e.code == 512 || e.code == 513 || e.code == 4 || e.code == 640 || e.code == 642);
	return [e.domain isEqual:NSCocoaErrorDomain] && codeOk && e.userInfo.count == 1 &&
	       [u.domain isEqual:NSPOSIXErrorDomain] && (posix == 0 || u.code == posix);
}

int main(void)
{
	@autoreleasepool {
		if (![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){ 10, 15, 0 }]) {
			printf("PASS: the error-returning NSFileHandle methods are macOS 10.15 API, nothing to check here\n");
			return 0;
		}
		CHECK([NSFileHandle instancesRespondToSelector:@selector(readDataToEndOfFileAndReturnError:)], "the error-returning methods exist");
		NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"fh-errors.%d", getpid()]];
		[@"hello world" writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:NULL];

		NSFileHandle *h = [NSFileHandle fileHandleForUpdatingAtPath:path];
		NSError *e = nil;
		unsigned long long off = 99;
		NSData *d = [h readDataUpToLength:5 error:&e];
		CHECK(e == nil && [d isEqualToData:[NSData dataWithBytes:"hello" length:5]], "readDataUpToLength:error: reads 5 bytes");
		CHECK([h getOffset:&off error:&e] && off == 5, "getOffset:error: reports 5");
		CHECK([h seekToEndReturningOffset:&off error:&e] && off == 11, "seekToEndReturningOffset:error: reports 11");
		d = [h readDataToEndOfFileAndReturnError:&e];
		CHECK(d != nil && d.length == 0 && e == nil, "reading at end of file gives empty data, no error");
		CHECK([h seekToOffset:2 error:&e] && [h writeData:[NSData dataWithBytes:"XY" length:2] error:&e] &&
		      [h truncateAtOffset:4 error:&e] && [h synchronizeAndReturnError:&e], "seek, write, truncate and synchronize succeed");
		CHECK([[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] isEqual:@"heXY"], "the file holds the expected bytes");
		CHECK([h writeData:[NSData data] error:NULL] && [h getOffset:NULL error:NULL], "NULL out parameters are accepted");

		CHECK([h closeAndReturnError:&e] && e == nil, "closeAndReturnError: succeeds");
		CHECK([h closeAndReturnError:&e] && e == nil, "closing again also succeeds");

		e = nil; d = [h readDataToEndOfFileAndReturnError:&e];
		CHECK(d == nil && isError(e, NSFileReadUnknownError, 0), "read to end after close (%s)", [[e description] UTF8String]);
		e = nil; d = [h readDataUpToLength:3 error:&e];
		CHECK(d == nil && isError(e, NSFileReadUnknownError, 0), "readDataUpToLength after close");
		e = nil; CHECK(![h writeData:[NSData dataWithBytes:"a" length:1] error:&e] && isError(e, NSFileWriteUnknownError, 0), "write after close");
		off = 7; e = nil; CHECK(![h getOffset:&off error:&e] && isError(e, NSFileReadUnknownError, 0) && off == 7, "getOffset after close leaves the out value alone");
		off = 7; e = nil; CHECK(![h seekToEndReturningOffset:&off error:&e] && isError(e, NSFileReadUnknownError, 0) && off == 7, "seekToEnd after close");
		e = nil; CHECK(![h seekToOffset:0 error:&e] && isError(e, NSFileReadUnknownError, 0), "seekToOffset after close");
		e = nil; CHECK(![h truncateAtOffset:0 error:&e] && isError(e, NSFileWriteUnknownError, 0), "truncate after close");
		e = nil; CHECK(![h synchronizeAndReturnError:&e] && isError(e, NSFileWriteUnknownError, 0), "synchronize after close");
		CHECK(![h writeData:[NSData dataWithBytes:"a" length:1] error:NULL], "NULL error out parameter on failure");

		NSFileHandle *ro = [NSFileHandle fileHandleForReadingAtPath:path];
		e = nil; CHECK(![ro writeData:[NSData dataWithBytes:"a" length:1] error:&e] && isError(e, 512, EBADF), "write on a read-only handle: EBADF");
		e = nil; CHECK(![ro truncateAtOffset:0 error:&e] && isError(e, 512, EINVAL), "truncate on a read-only handle: EINVAL");
		[ro closeFile];

		NSPipe *pipe = [NSPipe pipe];
		e = nil; CHECK(![pipe.fileHandleForReading seekToOffset:0 error:&e] && isError(e, 256, ESPIPE), "seek on a pipe: ESPIPE");
		off = 7; e = nil; CHECK(![pipe.fileHandleForReading getOffset:&off error:&e] && isError(e, 256, ESPIPE), "getOffset on a pipe: ESPIPE");

		/* the exception-raising forms still raise, with the same exception name */
		BOOL raised = NO;
		@try { [h readDataToEndOfFile]; } @catch (NSException *x) { raised = [x.name isEqual:@"NSFileHandleOperationException"]; }
		CHECK(raised, "readDataToEndOfFile on a closed handle still raises NSFileHandleOperationException");
		[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	}
	printf("%s\n", failures ? "FAILED" : "PASS: NSFileHandle error-returning methods");
	return failures != 0;
}
