#import "service.h"

#ifndef TEST_SECURE_CODING
	#define TEST_SECURE_CODING 0
#endif

@implementation SomeCodableObject

@synthesize someString = _someString;
@synthesize someOtherCodableObjects = _someOtherCodableObjects;

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

NSXPCInterface* generateServiceInterface(void) {
	NSXPCInterface* serviceInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Service)];
	NSXPCInterface* counterInterface = [NSXPCInterface interfaceWithProtocol: @protocol(Counter)];

	[serviceInterface setInterface: counterInterface forSelector: @selector(fetchSharedCounter:) argumentIndex: 0 ofReply: YES];

	[serviceInterface setClasses: [NSSet setWithObjects: [NSNumber class], [NSString class], [NSArray class], [NSDictionary class], [SomeCodableObject class], nil]
	                 forSelector: @selector(findAllWithDetails:callback:)
	               argumentIndex: 0
	                     ofReply: YES];

#if TEST_SECURE_CODING
	// purposefully set the wrong classes to see if our de/serialization will catch it

	// validate outgoing object; not sure if NSXPC should catch this
	// currently, we don't catch this; TODO: check official NSXPC behavior
	[serviceInterface setClasses: [NSSet setWithObjects: [NSNumber class], nil] forSelector: @selector(greet:) argumentIndex: 0 ofReply: NO];

	// validate incoming object; definitely supposed to be caught
	[serviceInterface setClasses: [NSSet setWithObjects: [NSNumber class], nil] forSelector: @selector(generateNonsense:) argumentIndex: 0 ofReply: YES];
#endif

	return serviceInterface;
};
