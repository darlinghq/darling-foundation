// Copyright (C) 2026 Lubos Dolezel
// -[NSURL hasDirectoryPath]: YES when the URL's path ends with a slash. Prints "FAIL: ..." for each check that does
// not hold and exits 1 if any did; prints "PASS" otherwise. Also builds on macOS.
#import <Foundation/Foundation.h>

int main(void)
{
    @autoreleasepool
    {
        struct { NSURL *url; BOOL expected; } cases[] = {
            { [NSURL fileURLWithPath:@"/tmp" isDirectory:YES], YES },
            { [NSURL fileURLWithPath:@"/tmp/file.txt" isDirectory:NO], NO },
            { [NSURL URLWithString:@"http://example.com/a/"], YES },
            { [NSURL URLWithString:@"http://example.com/a"], NO },
            { [NSURL URLWithString:@"file:///"], YES },
        };
        int failures = 0;
        for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++)
        {
            if ([cases[i].url hasDirectoryPath] != cases[i].expected)
            {
                printf("FAIL: %s hasDirectoryPath is %d\n", [[cases[i].url absoluteString] UTF8String], !cases[i].expected);
                failures++;
            }
        }
        if (failures)
            return 1;
        printf("PASS\n");
    }
    return 0;
}
