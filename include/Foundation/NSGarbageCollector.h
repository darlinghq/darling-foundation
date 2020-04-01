#import <Foundation/NSObject.h>

@interface NSGarbageCollector : NSObject
+(NSGarbageCollector*) defaultCollector;
-(void)disable;
-(void)enable;
-(BOOL)isEnabled;
-(BOOL)isCollecting;
- (void)collectExhaustively;
- (void)collectIfNeeded;
- (void)disableCollectorForPointer:(const void *)ptr;
- (void)enableCollectorForPointer:(const void *)ptr;
- (NSZone *)zone;
@end
