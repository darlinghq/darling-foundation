#import <Foundation/NSObject.h>

@class NSString, NSDate;

NS_ASSUME_NONNULL_BEGIN

@interface NSDistributedLock : NSObject {
    NSString *_path;
    BOOL _isLocked;
}

+ (nullable NSDistributedLock *)lockWithPath:(NSString *)path;
- (nullable instancetype)init; // NS_UNAVAILABLE
- (nullable instancetype)initWithPath:(NSString *)path NS_DESIGNATED_INITIALIZER;

- (BOOL)tryLock;
- (void)unlock;
- (void)breakLock;
@property (readonly, copy) NSDate *lockDate;

@end

NS_ASSUME_NONNULL_END
