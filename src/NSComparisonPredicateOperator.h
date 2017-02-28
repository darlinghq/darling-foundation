#import "NSPredicateOperator.h"

@interface NSComparisonPredicateOperator : NSPredicateOperator
{
    NSPredicateOperatorType _variant;
    NSComparisonPredicateOptions _options;
}

- (NSPredicateOperatorType)variant;
- (id)initWithOperatorType:(NSPredicateOperatorType)type modifier:(NSComparisonPredicateModifier)modifier variant:(NSPredicateOperatorType)variant options:(NSComparisonPredicateOptions)options;
- (id)initWithOperatorType:(NSPredicateOperatorType)type modifier:(NSComparisonPredicateModifier)modifier variant:(NSPredicateOperatorType)variant;

@end
