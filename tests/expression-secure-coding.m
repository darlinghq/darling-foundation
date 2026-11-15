/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// NSExpression (and so every comparison predicate) conforms to NSSecureCoding
// and survives a secure keyed archive round trip.
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

static id roundTrip(id object, Class cls) {
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error];
    if (!data)
        return nil;
    return [NSKeyedUnarchiver unarchivedObjectOfClass:cls fromData:data error:&error];
}

int main(void) {
    @autoreleasepool {
        CHECK([NSExpression conformsToProtocol:@protocol(NSSecureCoding)]);
        CHECK([NSExpression supportsSecureCoding]);

        NSExpression *keyPath = [NSExpression expressionForKeyPath:@"name"];
        NSExpression *constant = [NSExpression expressionForConstantValue:@"x"];
        NSExpression *restoredKeyPath = roundTrip(keyPath, [NSExpression class]);
        CHECK([restoredKeyPath isEqual:keyPath]);
        NSExpression *restoredConstant = roundTrip(constant, [NSExpression class]);
        CHECK([restoredConstant isEqual:constant]);

        NSPredicate *comparison = [NSPredicate predicateWithFormat:@"name == %@", @"x"];
        NSPredicate *restored = roundTrip(comparison, [NSPredicate class]);
        CHECK(restored != nil && [restored isEqual:comparison]);
        // A securely decoded predicate refuses evaluation until it is allowed.
        BOOL refused = NO;
        @try {
            [restored evaluateWithObject:@{@"name": @"x"}];
        } @catch (NSException *exception) {
            refused = YES;
        }
        CHECK(refused);
        [restored allowEvaluation];
        CHECK([restored evaluateWithObject:@{@"name": @"x"}]);

        NSPredicate *compound = [NSCompoundPredicate andPredicateWithSubpredicates:@[
            comparison, [NSPredicate predicateWithFormat:@"age > %@", @3]]];
        NSPredicate *restoredCompound = roundTrip(compound, [NSPredicate class]);
        CHECK(restoredCompound != nil && [restoredCompound isEqual:compound]);

        // Decoding as a class that does not match is refused.
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:keyPath requiringSecureCoding:YES error:&error];
        CHECK(data != nil);
        CHECK([NSKeyedUnarchiver unarchivedObjectOfClass:[NSString class] fromData:data error:&error] == nil);
    }
    if (failures == 0)
        printf("PASS\n");
    return failures != 0;
}
