/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// NSProgress fileTotalCount and fileCompletedCount (kept in the user info under the file
// count keys) and performAsCurrentWithPendingUnitCount:usingBlock: (current for the block,
// resigned afterwards, also when the block raises).
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSProgress *p = [NSProgress progressWithTotalUnitCount: 10];
    expect([p fileTotalCount] == nil && [p fileCompletedCount] == nil, @"counts start unset");
    [p setFileTotalCount: [NSNumber numberWithInt: 5]];
    [p setFileCompletedCount: [NSNumber numberWithInt: 2]];
    expect([[p fileTotalCount] intValue] == 5 && [[p fileCompletedCount] intValue] == 2, @"counts read back");
    expect([[[p userInfo] objectForKey: NSProgressFileTotalCountKey] intValue] == 5, @"total is stored under NSProgressFileTotalCountKey");
    expect([[[p userInfo] objectForKey: NSProgressFileCompletedCountKey] intValue] == 2, @"completed is stored under NSProgressFileCompletedCountKey");
    [p setFileTotalCount: nil];
    expect([p fileTotalCount] == nil && [p fileCompletedCount] != nil, @"nil clears one count");

    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    __block NSProgress *seen = nil;
    __block NSProgress *child = nil;
    [parent performAsCurrentWithPendingUnitCount: 40 usingBlock: ^{
        seen = [NSProgress currentProgress];
        child = [NSProgress progressWithTotalUnitCount: 10];
    }];
    expect(seen == parent, @"the progress is current inside the block");
    expect([NSProgress currentProgress] == nil, @"it is not current afterwards");
    [child setCompletedUnitCount: 10];
    expect([parent completedUnitCount] == 40, @"a child created in the block contributes the pending units");

    // QUIRK pinned: a block that raises leaves the progress current.
    NSProgress *raiser = [NSProgress progressWithTotalUnitCount: 10];
    @try {
        [raiser performAsCurrentWithPendingUnitCount: 1 usingBlock: ^{
            [NSException raise: @"V430Test" format: @"raised"];
        }];
        expect(NO, @"the exception propagates");
    } @catch (NSException *e) {
        expect([[e name] isEqualToString: @"V430Test"], @"the block's exception reaches the caller");
    }
    expect([NSProgress currentProgress] == raiser, @"a raising block leaves the progress current (quirk)");
    [raiser resignCurrent];
    expect([NSProgress currentProgress] == nil, @"explicit resign makes it non-current");

    [pool drain];
    return failures ? 1 : 0;
}
