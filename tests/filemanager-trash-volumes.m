// Copyright (C) 2026 Lubos Dolezel
// filemanager-trash-volumes <dir on the home volume> <dir on another volume> <file on a read-only volume>:
// NSTrashDirectory and -[NSFileManager trashItemAtURL:resultingItemURL:error:] on the home volume and on others.
// The other volume's trash, <mount point>/.Trashes/<uid>, must not exist yet. Prints "mount point: <path>" for the
// other volume, "FAIL: ..." for each check that does not hold, and exits 1 if any did. Removes what it trashed in
// the home trash. The behaviour is described in darling's tests/volumes.md.
#import <Foundation/Foundation.h>
#include <errno.h>
#include <sys/mount.h>
#include <unistd.h>

static int failures;

static void expect(BOOL ok, NSString *what)
{
    if (!ok)
    {
        printf("FAIL: %s\n", [what UTF8String]);
        failures++;
    }
}

static BOOL isPOSIXError(NSError *error, int code)
{
    return [error.domain isEqual:NSPOSIXErrorDomain] && error.code == code;
}

static NSURL *makeItem(NSString *dir, NSString *name, BOOL folder)
{
    NSString *path = [dir stringByAppendingPathComponent:name];
    if (folder)
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:NULL];
    else
        [[NSData data] writeToFile:path atomically:NO];
    return [NSURL fileURLWithPath:path];
}

int main(int argc, char **argv)
{
    if (argc != 4)
    {
        fprintf(stderr, "usage: filemanager-trash-volumes <home dir> <other volume dir> <read-only file>\n");
        return 2;
    }
    @autoreleasepool
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *homeDir = [NSString stringWithUTF8String:argv[1]];
        NSString *otherDir = [NSString stringWithUTF8String:argv[2]];
        NSString *readOnly = [NSString stringWithUTF8String:argv[3]];
        NSString *homeTrash = [NSHomeDirectory() stringByAppendingPathComponent:@".Trash"];
        NSError *error = nil;

        NSURL *trash = [fm URLForDirectory:NSTrashDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
        expect([trash.path isEqual:homeTrash], [NSString stringWithFormat:@"the trash is %@ (%@)", trash.path, error]);
        trash = [fm URLForDirectory:NSTrashDirectory inDomain:NSUserDomainMask appropriateForURL:[NSURL fileURLWithPath:homeDir] create:NO error:&error];
        expect([trash.path isEqual:homeTrash], [NSString stringWithFormat:@"the home volume's trash is %@ (%@)", trash.path, error]);
        NSArray *trashes = [fm URLsForDirectory:NSTrashDirectory inDomains:NSUserDomainMask];
        expect(trashes.count == 1 && [[trashes[0] path] isEqual:homeTrash], [NSString stringWithFormat:@"URLsForDirectory gives %@", trashes]);

        // the other volume
        struct statfs st;
        if (statfs([otherDir fileSystemRepresentation], &st) != 0)
        {
            printf("FAIL: cannot statfs %s\n", argv[2]);
            return 1;
        }
        printf("mount point: %s\n", st.f_mntonname);
        NSString *otherTrash = [NSString stringWithFormat:@"%s/.Trashes/%u", st.f_mntonname, getuid()];
        NSURL *otherItem = makeItem(otherDir, @"other.txt", NO);

        error = nil;
        trash = [fm URLForDirectory:NSTrashDirectory inDomain:NSUserDomainMask appropriateForURL:otherItem create:NO error:&error];
        expect(trash == nil && [error.domain isEqual:NSCocoaErrorDomain] && error.code == NSFeatureUnsupportedError
            && isPOSIXError(error.userInfo[NSUnderlyingErrorKey], ENOENT),
            [NSString stringWithFormat:@"the other volume's trash before use is %@, %@", trash.path, error]);

        NSURL *result = nil;
        error = nil;
        BOOL ok = [fm trashItemAtURL:otherItem resultingItemURL:&result error:&error];
        expect(ok && [result.path isEqual:[otherTrash stringByAppendingPathComponent:@"other.txt"]],
            [NSString stringWithFormat:@"trashing on the other volume gives %d, %@, %@", ok, result.path, error]);
        expect(![fm fileExistsAtPath:otherItem.path], @"the other volume's item is still there");
        trash = [fm URLForDirectory:NSTrashDirectory inDomain:NSUserDomainMask appropriateForURL:[NSURL fileURLWithPath:otherDir] create:NO error:&error];
        expect([trash.path isEqual:otherTrash], [NSString stringWithFormat:@"the other volume's trash is %@", trash.path]);
        [fm removeItemAtURL:result error:NULL];

        // errors
        error = nil;
        ok = [fm trashItemAtURL:[NSURL fileURLWithPath:readOnly] resultingItemURL:&result error:&error];
        expect(!ok && [error.domain isEqual:NSCocoaErrorDomain] && error.code == NSFeatureUnsupportedError
            && isPOSIXError(error.userInfo[NSUnderlyingErrorKey], EROFS),
            [NSString stringWithFormat:@"trashing on a read-only volume gives %d, %@", ok, error]);
        error = nil;
        ok = [fm trashItemAtURL:[NSURL URLWithString:@"http://example.com/x"] resultingItemURL:&result error:&error];
        expect(!ok && error.code == NSFileReadUnsupportedSchemeError, [NSString stringWithFormat:@"trashing an http URL gives %@", error]);
        error = nil;
        ok = [fm trashItemAtURL:[NSURL fileURLWithPath:[homeDir stringByAppendingPathComponent:@"missing"]] resultingItemURL:&result error:&error];
        expect(!ok && error.code == NSFileNoSuchFileError, [NSString stringWithFormat:@"trashing a missing file gives %@", error]);

        // collisions in the home trash (Review Focus 4)
        for (NSString *name in @[ @"noext", @".hidden", @"a folder" ])
        {
            BOOL folder = [name isEqual:@"a folder"];
            NSURL *first = nil, *second = nil;
            NSURL *item = makeItem(homeDir, name, folder);
            ok = [fm trashItemAtURL:item resultingItemURL:&first error:&error];
            item = makeItem(homeDir, name, folder);
            ok = [fm trashItemAtURL:item resultingItemURL:&second error:&error] && ok;
            expect(ok && first && second && ![first.path isEqual:second.path]
                && [first.path.stringByDeletingLastPathComponent isEqual:homeTrash]
                && [second.path.stringByDeletingLastPathComponent isEqual:homeTrash]
                && [fm fileExistsAtPath:first.path] && [fm fileExistsAtPath:second.path] && ![fm fileExistsAtPath:item.path],
                [NSString stringWithFormat:@"trashing two items called %@ gives %@ and %@ (%@)", name, first.path, second.path, error]);
            if (first)
                [fm removeItemAtURL:first error:NULL];
            if (second)
                [fm removeItemAtURL:second error:NULL];
        }
    }
    return failures ? 1 : 0;
}
