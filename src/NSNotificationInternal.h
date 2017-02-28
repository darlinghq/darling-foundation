#import <Foundation/NSNotification.h>

CF_PRIVATE
@interface NSConcreteNotification : NSNotification
{
    NSString *name;
    id object;
    NSDictionary *userInfo;
    BOOL dyingObject;
}
+ (id)newTempNotificationWithName:(NSString *)name object:(id)anObject userInfo:(NSDictionary *)aUserInfo;
- (id)initWithName:(NSString *)name object:(id)anObject userInfo:(NSDictionary *)aUserInfo;
- (void)recycle;
@end
