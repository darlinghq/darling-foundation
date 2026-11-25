/*
 This file is part of Darling.

 Copyright (C) 2026 Darling Team

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/NSObject.h>

@class NSArray<ObjectType>, NSString, NSScriptObjectSpecifier, NSSpecifierTest;

// GUESS: the numeric values are not stated in the public documentation; they follow the documented order.
typedef NS_ENUM(NSUInteger, NSTestComparisonOperation) {
    NSEqualToComparison = 0,
    NSLessThanOrEqualToComparison,
    NSLessThanComparison,
    NSGreaterThanOrEqualToComparison,
    NSGreaterThanComparison,
    NSBeginsWithComparison,
    NSEndsWithComparison,
    NSContainsComparison
};

@interface NSScriptWhoseTest : NSObject

- (BOOL)isTrue;

@end

@interface NSLogicalTest : NSScriptWhoseTest {
@private
    // Instance variables are declared here because the i386 runtime does not support them in the implementation.
    NSUInteger _operation;
    NSArray *_subTests;
}

- (id)initAndTestWithTests:(NSArray<NSSpecifierTest *> *)subTests;
- (id)initOrTestWithTests:(NSArray<NSSpecifierTest *> *)subTests;
- (id)initNotTestWithTest:(NSScriptWhoseTest *)subTest;

@end

@interface NSSpecifierTest : NSScriptWhoseTest {
@private
    NSScriptObjectSpecifier *_object1;
    NSTestComparisonOperation _comparisonOperator;
    id _object2;
}

- (id)initWithObjectSpecifier:(NSScriptObjectSpecifier *)obj1
           comparisonOperator:(NSTestComparisonOperation)compOp
                   testObject:(id)obj2;

@end

NS_ASSUME_NONNULL_BEGIN

// Comparisons of any two objects, through -isEqual: and -compare:
// (https://developer.apple.com/documentation/objectivec/nsobject/nscomparisonmethods).
@interface NSObject (NSComparisonMethods)
- (BOOL)isEqualTo:(nullable id)object;
- (BOOL)isLessThanOrEqualTo:(nullable id)object;
- (BOOL)isLessThan:(nullable id)object;
- (BOOL)isGreaterThanOrEqualTo:(nullable id)object;
- (BOOL)isGreaterThan:(nullable id)object;
- (BOOL)isNotEqualTo:(nullable id)object;
- (BOOL)doesContain:(id)object;
- (BOOL)isLike:(NSString *)object;
- (BOOL)isCaseInsensitiveLike:(NSString *)object;
@end

NS_ASSUME_NONNULL_END
