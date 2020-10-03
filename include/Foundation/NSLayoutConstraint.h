/*
    While NSLayoutConstraint is implemented in Foundation. It's definition does
    exist in both AppKit and UIKit. To reduce definition duplication, the
    definition will be stored in Foundation, to which AppKit/UIKit can import.
*/

#import <Foundation/NSObject.h>
#import <Foundation/NSGeometry.h>

typedef enum NSLayoutAttribute : NSInteger {
    NSLayoutAttributeLeft = 1,
    NSLayoutAttributeRight,
    NSLayoutAttributeTop,
    NSLayoutAttributeBottom,
    NSLayoutAttributeLeading,
    NSLayoutAttributeTrailing,
    NSLayoutAttributeWidth,
    NSLayoutAttributeHeight,
    NSLayoutAttributeCenterX,
    NSLayoutAttributeCenterY,
    NSLayoutAttributeBaseline,
    NSLayoutAttributeLastBaseline,
    NSLayoutAttributeFirstBaseline,
    NSLayoutAttributeLeftMargin,
    NSLayoutAttributeRightMargin,
    NSLayoutAttributeTopMargin,
    NSLayoutAttributeBottomMargin,
    NSLayoutAttributeLeadingMargin,
    NSLayoutAttributeTrailingMargin,
    NSLayoutAttributeCenterXWithinMargins,
    NSLayoutAttributeCenterYWithinMargins,
    NSLayoutAttributeNotAnAttribute
} NSLayoutAttribute;

typedef enum NSLayoutRelation : NSInteger {
    NSLayoutRelationLessThanOrEqual = -1,
    NSLayoutRelationEqual = 0,
    NSLayoutRelationGreaterThanOrEqual = 1
} NSLayoutRelation;

@interface NSLayoutConstraint : NSObject 
{
    id _firstItem;
    NSLayoutAttribute _firstAttribute;

    id _secondItem;
    NSLayoutAttribute _secondAttribute;

    NSLayoutRelation _relation;
    CGFloat _multiplier;
    CGFloat _constant;
}

@property(readonly, assign) id firstItem;
@property(readonly) NSLayoutAttribute firstAttribute;
// @property(readonly,copy) NSLayoutAnchor *firstAnchor;

@property(readonly, assign) id secondItem;
@property(readonly) NSLayoutAttribute secondAttribute;
// @property(readonly,copy) NSLayoutAnchor *secondAnchor;

@property(readonly) NSLayoutRelation relation;
@property(readonly) CGFloat multiplier;
@property CGFloat constant;



+ (instancetype)constraintWithItem:(id)view1
                         attribute:(NSLayoutAttribute)attr1
                         relatedBy:(NSLayoutRelation)relation
                            toItem:(id)view2
                         attribute:(NSLayoutAttribute)attr2
                        multiplier:(CGFloat)multiplier
                          constant:(CGFloat)c;

@end
