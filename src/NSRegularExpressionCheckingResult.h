#import <Foundation/NSTextCheckingResult.h>

@class NSArray, NSRegularExpression;

typedef NS_ENUM(NSUInteger, NSRegularExpressionCheckingResultLimits) {
    NSRegularExpressionCheckingResultSimpleLimit = 3,
    NSRegularExpressionCheckingResultExtendedLimit = 7,
};

NS_REQUIRES_PROPERTY_DEFINITIONS
@interface NSRegularExpressionCheckingResult : NSTextCheckingResult

@property (readonly) NSArray *rangeArray;
@property (readonly) NSRegularExpression *regularExpression;

- (id)initWithRangeArray:(NSArray *)ranges regularExpression:(NSRegularExpression *)expression;
- (id)initWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression *)expression;
- (id)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;
- (id)resultByAdjustingRangesWithOffset:(NSInteger)offset;
- (NSTextCheckingType)resultType;
- (NSString *)description;

@end

@interface NSSimpleRegularExpressionCheckingResult : NSRegularExpressionCheckingResult
{
    NSRegularExpression *_regularExpression;
    NSRange _ranges[NSRegularExpressionCheckingResultSimpleLimit];
    NSUInteger _numberOfRanges;
}

- (id)initWithRangeArray:(NSArray *)ranges regularExpression:(NSRegularExpression *)expression;
- (id)initWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression *)expression;
- (void)dealloc;
- (NSArray *)rangeArray;
- (NSRange)rangeAtIndex:(NSUInteger)index;
- (NSUInteger)numberOfRanges;
- (BOOL)_adjustRangesWithOffset:(NSInteger)offset;
- (NSRange)range;
- (NSRegularExpression *)regularExpression;

@end

@interface NSExtendedRegularExpressionCheckingResult : NSRegularExpressionCheckingResult
{
    NSRegularExpression *_regularExpression;
    NSRange _ranges[NSRegularExpressionCheckingResultExtendedLimit];
}

- (id)initWithRangeArray:(NSArray *)ranges regularExpression:(NSRegularExpression *)expression;
- (id)initWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression *)expression;
- (void)dealloc;
- (NSArray *)rangeArray;
- (NSRange)rangeAtIndex:(NSUInteger)index;
- (NSUInteger)numberOfRanges;
- (BOOL)_adjustRangesWithOffset:(NSInteger)offset;
- (NSRange)range;
- (NSRegularExpression *)regularExpression;

@end


@interface NSComplexRegularExpressionCheckingResult : NSRegularExpressionCheckingResult {
    NSRegularExpression *_regularExpression;
    NSArray *_rangeArray;
}

- (id)initWithRangeArray:(NSArray *)ranges regularExpression:(NSRegularExpression *)expression;
- (id)initWithRanges:(NSRangePointer)ranges count:(NSUInteger)count regularExpression:(NSRegularExpression *)expression;
- (void)dealloc;
- (NSArray *)rangeArray;
- (NSRange)rangeAtIndex:(NSUInteger)index;
- (NSUInteger)numberOfRanges;
- (BOOL)_adjustRangesWithOffset:(NSInteger)offset;
- (NSRange)range;
- (NSRegularExpression *)regularExpression;

@end
