// TODO: NSScriptWhoseTest, NSLogicalTest, NSSpecifierTest and the
// NSScriptingComparisonMethods category

#import <Foundation/NSObject.h>

@class NSString;

NS_ASSUME_NONNULL_BEGIN

// Comparisons of any two objects, through -isEqual: and -compare:
// (https://developer.apple.com/documentation/objectivec/nsobject/nscomparisonmethods).
@interface NSObject (NSComparisonMethods)
- (BOOL)isEqualTo:(nullable id)object;
- (BOOL)isLessThanOrEqualTo:(nullable id)object;
- (BOOL)isLessThan:(nullable id)object;
- (BOOL)isGreaterThanOrEqualTo:(nullable id)object;
- (BOOL)isGreaterThan:(nullable id)object;
- (BOOL)isNotEqualTo:(nullable id)object;
- (BOOL)doesContain:(id)object;
- (BOOL)isLike:(NSString *)object;
- (BOOL)isCaseInsensitiveLike:(NSString *)object;
@end

NS_ASSUME_NONNULL_END
