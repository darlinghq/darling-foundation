#import <Foundation/NSGarbageCollector.h>

@implementation NSGarbageCollector
+(NSGarbageCollector*) defaultCollector
{
	return nil;
}

-(void)disable
{
}

-(void)enable
{
}

-(BOOL)isEnabled
{
	return NO;
}

-(BOOL)isCollecting
{
	return NO;
}

- (void)collectExhaustively
{
}

- (void)collectIfNeeded
{
}

- (void)disableCollectorForPointer:(const void *)ptr
{
}

- (void)enableCollectorForPointer:(const void *)ptr
{
}

- (NSZone *)zone
{
	return nil;
}
@end
