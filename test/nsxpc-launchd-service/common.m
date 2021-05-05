#import "service.h"

@implementation SomeCodableObject

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)dealloc
{
	[_someString release];
	[_someOtherCodableObjects release];
	[super dealloc];
}

- (instancetype)init
{
	if (self = [super init]) {
		_someString = @"<default value>";
		_someOtherCodableObjects = [NSMutableArray new];
	}
	return self;
}

- (instancetype)initWithCoder: (NSCoder*)coder
{
	if (!coder.allowsKeyedCoding) {
		[NSException raise: NSInvalidArgumentException format: @"SomeCodableObject requires keyed coding"];
	}

	if (self = [super init]) {
		_someString = [[coder decodeObjectOfClass: [NSString class] forKey: @"str"] copy];
		_someOtherCodableObjects = [[coder decodeObjectOfClasses: [NSSet setWithObjects: [NSArray class], [self class], nil] forKey: @"arr"] mutableCopy];
	}
	return self;
}

- (void)encodeWithCoder: (NSCoder*)coder
{
	if (!coder.allowsKeyedCoding) {
		[NSException raise: NSInvalidArgumentException format: @"SomeCodableObject requires keyed coding"];
	}

	[coder encodeObject: _someString forKey: @"str"];
	[coder encodeObject: _someOtherCodableObjects forKey: @"arr"];
}

- (NSString*)description
{
	return [NSString stringWithFormat: @"SomeCodableObject (%@, %@)", _someString, _someOtherCodableObjects];
}

@end
