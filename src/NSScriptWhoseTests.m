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

#import <Foundation/NSScriptWhoseTests.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSException.h>
#import <Foundation/NSObjCRuntime.h>

@implementation NSScriptWhoseTest

- (BOOL)isTrue
{
    // GUESS: the class is abstract in the documentation; the base returns NO.
    return NO;
}

@end

typedef NS_ENUM(NSUInteger, DarlingLogicalTestOperation) {
    DarlingLogicalTestAnd,
    DarlingLogicalTestOr,
    DarlingLogicalTestNot
};

@implementation NSLogicalTest {
    DarlingLogicalTestOperation _operation;
    NSArray *_subTests;
}

- (id)_darlingInitWithOperation:(DarlingLogicalTestOperation)operation subTests:(NSArray *)subTests
{
    if ((self = [super init]))
    {
        _operation = operation;
        _subTests = [subTests copy];
    }
    return self;
}

- (id)initAndTestWithTests:(NSArray *)subTests
{
    return [self _darlingInitWithOperation:DarlingLogicalTestAnd subTests:subTests];
}

- (id)initOrTestWithTests:(NSArray *)subTests
{
    return [self _darlingInitWithOperation:DarlingLogicalTestOr subTests:subTests];
}

- (id)initNotTestWithTest:(NSScriptWhoseTest *)subTest
{
    // GUESS: a nil subtest raises; the public documentation does not say what happens.
    if (subTest == nil)
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"-initNotTestWithTest: requires a test"];
    }
    return [self _darlingInitWithOperation:DarlingLogicalTestNot subTests:@[subTest]];
}

- (void)dealloc
{
    [_subTests release];
    [super dealloc];
}

// GUESS: an empty or nil AND list is true and an empty or nil OR list is false (the usual identity
// elements); the public documentation does not say.
- (BOOL)isTrue
{
    switch (_operation)
    {
        case DarlingLogicalTestAnd:
            for (NSScriptWhoseTest *test in _subTests)
            {
                if (![test isTrue])
                    return NO;
            }
            return YES;
        case DarlingLogicalTestOr:
            for (NSScriptWhoseTest *test in _subTests)
            {
                if ([test isTrue])
                    return YES;
            }
            return NO;
        case DarlingLogicalTestNot:
            return ![[_subTests firstObject] isTrue];
    }
    return NO;
}

@end

@implementation NSSpecifierTest {
    NSScriptObjectSpecifier *_object1;
    NSTestComparisonOperation _comparisonOperator;
    id _object2;
}

- (id)initWithObjectSpecifier:(NSScriptObjectSpecifier *)obj1
           comparisonOperator:(NSTestComparisonOperation)compOp
                   testObject:(id)obj2
{
    if ((self = [super init]))
    {
        _object1 = [obj1 retain];
        _comparisonOperator = compOp;
        _object2 = [obj2 retain];
    }
    return self;
}

- (void)dealloc
{
    [_object1 release];
    [_object2 release];
    [super dealloc];
}

// GUESS: not implemented. The comparison is a placeholder, so the test never matches.
- (BOOL)isTrue
{
    NSLog(@"Stub called: -isTrue in %@", [self class]);
    return NO;
}

@end
