/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * NSFileManager destinationOfSymbolicLinkAtPath:error: returns the stored link
 * text (not a resolved path); a relative or dangling target is reported as is,
 * the legacy pathContentOfSymbolicLinkAtPath: agrees, and a non-link fails with
 * a POSIX error.
 */
#import <Foundation/Foundation.h>
#undef NDEBUG
#include <assert.h>
#include <stdlib.h>
#include <unistd.h>

int main(void)
{
    @autoreleasepool {
        char tmpl[] = "/tmp/link-destination-XXXXXX";
        assert(mkdtemp(tmpl) != NULL);
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dir = [fm stringWithFileSystemRepresentation:tmpl length:strlen(tmpl)];
        NSString *link = [dir stringByAppendingPathComponent:@"link"];
        NSString *dangling = [dir stringByAppendingPathComponent:@"dangling"];
        NSString *plain = [dir stringByAppendingPathComponent:@"plain"];

        assert(symlink("target/../file", [link fileSystemRepresentation]) == 0);
        assert(symlink("/nonexistent/destination", [dangling fileSystemRepresentation]) == 0);
        assert([@"x" writeToFile:plain atomically:NO encoding:NSUTF8StringEncoding error:NULL]);

        NSError *error = nil;
        assert([[fm destinationOfSymbolicLinkAtPath:link error:&error] isEqualToString:@"target/../file"]);
        assert(error == nil);
        assert([[fm destinationOfSymbolicLinkAtPath:dangling error:&error] isEqualToString:@"/nonexistent/destination"]);
        assert([[fm pathContentOfSymbolicLinkAtPath:link] isEqualToString:@"target/../file"]);

        error = nil;
        assert([fm destinationOfSymbolicLinkAtPath:plain error:&error] == nil);
        assert(error != nil && [[error domain] isEqualToString:NSPOSIXErrorDomain]);
        assert([fm pathContentOfSymbolicLinkAtPath:plain] == nil);
        assert([fm destinationOfSymbolicLinkAtPath:[dir stringByAppendingPathComponent:@"missing"] error:NULL] == nil);

        [fm removeItemAtPath:dir error:NULL];
        printf("PASS\n");
    }
    return 0;
}
