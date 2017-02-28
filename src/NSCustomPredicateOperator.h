#import "NSPredicateOperator.h"

CF_PRIVATE
@interface NSCustomPredicateOperator : NSPredicateOperator
{
    SEL _selector;
}

- (id)initWithCustomSelector:(SEL)customSelector modifier:(NSComparisonPredicateModifier)modifier;

@end
