#import <Foundation/NSObject.h>

@class NSArray, NSKeyValueObservance, NSMutableArray;

CF_PRIVATE
@interface NSKeyValueObservationInfo : NSObject
{
    NSMutableArray *_observances;
}
- (NSArray *)observances;
- (void)addObservance:(NSKeyValueObservance *)observance;
- (void)removeObservance:(NSKeyValueObservance *)observance;
@end
