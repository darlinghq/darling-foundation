#import "NSPredicateOperator.h"
#import "NSSubstringPredicateOperator.h"
#import <pthread.h>

@interface NSInPredicateOperator : NSPredicateOperator
{
    NSComparisonPredicateOptions _flags;
    NSSubstringPredicateOperator * _stringVersion;
    pthread_mutex_t _mutex;
}

- (id)initWithOperatorType:(NSPredicateOperatorType)type modifier:(NSComparisonPredicateModifier)modifier options:(NSComparisonPredicateOptions)options;
- (NSComparisonPredicateOptions)flags;
- (id)stringVersion;

@end
