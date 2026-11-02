#import <Foundation/Foundation.h>
#include <errno.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

int main(void)
{
    @autoreleasepool {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSError *error = nil;
        NSString *missingPath = @"/tmp/nonexistent_file_for_setattributes_test_12345";
        
        // Remove file if it somehow exists
        unlink([missingPath fileSystemRepresentation]);
        
        BOOL success = [fm setAttributes:@{NSFilePosixPermissions: @0644} ofItemAtPath:missingPath error:&error];
        assert(!success);
        assert(error != nil);
        assert([[error domain] isEqualToString:NSPOSIXErrorDomain]);
        assert([error code] == ENOENT);
        assert([[error userInfo][NSFilePathErrorKey] isEqualToString:missingPath]);

        id underlying = [error userInfo][NSUnderlyingErrorKey];
        assert(underlying != nil);
        assert([underlying isKindOfClass:[NSError class]]);
        
        NSError *underlyingError = (NSError *)underlying;
        assert([[underlyingError domain] isEqualToString:NSPOSIXErrorDomain]);
        assert([underlyingError code] == ENOENT);
        
        // Calling NSError methods on the underlying error must not raise unrecognized selector
        (void)[underlyingError localizedFailureReason];
        (void)[underlyingError localizedRecoverySuggestion];
        assert([underlyingError localizedDescription] != nil);

        // Describing the outer error must not crash
        NSString *desc = [error description];
        assert(desc != nil && [desc length] > 0);
    }
    
    puts("PASS: NSFileManager setAttributes error stores NSError under NSUnderlyingErrorKey");
    return 0;
}
