/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * An observer may keep the notification it was sent (retain it, or hold it in a collection) and read it later:
 * -[NSNotificationCenter postNotificationName:object:] and its userInfo variant deliver an ordinary notification
 * object whose name, object and userInfo stay as they were while anyone holds it. Prints PASS or FAIL.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

@interface Keeper : NSObject {
@public
    NSNotification *kept;
    NSMutableArray *all;
}
@end
@implementation Keeper
- (void) note: (NSNotification *) n {
    [kept release];
    kept = [n retain];
    [all addObject: n];
}
@end

int main(void) {
    @autoreleasepool {
        Keeper *k = [Keeper new];
        k->all = [NSMutableArray new];
        id sender = [NSObject new];
        NSDictionary *info = @{@"key": @"value"};
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver: k selector: @selector(note:) name: @"RetainedNote" object: sender];

        [nc postNotificationName: @"RetainedNote" object: sender];
        CHECK([[k->kept name] isEqualToString: @"RetainedNote"]);
        CHECK([k->kept object] == sender);
        CHECK([k->kept userInfo] == nil);

        // Later posts do not change what was kept
        NSNotification *first = [[k->kept retain] autorelease];
        [nc postNotificationName: @"RetainedNote" object: sender userInfo: info];
        [nc postNotificationName: @"RetainedNote" object: sender];
        CHECK([[first name] isEqualToString: @"RetainedNote"]);
        CHECK([first object] == sender);
        CHECK([first userInfo] == nil);

        // The one with user info, kept in a collection
        NSNotification *second = [k->all objectAtIndex: 1];
        CHECK([[second name] isEqualToString: @"RetainedNote"]);
        CHECK([second object] == sender);
        CHECK([[second userInfo] isEqualToDictionary: info]);
        CHECK([k->all count] == 3);

        // An observer that keeps nothing still works after notifications were kept
        [nc removeObserver: k];
        Keeper *k2 = [Keeper new];
        k2->all = [NSMutableArray new];
        [nc addObserver: k2 selector: @selector(note:) name: @"RetainedNote2" object: nil];
        for (int i = 0; i < 5; i++) {
            [nc postNotificationName: @"RetainedNote2" object: sender userInfo: @{@"i": @(i)}];
            [k2->all removeAllObjects];
        }
        CHECK([[[k2->kept userInfo] objectForKey: @"i"] intValue] == 4);
        CHECK([[k2->kept name] isEqualToString: @"RetainedNote2"]);
        [nc removeObserver: k2];

        printf(failures ? "FAIL\n" : "PASS\n");
    }
    return failures != 0;
}
