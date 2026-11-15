/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// NSThumbnail1024x1024SizeKey is exported as an NSURLThumbnailDictionaryItem, the key type of the
// dictionary behind NSURLThumbnailDictionaryKey. Its value is the constant's own name (the same as
// the NSURL resource keys; the public documentation does not state the string).
#import <Foundation/Foundation.h>
#include <stdio.h>

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int failures = 0;

    NSURLThumbnailDictionaryItem item = NSThumbnail1024x1024SizeKey;
    BOOL ok = item != nil && [item isEqualToString: @"NSThumbnail1024x1024SizeKey"];
    printf("%s NSThumbnail1024x1024SizeKey\n", ok ? "PASS" : "FAIL");
    failures += !ok;

    NSDictionary<NSURLThumbnailDictionaryItem, id> *dictionary = @{ NSThumbnail1024x1024SizeKey : @"image" };
    ok = [[dictionary objectForKey: NSThumbnail1024x1024SizeKey] isEqual: @"image"];
    printf("%s the constant works as a dictionary key\n", ok ? "PASS" : "FAIL");
    failures += !ok;

    [pool drain];
    return failures ? 1 : 0;
}
