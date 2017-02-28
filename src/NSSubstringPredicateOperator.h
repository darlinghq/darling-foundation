#import "NSStringPredicateOperator.h"

typedef NS_ENUM(NSUInteger, NSSubstringPredicateOperatorPosition) {
    NSSubstringBeginsWith = 0,
    NSSubstringEndsWith,
    NSSubstringContains,
};

@interface NSSubstringPredicateOperator : NSStringPredicateOperator
{
    NSSubstringPredicateOperatorPosition _position;
}

- (id)initWithOperatorType:(NSPredicateOperatorType)type modifier:(NSComparisonPredicateModifier)modifier variant:(NSUInteger)variant position:(NSSubstringPredicateOperatorPosition)position;
- (NSSubstringPredicateOperatorPosition)position;

@end
