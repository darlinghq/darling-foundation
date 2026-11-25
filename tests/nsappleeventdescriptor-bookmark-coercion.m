// Copyright (C) 2026 Lubos Dolezel
// nsappleeventdescriptor-bookmark-coercion: -[NSAppleEventDescriptor coerceToDescriptorType:typeFileURL] of bookmark
// data gives the file URL it resolves to (a coercion the Apple Event Manager provides). Prints "FAIL: ..." on
// failure, else "PASS". Link with -framework Foundation -framework CoreServices. Also passes on macOS 26.7.3.
#import <Foundation/Foundation.h>
#include <CoreServices/CoreServices.h>
#include <stdlib.h>
#include <unistd.h>

int main(void)
{
    @autoreleasepool
    {
        char template[] = "/tmp/aed-bookmark.XXXXXX";
        char real[PATH_MAX];
        if (mkdtemp(template) == NULL || realpath(template, real) == NULL)
            return 2;
        NSString *file = [[NSString stringWithUTF8String:real] stringByAppendingPathComponent:@"a.txt"];
        [@"a" writeToFile:file atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        NSURL *url = [NSURL fileURLWithPath:file];
        NSData *bookmark = [url bookmarkDataWithOptions:0 includingResourceValuesForKeys:nil relativeToURL:nil error:NULL];
        NSAppleEventDescriptor *item = [NSAppleEventDescriptor descriptorWithDescriptorType:typeBookmarkData data:bookmark];
        NSAppleEventDescriptor *coerced = [item coerceToDescriptorType:typeFileURL];
        NSString *string = coerced ? [[[NSString alloc] initWithData:coerced.data encoding:NSUTF8StringEncoding] autorelease] : nil;
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithUTF8String:real] error:NULL];
        if (coerced.descriptorType != typeFileURL || ![string isEqual:url.absoluteString])
        {
            printf("FAIL: the coercion gives %s\n", [[coerced description] UTF8String]);
            return 1;
        }
    }
    printf("PASS\n");
    return 0;
}
