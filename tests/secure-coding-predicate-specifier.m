#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#undef NDEBUG
#include <assert.h>
#include <stdio.h>

int main(void) {
    @autoreleasepool {
        Class blockPredCls = NSClassFromString(@"NSBlockPredicate");
        Class specCls = [NSScriptObjectSpecifier class];

        // 1. NSPredicate adopts NSSecureCoding protocol and reports supportsSecureCoding == YES
        assert([NSPredicate conformsToProtocol:@protocol(NSSecureCoding)]);
        assert([NSPredicate supportsSecureCoding] == YES);

        // 2. NSBlockPredicate explicitly overrides supportsSecureCoding to NO at class level,
        // and does NOT have an instance method for supportsSecureCoding.
        assert([blockPredCls supportsSecureCoding] == NO);
        assert(class_getInstanceMethod(blockPredCls, @selector(supportsSecureCoding)) == NULL);

        // 3. NSScriptObjectSpecifier adopts NSSecureCoding and implements supportsSecureCoding == YES
        // at class level, and does NOT have an instance method for supportsSecureCoding.
        assert([specCls conformsToProtocol:@protocol(NSSecureCoding)]);
        assert([specCls supportsSecureCoding] == YES);
        assert(class_getInstanceMethod(specCls, @selector(supportsSecureCoding)) == NULL);

        // 4. Secure archiving of NSPredicate round-trips cleanly
        NSPredicate *pred = [NSPredicate predicateWithValue:YES];
        NSError *error = nil;
        NSData *predData = [NSKeyedArchiver archivedDataWithRootObject:pred requiringSecureCoding:YES error:&error];
        assert(predData != nil);
        assert(error == nil);

        NSPredicate *decodedPred = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSPredicate class] fromData:predData error:&error];
        assert(decodedPred != nil);
        assert(error == nil);
        assert([decodedPred evaluateWithObject:nil] == YES);

        // 5. NSBlockPredicate is rejected by secure archiver because supportsSecureCoding == NO
        NSPredicate *blockPred = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return YES;
        }];
        assert([blockPred isKindOfClass:blockPredCls]);
        error = nil;
        NSData *blockData = [NSKeyedArchiver archivedDataWithRootObject:blockPred requiringSecureCoding:YES error:&error];
        assert(blockData == nil);
        assert(error != nil);

        // 6. NSScriptObjectSpecifier encodes and decodes securely
        NSScriptObjectSpecifier *spec = [[[NSScriptObjectSpecifier alloc] init] autorelease];
        error = nil;
        NSData *specData = [NSKeyedArchiver archivedDataWithRootObject:spec requiringSecureCoding:YES error:&error];
        assert(specData != nil);
        assert(error == nil);

        NSScriptObjectSpecifier *decodedSpec = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSScriptObjectSpecifier class] fromData:specData error:&error];
        assert(decodedSpec != nil);
        assert(error == nil);
        assert([decodedSpec isKindOfClass:specCls]);
    }

    puts("PASS: supportsSecureCoding class methods and NSSecureCoding conformance verified");
    return 0;
}
