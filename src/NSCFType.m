#import "NSCFType.h"
#import "CFInternal.h"

@implementation NSCFType

- (BOOL)allowsWeakReference
{
	return !_CFIsDeallocating(self);
}

- (NSUInteger)hash
{
	return CFHash(self);
}

- (BOOL)isEqual: (id)other
{
	if (!other) {
		return NO;
	}

	if (self == other) {
		return YES;
	}

	return CFEqual(self, other);
}

- (oneway void)release
{
	CFRelease(self);
}

- (instancetype)retain
{
	CFRetain(self);
	return self;
}

- (NSUInteger)retainCount
{
	return CFGetRetainCount(self);
}

- (BOOL)retainWeakReference
{
	return _CFTryRetain(self) != nil;
}

@end
