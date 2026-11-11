#import <Foundation/NSObject.h>

@class NSMutableDictionary;

@interface NSScriptCoercionHandler : NSObject
{
    NSMutableDictionary *_coercers;
}
+ (NSScriptCoercionHandler *)sharedCoercionHandler;
- (id)coerceValue:(id)value toClass:(Class)toClass;
- (void)registerCoercer:(id)coercer selector:(SEL)selector toConvertFromClass:(Class)fromClass toClass:(Class)toClass;
@end
