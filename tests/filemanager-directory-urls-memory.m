// Copyright (C) 2026 Lubos Dolezel
//
// Guest test: -[NSFileManager contentsOfDirectoryAtURL:includingPropertiesForKeys:options:error:] on a
// folder of thousands of entries returns one URL per entry and does not use a large amount of memory
// per entry (the resident size is measured with task_info around the call, before the autorelease pool
// drains).
#import <Foundation/Foundation.h>
#include <mach/mach.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

static int failures;

static void report(const char *name, BOOL ok)
{
    printf("%s: %s\n", ok ? "PASS" : "FAIL", name);
    if (!ok)
        failures++;
}

static size_t residentSize(void)
{
    struct mach_task_basic_info info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &count) != KERN_SUCCESS)
        return 0;
    return info.resident_size;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        const int entries = 6000;
        const size_t perEntryLimit = 1024; // bytes; a listing without properties needs a few hundred
        NSFileManager *fm = [NSFileManager defaultManager];
        char tmpl[] = "/tmp/fm-dir-urls-XXXXXX";
        if (!mkdtemp(tmpl)) {
            printf("FAIL: mkdtemp\n");
            return 1;
        }
        NSString *dir = [NSString stringWithUTF8String:tmpl];
        for (int i = 0; i < entries; i++) {
            NSString *p = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"entry-%05d.txt", i]];
            if (i % 2) {
                mkdir([p fileSystemRepresentation], 0755);
            } else {
                int fd = open([p fileSystemRepresentation], O_CREAT | O_WRONLY, 0644);
                if (fd >= 0)
                    close(fd);
            }
        }

        // Warm up so that one-time allocations are not counted.
        [fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:dir] includingPropertiesForKeys:nil options:0 error:NULL];

        size_t before = residentSize();
        NSError *error = nil;
        NSArray *urls = [fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:dir isDirectory:YES]
                          includingPropertiesForKeys:nil
                                             options:0
                                               error:&error];
        size_t after = residentSize();
        report("listing succeeds", urls != nil && error == nil);
        report("one URL per entry", [urls count] == (NSUInteger)entries);
        BOOL allFile = YES, namesOk = YES;
        for (NSURL *url in urls) {
            if (![url isFileURL])
                allFile = NO;
            if (![[url lastPathComponent] hasPrefix:@"entry-"])
                namesOk = NO;
        }
        report("every URL is a file URL with the entry name", allFile && namesOk);
        NSArray *withKeys = [fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:dir]
                              includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                   error:NULL];
        NSNumber *isDir = nil;
        [[withKeys objectAtIndex:1] getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
        report("requested properties are still available", [withKeys count] == (NSUInteger)entries && isDir != nil);

        size_t grown = after > before ? after - before : 0;
        printf("resident growth: %zu KB (%zu bytes per entry)\n", grown / 1024, grown / entries);
        report("memory per entry is small", grown < perEntryLimit * entries);

        [fm removeItemAtPath:dir error:NULL];
    }
    return failures ? 1 : 0;
}
