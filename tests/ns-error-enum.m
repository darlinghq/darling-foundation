// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Lubos Dolezel
//
// NS_ERROR_ENUM(domain, Name) declares an NSInteger-based enum tied to an NSError domain string
// constant. Checks the underlying type and the values. The Swift import of the enum as an error type is
// checked by the Swift typecheck tests of the frameworks that declare one.
// Prints PASS when everything holds; the exit code is the number of failed checks.

#import <Foundation/Foundation.h>

extern NSString *const TestErrorDomain;
NSString *const TestErrorDomain = @"TestErrorDomain";

typedef NS_ERROR_ENUM(TestErrorDomain, TestErrorCode) {
    TestErrorCodeFirst = 1,
    TestErrorCodeNegative = -7,
    TestErrorCodeLarge = 0x7fffffff,
};

static int failures;

#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

int main(void)
{
    @autoreleasepool {
        CHECK(sizeof(TestErrorCode) == sizeof(NSInteger));
        CHECK((TestErrorCode)-1 < 0); /* signed, like NSInteger */
        CHECK(TestErrorCodeFirst == 1 && TestErrorCodeNegative == -7 && TestErrorCodeLarge == 0x7fffffff);
        NSError *e = [NSError errorWithDomain:TestErrorDomain code:TestErrorCodeNegative userInfo:nil];
        CHECK(e.code == TestErrorCodeNegative);
    }
    if (!failures) printf("PASS\n");
    return failures;
}
