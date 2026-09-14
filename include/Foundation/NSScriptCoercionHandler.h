#import <Foundation/NSObject.h>

@interface NSScriptCoercionHandler : NSObject
+ (NSScriptCoercionHandler *)sharedCoercionHandler;
- (id)coerceValue:(id)value toClass:(Class)toClass;
- (void)registerCoercer:(id)coercer selector:(SEL)selector toConvertFromClass:(Class)fromClass toClass:(Class)toClass;
@end
