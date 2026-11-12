#import <Foundation/NSTextCheckingResult.h>

@class NSString;

@interface NSReplacementCheckingResult : NSTextCheckingResult {
    NSRange _range;
    NSString *_replacementString;
}

- (id)initWithRange:(NSRange)range replacementString:(NSString *)replacementString;
- (id)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;
- (void)dealloc;
- (NSString *)replacementString;
- (BOOL)_adjustRangesWithOffset:(NSInteger)offset;
- (id)resultByAdjustingRangesWithOffset:(NSInteger)offset;
- (NSRange)range;
- (NSString *)description;

@end


@interface NSCorrectionCheckingResult : NSReplacementCheckingResult

- (NSTextCheckingType)resultType;

@end

@interface NSDashCheckingResult : NSReplacementCheckingResult

- (NSTextCheckingType)resultType;

@end

@interface NSQuoteCheckingResult : NSReplacementCheckingResult

- (NSTextCheckingType)resultType;

@end
