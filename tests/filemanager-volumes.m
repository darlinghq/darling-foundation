// Copyright (C) 2026 Lubos Dolezel
// filemanager-volumes [<hidden volume>]: -[NSFileManager mountedVolumeURLsIncludingResourceValuesForKeys:options:]
// with a disk image attached at "/Volumes/Unmount Test" (darling's tests/fixtures/unmount-test.dmg). The hidden
// volume, if given, must be listed, but not when hidden volumes are skipped (/proc in Darling's guest, or
// /System/Volumes/VM on macOS). Prints "FAIL: ..." for each check that does not hold and exits 1 if any did.
// The behaviour is described in darling's tests/volumes.md.
#import <Foundation/Foundation.h>
#include <sys/mount.h>

static int failures;

static void expect(BOOL ok, NSString *what)
{
    if (!ok)
    {
        printf("FAIL: %s\n", [what UTF8String]);
        failures++;
    }
}

static NSArray *strings(NSArray *urls)
{
    NSMutableArray *result = [NSMutableArray array];
    for (NSURL *url in urls)
        [result addObject:[url absoluteString]];
    return result;
}

int main(int argc, char **argv)
{
    @autoreleasepool
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *image = @"file:///Volumes/Unmount%20Test/";
        NSString *hidden = argc > 1 ? [[NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]] isDirectory:YES] absoluteString] : nil;

        NSArray *all = [fm mountedVolumeURLsIncludingResourceValuesForKeys:@[] options:0];
        NSArray *allStrings = strings(all);
        printf("all: %s\n", [[allStrings componentsJoinedByString:@" "] UTF8String]);
        expect(all != nil, @"the list is nil");
        expect([[allStrings firstObject] isEqual:@"file:///"], @"the list does not start with /");
        expect([allStrings containsObject:image], @"the image is not listed");
        if (hidden)
            expect([allStrings containsObject:hidden], [NSString stringWithFormat:@"%@ is not listed", hidden]);

        NSArray *visible = strings([fm mountedVolumeURLsIncludingResourceValuesForKeys:nil
                                                                             options:NSVolumeEnumerationSkipHiddenVolumes]);
        printf("visible: %s\n", [[visible componentsJoinedByString:@" "] UTF8String]);
        expect([[visible firstObject] isEqual:@"file:///"], @"skipping hidden volumes: the list does not start with /");
        expect([visible containsObject:image], @"skipping hidden volumes: the image is not listed");
        if (hidden)
            expect(![visible containsObject:hidden], [NSString stringWithFormat:@"skipping hidden volumes: %@ is listed", hidden]);
        // skipping hidden volumes leaves out exactly those statfs flags as not to be browsed
        for (NSURL *url in all)
        {
            struct statfs st;
            BOOL browsable = statfs([url fileSystemRepresentation], &st) == 0 && !(st.f_flags & MNT_DONTBROWSE);
            expect(browsable == [visible containsObject:[url absoluteString]],
                [NSString stringWithFormat:@"skipping hidden volumes: %@ (browsable: %d)", url, browsable]);
        }

        NSArray *nilKeys = [fm mountedVolumeURLsIncludingResourceValuesForKeys:nil options:0];
        expect(nilKeys.count == all.count, @"nil keys give a different list");

        NSArray *named = [fm mountedVolumeURLsIncludingResourceValuesForKeys:@[ NSURLVolumeNameKey ] options:0];
        NSURL *imageURL = nil;
        for (NSURL *url in named)
        {
            if ([[url absoluteString] isEqual:image])
                imageURL = url;
        }
        NSString *name = nil;
        [imageURL getResourceValue:&name forKey:NSURLVolumeNameKey error:NULL];
        expect([name isEqual:@"Unmount Test"], [NSString stringWithFormat:@"the prefetched volume name is %@", name]);
    }
    return failures ? 1 : 0;
}
