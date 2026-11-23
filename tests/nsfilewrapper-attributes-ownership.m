// -[NSFileWrapper initWithPath:] and -[NSFileWrapper updateFromPath:] keep one owned copy of the file attributes.
// Memory Management Policy (developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/
// Articles/mmRules.html): an object made with a method whose name contains "copy" is owned by the caller, so
// storing it in an instance variable needs no further retain, and an object only borrowed (an autoreleased
// result) is released by whoever created the pool it lives in, not by the caller.
// -updateFromPath: is documented at developer.apple.com/documentation/foundation/filewrapper/update(frompath:).
// Built without ARC; the legacy path methods are not declared in the header.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

@interface NSFileWrapper (LegacyPathAPI)
- (id)initWithPath:(NSString *)path;
- (BOOL)updateFromPath:(NSString *)path;
@end

static int failures;

static void expect(BOOL ok, const char *what)
{
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok)
        failures++;
}

int main(void)
{
    NSAutoreleasePool *outer = [NSAutoreleasePool new];
    NSFileManager *fm = [NSFileManager defaultManager];
    char tmpl[] = "/tmp/filewrapper-attributes-XXXXXX";
    if (!mkdtemp(tmpl)) {
        printf("FAIL: mkdtemp\n");
        return 1;
    }
    NSString *dir = [fm stringWithFileSystemRepresentation:tmpl length:strlen(tmpl)];
    NSString *file = [dir stringByAppendingPathComponent:@"a.txt"];
    [@"one" writeToFile:file atomically:NO encoding:NSUTF8StringEncoding error:NULL];

    NSFileWrapper *wrapper = nil;
    {
        // Whatever -initWithPath: autoreleased lives in this pool, so afterwards only owners are left.
        NSAutoreleasePool *inner = [NSAutoreleasePool new];
        wrapper = [[NSFileWrapper alloc] initWithPath:file];
        [inner drain];
    }
    expect(wrapper != nil && [wrapper isRegularFile], "the wrapper reads a regular file");

    NSDictionary *attributes = [wrapper fileAttributes];
    expect(attributes != nil, "the wrapper keeps the attributes of the file");
    expect([attributes retainCount] == 1, "after initWithPath: the wrapper is the only owner of its attribute dictionary");
    // The values are shared by a shallow copy, so a dictionary that was read and never released would still hold
    // this one.
    NSDate *modified = [attributes objectForKey:NSFileModificationDate];
    expect(modified != nil && [modified retainCount] == 1,
           "after initWithPath: nothing but the wrapper's copy holds the attribute values");

    // Each update after a change that makes the file newer than the wrapper replaces the copy.
    for (int round = 1; round <= 3; round++) {
        NSDictionary *touch = @{ NSFileModificationDate: [NSDate dateWithTimeIntervalSinceNow:10 * round] };
        [fm setAttributes:touch ofItemAtPath:file error:NULL];
        expect([wrapper updateFromPath:file], "the wrapper is updated from a newer file");
        attributes = [wrapper fileAttributes];
        expect([attributes retainCount] == 1, "after updateFromPath: the wrapper is the only owner of its attributes");
        expect([[attributes objectForKey:NSFileModificationDate] timeIntervalSinceNow] > 5,
               "the attributes are those of the updated file");
    }

    // Releasing the wrapper gives up its reference to the dictionary, so a reference taken here is the last one.
    NSDictionary *kept = [[wrapper fileAttributes] retain];
    [wrapper release];
    expect([kept retainCount] == 1, "the attribute dictionary does not outlive the wrapper");
    [kept release];
    [fm removeItemAtPath:dir error:NULL];
    [outer drain];
    printf("%s\n", failures ? "FAIL" : "PASS");
    return failures ? 1 : 0;
}
