/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// NSProgress fileURL and fileOperationKind: kept in the user info under
// NSProgressFileURLKey and NSProgressFileOperationKindKey, so that either way
// of setting a value reads back the other way, and nil removes the key.
// Matches macOS 26.7.3 and Mac OS X 10.14.4, where the program builds and runs too.
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
    expect([p fileURL] == nil && [p fileOperationKind] == nil, @"both start unset");

    NSURL *file = [NSURL fileURLWithPath: @"/tmp/download"];
    [p setFileURL: file];
    [p setFileOperationKind: NSProgressFileOperationKindDownloading];
    expect([[[p userInfo] objectForKey: NSProgressFileURLKey] isEqual: file], @"the URL is stored under NSProgressFileURLKey");
    expect([[[p userInfo] objectForKey: NSProgressFileOperationKindKey] isEqual: NSProgressFileOperationKindDownloading],
           @"the kind is stored under NSProgressFileOperationKindKey");

    NSURL *other = [NSURL URLWithString: @"http://example.com/file"];
    [p setUserInfoObject: other forKey: NSProgressFileURLKey];
    [p setUserInfoObject: @"custom" forKey: NSProgressFileOperationKindKey];
    expect([[p fileURL] isEqual: other] && [[p fileOperationKind] isEqualToString: @"custom"],
           @"values set in the user info read back through the properties");

    [p setFileURL: nil];
    [p setFileOperationKind: nil];
    expect([p fileURL] == nil && [p fileOperationKind] == nil && [[p userInfo] count] == 0, @"nil removes the keys");

    expect([NSProgressFileURLKey isEqualToString: @"NSProgressFileURLKey"]
               && [NSProgressFileOperationKindKey isEqualToString: @"NSProgressFileOperationKindKey"],
           @"the key names");

    [pool release];
    printf("%s\n", failures ? "FAILED" : "ALL PASSED");
    return failures != 0;
}
