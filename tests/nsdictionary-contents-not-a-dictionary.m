// Copyright (C) 2026 Lubos Dolezel
//
// +[NSDictionary dictionaryWithContentsOfFile:] and its relatives return nil for a property list file whose
// root is not a dictionary (a string, an array), as documented for a file that is not a valid
// representation of a dictionary; a dictionary file still loads, mutable from NSMutableDictionary.
// Passes unchanged on macOS 26.7.3.
#import <Foundation/Foundation.h>
#include <stdlib.h>

static int failures;

static void expect(BOOL condition, const char *what) {
    printf("%s: %s\n", condition ? "PASS" : "FAIL", what);
    if (!condition)
        failures++;
}

int main(void) {
    @autoreleasepool {
        NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                [NSString stringWithFormat: @"nsdictionary-contents-%d", getpid()]];
        [[NSFileManager defaultManager] createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL];
        NSString *word = [dir stringByAppendingPathComponent: @"word.plist"];
        NSString *string = [dir stringByAppendingPathComponent: @"string.plist"];
        NSString *array = [dir stringByAppendingPathComponent: @"array.plist"];
        NSString *dict = [dir stringByAppendingPathComponent: @"dict.plist"];
        [@"plist\n" writeToFile: word atomically: NO encoding: NSUTF8StringEncoding error: NULL];
        [[NSPropertyListSerialization dataWithPropertyList: @"text" format: NSPropertyListXMLFormat_v1_0 options: 0 error: NULL]
                writeToFile: string atomically: NO];
        [@[ @1, @2 ] writeToFile: array atomically: NO];
        [@{ @"key" : @"value" } writeToFile: dict atomically: NO];

        expect([NSDictionary dictionaryWithContentsOfFile: word] == nil, "a bare word (an old-style string) gives nil");
        expect([NSDictionary dictionaryWithContentsOfFile: string] == nil, "an XML string gives nil");
        expect([NSDictionary dictionaryWithContentsOfFile: array] == nil, "an array gives nil");
        expect([[NSDictionary alloc] initWithContentsOfFile: string] == nil, "initWithContentsOfFile: too");
        expect([NSMutableDictionary dictionaryWithContentsOfFile: array] == nil, "NSMutableDictionary too");
        expect([NSDictionary dictionaryWithContentsOfURL: [NSURL fileURLWithPath: string]] == nil, "dictionaryWithContentsOfURL: too");

        NSDictionary *loaded = [NSDictionary dictionaryWithContentsOfFile: dict];
        expect([[loaded objectForKey: @"key"] isEqual: @"value"], "a dictionary file loads");
        NSMutableDictionary *mutable = [NSMutableDictionary dictionaryWithContentsOfFile: dict];
        [mutable setObject: @"other" forKey: @"added"];
        expect([mutable count] == 2, "NSMutableDictionary's is mutable");

        [[NSFileManager defaultManager] removeItemAtPath: dir error: NULL];
        printf(failures ? "FAILED %d\n" : "ALL PASSED\n", failures);
        return failures != 0;
    }
}
