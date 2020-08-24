/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#import <Foundation/NSInvocation.h>
#import <Foundation/NSLayoutConstraint.h>
#import <Foundation/NSMethodSignature.h>
#warning TODO: $ld$hide$os 10.4 through 10.7, also METACLASS

@implementation NSLayoutConstraint

// @synthesize firstItem=_firstItem;
// @synthesize firstAttribute=_firstAttribute;
// @synthesize secondItem=_secondItem;
// @synthesize secondAttribute=_secondAttribute;
// @synthesize relation=_relation;
// @synthesize multiplier=_multiplier;
// @synthesize constant=_constant;

+ (instancetype)constraintWithItem:(id)view1
                         attribute:(NSLayoutAttribute)attr1
                         relatedBy:(NSLayoutRelation)relation
                            toItem:(id)view2
                         attribute:(NSLayoutAttribute)attr2
                        multiplier:(CGFloat)multiplier
                          constant:(CGFloat)c {
    NSLayoutConstraint *item = [[NSLayoutConstraint alloc] init];

    return item;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
  return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
  NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
