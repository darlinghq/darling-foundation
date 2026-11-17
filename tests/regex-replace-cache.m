/*
 * Copyright (C) 2026 Lubos Dolezel
 *
 * Regular expression replacement in strings with several different patterns in one process,
 * and LIKE / MATCHES predicates, which use it. On the i386 slice the second pattern used to hit
 * an unrecognized selector when the cache compared keys. Observed on macOS 10.14.4 (x86_64,
 * i386) and macOS 26.7.3.
 */
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSString *p = @"?ob";
        NSString *q = @"A*";
        NSStringCompareOptions regex = NSRegularExpressionSearch;
        CHECK([[p stringByReplacingOccurrencesOfString:@"\\?" withString:@"." options:regex range:NSMakeRange(0, [p length])] isEqualToString:@".ob"]);
        CHECK([[q stringByReplacingOccurrencesOfString:@"\\*" withString:@".*" options:regex range:NSMakeRange(0, [q length])] isEqualToString:@"A.*"]);
        CHECK([[p stringByReplacingOccurrencesOfString:@"[ob]" withString:@"x" options:regex range:NSMakeRange(0, [p length])] isEqualToString:@"?xx"]);

        CHECK([[NSPredicate predicateWithFormat:@"SELF LIKE '?ob'"] evaluateWithObject:@"Bob"]);
        CHECK([[NSPredicate predicateWithFormat:@"SELF LIKE[c] 'A*'"] evaluateWithObject:@"alice"]);
        CHECK(![[NSPredicate predicateWithFormat:@"SELF LIKE 'A*'"] evaluateWithObject:@"alice"]);
        CHECK([[NSPredicate predicateWithFormat:@"SELF MATCHES 'B.b'"] evaluateWithObject:@"Bob"]);
    }
    if (failures)
        return 1;
    puts("PASS_REGEX_REPLACE_CACHE");
    return 0;
}
