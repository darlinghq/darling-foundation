#import <Foundation/NSObject.h>
#import <CoreFoundation/CFUUID.h>
#import <uuid/uuid.h>

#if __OBJC2__
#define FOUNDATION_INSTANCETYPE instancetype
#else
#define FOUNDATION_INSTANCETYPE id
#endif

@interface NSUUID : NSObject <NSCopying, NSSecureCoding>

+ (FOUNDATION_INSTANCETYPE)UUID;
- (FOUNDATION_INSTANCETYPE)init;
- (FOUNDATION_INSTANCETYPE)initWithUUIDString:(NSString *)string;
- (FOUNDATION_INSTANCETYPE)initWithUUIDBytes:(const uuid_t)bytes;
- (void)getUUIDBytes:(uuid_t)uuid;
- (NSString *)UUIDString;

@end
