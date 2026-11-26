// Copyright (C) 2026 Lubos Dolezel
//
// Foundation's Swift concurrency annotations (NS_SWIFT_UI_ACTOR,
// NS_SWIFT_NONISOLATED, NS_SWIFT_ASYNC, NS_SWIFT_DISABLE_ASYNC,
// NS_SWIFT_ASYNC_NAME, NS_SWIFT_ASYNC_THROWS_ON_FALSE) are accepted where
// the macOS SDK's headers use them, and change nothing for Objective-C.
// Builds and runs on macOS as well.
#import <Foundation/Foundation.h>
#include <stdio.h>

extern NSString *const TestConstant NS_SWIFT_NONISOLATED;
NSString *const TestConstant = @"constant";

NS_SWIFT_UI_ACTOR
@interface TestObject : NSObject
- (void)loadWithCompletion:(void (^)(NSString *result))completion NS_SWIFT_ASYNC(1);
- (void)checkWithCompletion:(void (^)(BOOL ok, NSError *error))completion NS_SWIFT_ASYNC_THROWS_ON_FALSE(1);
- (void)fetchWithCompletion:(void (^)(NSString *result))completion NS_SWIFT_ASYNC_NAME(fetch());
- (void)notifyWithCompletion:(void (^)(void))completion NS_SWIFT_DISABLE_ASYNC;
@end

@implementation TestObject
- (void)loadWithCompletion:(void (^)(NSString *))completion { completion(@"loaded"); }
- (void)checkWithCompletion:(void (^)(BOOL, NSError *))completion { completion(YES, nil); }
- (void)fetchWithCompletion:(void (^)(NSString *))completion { completion(@"fetched"); }
- (void)notifyWithCompletion:(void (^)(void))completion { completion(); }
@end

int main(void)
{
    @autoreleasepool {
        __block int calls = 0;
        TestObject *object = [[TestObject alloc] init];
        [object loadWithCompletion:^(NSString *result) { calls += [result isEqualToString:@"loaded"]; }];
        [object checkWithCompletion:^(BOOL ok, NSError *error) { calls += ok && error == nil; }];
        [object fetchWithCompletion:^(NSString *result) { calls += [result isEqualToString:@"fetched"]; }];
        [object notifyWithCompletion:^{ calls++; }];
        [object release];
        int ok = calls == 4 && [TestConstant isEqualToString:@"constant"];
        printf("%s\n", ok ? "ALL PASSED" : "FAILED");
        return !ok;
    }
}
