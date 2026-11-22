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

@class NSArray<ObjectType>, NSScriptObjectSpecifier, NSSpecifierTest;

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

@interface NSLogicalTest : NSScriptWhoseTest

- (id)initAndTestWithTests:(NSArray<NSSpecifierTest *> *)subTests;
- (id)initOrTestWithTests:(NSArray<NSSpecifierTest *> *)subTests;
- (id)initNotTestWithTest:(NSScriptWhoseTest *)subTest;

@end

@interface NSSpecifierTest : NSScriptWhoseTest

- (id)initWithObjectSpecifier:(NSScriptObjectSpecifier *)obj1
           comparisonOperator:(NSTestComparisonOperation)compOp
                   testObject:(id)obj2;

@end
