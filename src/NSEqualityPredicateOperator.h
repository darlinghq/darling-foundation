#import "NSPredicateOperator.h"

@interface NSEqualityPredicateOperator : NSPredicateOperator
{
    BOOL _negate;
    NSComparisonPredicateOptions _options;
}

- (id)initWithOperatorType:(NSPredicateOperatorType)type modifier:(NSComparisonPredicateModifier)modifier negate:(BOOL)negate options:(NSComparisonPredicateOptions)options;
- (id)initWithOperatorType:(NSPredicateOperatorType)type modifier:(NSComparisonPredicateModifier)modifier negate:(BOOL)negate;
- (void)setNegation:(BOOL)negation;
- (BOOL)isNegation;

@end
