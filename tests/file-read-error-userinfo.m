// Copyright (C) 2026 Lubos Dolezel
//
// The errors of reading a file with NSData and NSString: the code, and the userInfo, which has the path and the errno
// underneath (NSFilePath, NSUnderlyingError) and no NSLocalizedDescription of its own, so that the description comes from
// the code, as on the original. A missing file is NSFileReadNoSuchFileError (260), a file that cannot be read or a directory
// 257, a path below a regular file 256 (POSIX ENOTDIR), a dangling link 260, an empty path 258 with the path only, and a
// file that is not valid in the given text encoding 261 with NSFilePath and NSStringEncoding. Expected values are the black-box
// observations of macOS 10.14.4 (x86_64 and i386) in mac-probes/fileerrors (readprobe.m, readout.148-*.txt); macOS 26.7.3
// agrees but adds an NSURL key (the older system is followed). Runs as an ordinary user, with no window server.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

static int failures, checks;

static void expectThat(BOOL condition, NSString *what) {
    checks++;
    if (!condition) {
        failures++;
        printf("FAIL %s\n", [what UTF8String]);
    }
}

// error: expected code, expected POSIX errno underneath (0: none), expected path
static void expectError(NSString *what, NSError *e, NSInteger code, int posix, NSString *path) {
    expectThat(e != nil, [what stringByAppendingString:@": an error is returned"]);
    if (e == nil)
        return;
    expectThat([[e domain] isEqual:NSCocoaErrorDomain] && [e code] == code,
          [NSString stringWithFormat:@"%@: NSCocoaErrorDomain %ld, got %@ %ld", what, (long)code, [e domain], (long)[e code]]);
    NSDictionary *ui = [e userInfo];
    NSMutableSet *keys = [NSMutableSet setWithArray:[ui allKeys]];
    NSMutableSet *want = [NSMutableSet setWithObject:NSFilePathErrorKey];
    if (posix != 0)
        [want addObject:NSUnderlyingErrorKey];
    if (code == 261)
        [want addObject:NSStringEncodingErrorKey];
    expectThat([keys isEqual:want], [NSString stringWithFormat:@"%@: userInfo keys %@, got %@", what,
                                [[want allObjects] sortedArrayUsingSelector:@selector(compare:)],
                                [[keys allObjects] sortedArrayUsingSelector:@selector(compare:)]]);
    expectThat(ui[NSLocalizedDescriptionKey] == nil, [what stringByAppendingString:@": no NSLocalizedDescription in the userInfo"]);
    expectThat([ui[NSFilePathErrorKey] isEqual:path], [what stringByAppendingString:@": NSFilePath is the path"]);
    if (posix != 0) {
        NSError *u = ui[NSUnderlyingErrorKey];
        expectThat([[u domain] isEqual:NSPOSIXErrorDomain] && [u code] == posix,
              [NSString stringWithFormat:@"%@: underlying POSIX %d, got %@ %ld", what, posix, [u domain], (long)[u code]]);
    }
}

int main(void) {
    @autoreleasepool {
        NSString *D = [NSString stringWithFormat:@"/tmp/readerr.%d", getpid()];
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:D withIntermediateDirectories:YES attributes:nil error:NULL];
        NSString *(^P)(NSString *) = ^(NSString *rel) { return [D stringByAppendingPathComponent:rel]; };
        [fm createDirectoryAtPath:P(@"dir") withIntermediateDirectories:NO attributes:nil error:NULL];
        [@"x" writeToFile:P(@"file") atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        [@"secret" writeToFile:P(@"noread") atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        chmod([P(@"noread") fileSystemRepresentation], 0);
        [[NSData dataWithBytes:"\xff\xfe\xfa" length:3] writeToFile:P(@"badutf8") atomically:NO];
        symlink("nowhere", [P(@"dangling") fileSystemRepresentation]);

        struct { NSString *rel; NSInteger code; int posix; BOOL needsUser; } cases[] = {
            { @"missing", 260, 2, NO }, { @"dir", 257, 13, NO }, { @"noread", 257, 13, YES },
            { @"file/below", 256, 20, NO }, { @"dangling", 260, 2, NO },
        };
        for (size_t i = 0; i < sizeof cases / sizeof cases[0]; i++) {
            if (cases[i].needsUser && getuid() == 0)
                continue;
            NSString *rel = cases[i].rel, *path = P(rel);
            NSURL *url = [NSURL fileURLWithPath:path];
            NSError *e = nil;
            NSInteger code = cases[i].code;
            int posix = cases[i].posix;
            e = nil; expectThat([NSData dataWithContentsOfFile:path options:0 error:&e] == nil, @"read fails");
            expectError([@"dataWithContentsOfFile: " stringByAppendingString:rel], e, code, posix, path);
            e = nil; [NSData dataWithContentsOfURL:url options:0 error:&e];
            expectError([@"dataWithContentsOfURL: " stringByAppendingString:rel], e, code, posix, path);
            e = nil; [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&e];
            expectError([@"dataWithContentsOfFile:mapped " stringByAppendingString:rel], e, code, posix, path);
            e = nil; [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&e];
            expectError([@"stringWithContentsOfFile: " stringByAppendingString:rel], e, code, posix, path);
            e = nil; [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&e];
            expectError([@"stringWithContentsOfURL: " stringByAppendingString:rel], e, code, posix, path);
            e = nil; { NSStringEncoding enc; [NSString stringWithContentsOfFile:path usedEncoding:&enc error:&e]; }
            expectError([@"stringWithContentsOfFile:usedEncoding: " stringByAppendingString:rel], e, code, posix, path);
        }

        // An empty path is an invalid file name.
        NSError *e = nil;
        expectThat([NSData dataWithContentsOfFile:@"" options:0 error:&e] == nil, @"empty path fails");
        expectError(@"dataWithContentsOfFile: empty path", e, 258, 0, @"");
        e = nil;
        expectThat([NSString stringWithContentsOfFile:@"" encoding:NSUTF8StringEncoding error:&e] == nil, @"empty path fails for strings");
        expectError(@"stringWithContentsOfFile: empty path", e, 258, 0, @"");

        // A file that is not valid in the given encoding.
        e = nil;
        expectThat([NSString stringWithContentsOfFile:P(@"badutf8") encoding:NSUTF8StringEncoding error:&e] == nil, @"invalid UTF-8 fails");
        expectError(@"stringWithContentsOfFile: invalid UTF-8", e, 261, 0, P(@"badutf8"));
        expectThat([e userInfo][NSStringEncodingErrorKey] != nil && [[e userInfo][NSStringEncodingErrorKey] unsignedIntegerValue] == NSUTF8StringEncoding,
              @"the error names the encoding");

        // Reading what exists still works.
        e = nil;
        expectThat([[NSString stringWithContentsOfFile:P(@"file") encoding:NSUTF8StringEncoding error:&e] isEqual:@"x"] && e == nil, @"a file reads");

        chmod([P(@"noread") fileSystemRepresentation], 0600);
        [fm removeItemAtPath:D error:NULL];
    }
    printf("%d checks, %d failures\n", checks, failures);
    printf(failures ? "FAIL\n" : "PASS\n");
    return failures != 0;
}
