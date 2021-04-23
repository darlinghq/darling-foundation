#import <Foundation/NSDeprecatedKeyValueCoding.h>
#import <Foundation/NSRaise.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNull.h>

#import <objc/runtime.h>

#include <dispatch/dispatch.h>

#import "NSKeyValueCodingInternal.h"
#import "NSKeyValueAccessor.h"

static NSMutableDictionary<Class, NSMutableDictionary<NSString*, NSMutableArray<NSKeyBinding*>*>*>* bindingsByClassAndKeyAndType = nil;

static void initializeBindingsTable(void) {
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		bindingsByClassAndKeyAndType = [NSMutableDictionary new];
	});
};

static NSMutableDictionary<NSString*, NSMutableArray<NSKeyBinding*>*>* bindingsByKeyAndTypeForClass(Class class) {
	initializeBindingsTable();

	NSMutableDictionary<NSString*, NSMutableArray<NSKeyBinding*>*>* dict = nil;

	@synchronized(bindingsByClassAndKeyAndType) {
		dict = bindingsByClassAndKeyAndType[class];
		if (dict == nil) {
			bindingsByClassAndKeyAndType[class] = dict = [NSMutableDictionary new];
		}
	}

	return dict;
};

static NSMutableArray<NSKeyBinding*>* bindingsByTypeForClassAndKey(Class class, NSString* key) {
	NSMutableDictionary<NSString*, NSMutableArray<NSKeyBinding*>*>* bindingsByKeyAndType = bindingsByKeyAndTypeForClass(class);

	NSMutableArray<NSKeyBinding*>* array = nil;

	@synchronized(bindingsByKeyAndType) {
		array = bindingsByKeyAndType[key];
		if (array == nil) {
			bindingsByKeyAndType[key] = array = [@[[NSNull null], [NSNull null], [NSNull null], [NSNull null]] mutableCopy];
		}
	}

	return array;
};

static NSKeyBinding* bindingForClassAndKeyAndType(NSObject* object, Class class, NSString* key, NSKeyValueBindingOptions type) {
	NSMutableArray<NSKeyBinding*>* bindingsByType = bindingsByTypeForClassAndKey(class, key);
	NSKeyBinding* binding = nil;
	@synchronized(bindingsByType) {
		binding = bindingsByType[type & NSKeyValueBindingOptionsMask];
		if ([binding isEqual: [NSNull null]]) {
			binding = [object createKeyValueBindingForKey: key typeMask: type];
			if (binding == nil) {
				if (type & NSKeyValueBindingForSetter) {
					binding = [[NSKeySetBinding new] autorelease];
				} else {
					binding = [[NSKeyGetBinding new] autorelease];
				}
				binding.key = key;
			}
			binding.targetClass = class;
			bindingsByType[type & NSKeyValueBindingOptionsMask] = binding;
		}
	}
	if (binding != nil) {
		return [[binding retain] autorelease];
	}
	return nil;
};

static SEL selectorForOptions(NSKeyValueBindingOptions options) {
	if (options & NSKeyValueBindingForSetter) {
		if (options & NSKeyValueBindingIsStored) {
			return @selector(takeStoredValue:forKey:);
		} else {
			return @selector(takeValue:forKey:);
		}
	} else {
		if (options & NSKeyValueBindingIsStored) {
			return @selector(storedValueForKey:);
		} else {
			return @selector(valueForKey:);
		}
	}
};

static IMP classImplementationForOptions(NSKeyValueBindingOptions options, Class objectClass) {
	SEL selector = selectorForOptions(options);
	if ([objectClass instancesRespondToSelector: selector]) {
		return [objectClass instanceMethodForSelector: selector];
	}
	// should be impossible
	return nil;
};

static IMP defaultImplementationForOptions(NSKeyValueBindingOptions options) {
	static dispatch_once_t onceToken;
	static IMP valueForKey;
	static IMP storedValueForKey;
	static IMP takeValueForKey;
	static IMP takeStoredValueForKey;

	dispatch_once(&onceToken, ^{
		valueForKey = [NSObject instanceMethodForSelector: @selector(valueForKey:)];
		storedValueForKey = [NSObject instanceMethodForSelector: @selector(storedValueForKey:)];
		takeValueForKey = [NSObject instanceMethodForSelector: @selector(takeValue:forKey:)];
		takeStoredValueForKey = [NSObject instanceMethodForSelector: @selector(takeStoredValue:forKey:)];
	});

	if (options & NSKeyValueBindingForSetter) {
		if (options & NSKeyValueBindingIsStored) {
			return takeStoredValueForKey;
		} else {
			return takeValueForKey;
		}
	} else {
		if (options & NSKeyValueBindingIsStored) {
			return storedValueForKey;
		} else {
			return valueForKey;
		}
	}
};

static void raiseKeyValueException(NSString* reason, NSObject* object, NSString* key) {
	NSException* exc = [NSException exceptionWithName: @"NSUnknownKeyException" reason: reason userInfo: @{
		@"NSTargetObjectUserInfoKey": object,
		@"NSUnknownUserInfoKey": key
	}];
	[exc raise];
};

@implementation NSKeyBinding

@synthesize targetClass = _targetClass;
@synthesize key = _key;

- (void)dealloc
{
	[_key release];
	[super dealloc];
}

+ (void)suppressCapitalizedKeyWarning
{

}

@end

@implementation NSKeyGetBinding

- (id)getValueFromObject: (id)object
{
	return [object handleQueryWithUnboundKey: self.key];
}

@end

@implementation NSKeySetBinding

- (BOOL)isScalarProperty
{
	return NO;
}

- (void)setValue:(id)value inObject:(id)object
{
	return [object handleTakeValue: value forUnboundKey: self.key];
}

@end

@implementation _NSKeyForwardingGetBinding

- (instancetype)initWithKey: (NSString*)key isStored: (BOOL)isStored
{
	if (self = [super init]) {
		_isStored = isStored;
		self.key = key;
	}
	return self;
}

- (id)getValueFromObject: (id)object
{
	if (_isStored) {
		return [object storedValueForKey: self.key];
	} else {
		return [object valueForKey: self.key];
	}
}

@end

@implementation _NSKeyForwardingSetBinding

- (instancetype)initWithKey: (NSString*)key isStored: (BOOL)isStored
{
	if (self = [super init]) {
		_isStored = isStored;
		self.key = key;
	}
	return self;
}

- (void)setValue: (id)value inObject: (id)object
{
	if (_isStored) {
		return [object takeStoredValue: value forKey: self.key];
	} else {
		return [object takeValue: value forKey: self.key];
	}
}

@end

@implementation _NSKeyBindingGetWrapper

- (instancetype)initWithAccessor: (NSKeyValueGetter*)accessor forKey: (NSString*)key
{
	if (self = [super init]) {
		_wrappedAccessor = [accessor retain];
		self.key = key;
	}
	return self;
}

- (void)dealloc
{
	[_wrappedAccessor release];
	[super dealloc];
}

- (id)getValueFromObject: (id)object
{
	return _NSGetUsingKeyValueGetter(object, _wrappedAccessor);
}

@end

@implementation _NSKeyBindingSetWrapper

- (instancetype)initWithAccessor: (NSKeyValueSetter*)accessor forKey: (NSString*)key isScalar: (BOOL)isScalar
{
	if (self = [super init]) {
		_wrappedAccessor = [accessor retain];
		_isScalar = isScalar;
		self.key = key;
	}
	return self;
}

- (void)dealloc
{
	[_wrappedAccessor release];
	[super dealloc];
}

- (void)setValue: (id)value inObject: (id)object
{
	_NSSetUsingKeyValueSetter(object, _wrappedAccessor, value);
}

- (BOOL)isScalarProperty
{
	return _isScalar;
}

@end

@implementation NSObject (NSDeprecatedKeyValueCoding)

+ (BOOL)useStoredAccessor
{
	return YES;
}

- (id)_oldValueForKey: (NSString*)key
{
	NSKeyGetBinding* getter = (NSKeyGetBinding*)bindingForClassAndKeyAndType(self, [self class], key, NSKeyValueBindingForGetter);
	if (getter == nil) {
		return nil;
	}
	return [getter getValueFromObject: self];
}

- (id)storedValueForKey: (NSString*)key
{
	NSKeyGetBinding* getter = (NSKeyGetBinding*)bindingForClassAndKeyAndType(self, [self class], key, NSKeyValueBindingForGetter | NSKeyValueBindingIsStored);
	if (getter == nil) {
		return nil;
	}
	return [getter getValueFromObject: self];
}

- (void)takeValue: (id)value forKey: (NSString*)key
{
	NSKeySetBinding* setter = (NSKeySetBinding*)bindingForClassAndKeyAndType(self, [self class], key, NSKeyValueBindingForSetter);
	if (setter == nil) {
		return;
	}
	if (value == nil && setter.isScalarProperty) {
		[self unableToSetNilForKey: key];
		return;
	}
	[setter setValue: value inObject: self];
}

- (void)takeStoredValue: (id)value forKey: (NSString*)key
{
	NSKeySetBinding* setter = (NSKeySetBinding*)bindingForClassAndKeyAndType(self, [self class], key, NSKeyValueBindingForSetter | NSKeyValueBindingIsStored);
	if (setter == nil) {
		return;
	}
	if (value == nil && setter.isScalarProperty) {
		[self unableToSetNilForKey: key];
		return;
	}
	[setter setValue: value inObject: self];
}

- (id)handleQueryWithUnboundKey: (NSString*)key
{
	raiseKeyValueException(@"handleQueryWithUnboundKey: unknown key", self, key);
	return nil;
}

- (void)handleTakeValue: (id)value forUnboundKey: (NSString*)key
{
	raiseKeyValueException(@"handleTakeValue: unknown key", self, key);
}

- (void)unableToSetNilForKey: (NSString*)key
{
	raiseKeyValueException(@"unableToSetNilForKey: invalid nil value for key", self, key);
}

- (NSKeyBinding*)_createKeyValueBindingForKey: (NSString*)key name: (const char*)name bindingType: (NSKeyValueBindingType)type
{
	if (type & NSKeyValueBindingForSetter) {
		if (type & NSKeyValueBindingTypeNoDirectAccess) {
			SEL selector = sel_registerName(name);
			Method method = class_getInstanceMethod([self class], selector);
			if (method == nil) {
				return nil;
			}
			NSKeyValueMethodSetter* setter = [[[NSKeyValueMethodSetter alloc] initWithContainerClassID: [self class] key: key method: method] autorelease];
			if (setter == nil) {
				return nil;
			}
			char* argType = method_copyArgumentType(method, 2);
			BOOL isScalar = argType ? argType[0] != _C_ID : NO;
			free(argType);
			return [[[_NSKeyBindingSetWrapper alloc] initWithAccessor: setter forKey: key isScalar: isScalar] autorelease];
		} else {
			Ivar ivar = class_getInstanceVariable([self class], name);
			if (ivar == nil) {
				return nil;
			}
			NSKeyValueIvarSetter* setter = [[[NSKeyValueIvarSetter alloc] initWithContainerClassID: [self class] key: key containerIsa: [self class] ivar: ivar] autorelease];
			if (setter == nil) {
				return nil;
			}
			return [[[_NSKeyBindingSetWrapper alloc] initWithAccessor: setter forKey: key isScalar: ivar_getTypeEncoding(ivar)[0] != _C_ID] autorelease];
		}
	} else {
		if (type & NSKeyValueBindingTypeNoDirectAccess) {
			SEL selector = sel_registerName(name);
			Method method = class_getInstanceMethod([self class], selector);
			if (method == nil) {
				return nil;
			}
			NSKeyValueMethodGetter* getter = [[[NSKeyValueMethodGetter alloc] initWithContainerClassID: [self class] key: key method: method] autorelease];
			if (getter == nil) {
				return nil;
			}
			return [[[_NSKeyBindingGetWrapper alloc] initWithAccessor: getter forKey: key] autorelease];
		} else {
			Ivar ivar = class_getInstanceVariable([self class], name);
			if (ivar == nil) {
				return nil;
			}
			NSKeyValueIvarGetter* getter = [[[NSKeyValueIvarGetter alloc] initWithContainerClassID: [self class] key: key ivar: ivar] autorelease];
			if (getter == nil) {
				return nil;
			}
			return [[[_NSKeyBindingGetWrapper alloc] initWithAccessor: getter forKey: key] autorelease];
		}
	}
}

- (NSKeyBinding*)createKeyValueBindingForKey: (NSString*)key typeMask: (NSKeyValueBindingOptions)mask
{
	if (mask & NSKeyValueBindingIsStored) {
		if (!self.class.useStoredAccessor) {
			mask &= ~NSKeyValueBindingIsStored;
		}
	}

	BOOL isSetter = mask & NSKeyValueBindingForSetter;
	BOOL isStored = mask & NSKeyValueBindingIsStored;
	BOOL accessIVars = self.class.accessInstanceVariablesDirectly;
	NSKeyBinding* binding = nil;

	// don't use `capitalizedString`; that turns other letters into lowercase
	// (we only want the first letter to become uppercase and leave the rest alone)
	NSString* capitalizedKey = [NSString stringWithFormat: @"%@%@", [[key substringToIndex: 1] uppercaseString], [key substringFromIndex: 1]];

	if (isSetter) {
		if (isStored) {
			binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"_set%@:", capitalizedKey].UTF8String bindingType: NSKeyValueBindingTypeForSetter | NSKeyValueBindingTypeNoDirectAccess];
			if (accessIVars) {
				if (binding == nil) {
					binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"_%@", key].UTF8String bindingType: NSKeyValueBindingTypeForSetter];
				}
				if (binding == nil) {
					binding = [self _createKeyValueBindingForKey: key name: key.UTF8String bindingType: NSKeyValueBindingTypeForSetter];
				}
			}
			if (binding == nil) {
				binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"set%@:", capitalizedKey].UTF8String bindingType: NSKeyValueBindingTypeForSetter | NSKeyValueBindingTypeNoDirectAccess];
			}
		} else {
			binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"set%@:", capitalizedKey].UTF8String bindingType: NSKeyValueBindingTypeForSetter | NSKeyValueBindingTypeNoDirectAccess];
			if (binding == nil) {
				binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"_set%@:", capitalizedKey].UTF8String bindingType: NSKeyValueBindingTypeForSetter | NSKeyValueBindingTypeNoDirectAccess];
			}
			if (accessIVars) {
				if (binding == nil) {
					binding = [self _createKeyValueBindingForKey: key name: key.UTF8String bindingType: NSKeyValueBindingTypeForSetter];
				}
				if (binding == nil) {
					binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"_%@", key].UTF8String bindingType: NSKeyValueBindingTypeForSetter];
				}
			}
		}
	} else {
		if (isStored) {
			binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"_get%@", capitalizedKey].UTF8String bindingType: NSKeyValueBindingTypeForGetter | NSKeyValueBindingTypeNoDirectAccess];
			if (binding == nil) {
				binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"_%@", key].UTF8String bindingType: NSKeyValueBindingTypeForGetter | NSKeyValueBindingTypeNoDirectAccess];
			}
			if (accessIVars) {
				if (binding == nil) {
					binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"_%@", key].UTF8String bindingType: NSKeyValueBindingTypeForGetter];
				}
				if (binding == nil) {
					binding = [self _createKeyValueBindingForKey: key name: key.UTF8String bindingType: NSKeyValueBindingTypeForGetter];
				}
			}
			if (binding == nil) {
				binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"get%@", capitalizedKey].UTF8String bindingType: NSKeyValueBindingTypeForGetter | NSKeyValueBindingTypeNoDirectAccess];
			}
			if (binding == nil) {
				binding = [self _createKeyValueBindingForKey: key name: key.UTF8String bindingType: NSKeyValueBindingForGetter | NSKeyValueBindingTypeNoDirectAccess];
			}
		} else {
			binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"get%@", capitalizedKey].UTF8String bindingType: NSKeyValueBindingTypeForGetter | NSKeyValueBindingTypeNoDirectAccess];
			if (binding == nil) {
				binding = [self _createKeyValueBindingForKey: key name: key.UTF8String bindingType: NSKeyValueBindingForGetter | NSKeyValueBindingTypeNoDirectAccess];
			}
			if (binding == nil) {
				binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"_get%@", capitalizedKey].UTF8String bindingType: NSKeyValueBindingTypeForGetter | NSKeyValueBindingTypeNoDirectAccess];
			}
			if (binding == nil) {
				binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"_%@", key].UTF8String bindingType: NSKeyValueBindingTypeForGetter | NSKeyValueBindingTypeNoDirectAccess];
			}
			if (accessIVars) {
				if (binding == nil) {
					binding = [self _createKeyValueBindingForKey: key name: key.UTF8String bindingType: NSKeyValueBindingTypeForGetter];
				}
				if (binding == nil) {
					binding = [self _createKeyValueBindingForKey: key name: [NSString stringWithFormat: @"_%@", key].UTF8String bindingType: NSKeyValueBindingTypeForGetter];
				}
			}
		}
	}

	return binding;
}

- (NSKeyBinding*)keyValueBindingForKey: (NSString*)key typeMask: (NSKeyValueBindingOptions)mask
{
	// check if the implementation for the desired method is the default one
	IMP defaultImp = defaultImplementationForOptions(mask);
	IMP classImp = classImplementationForOptions(mask, [self class]);

	if (classImp == defaultImp) {
		NSKeyBinding* binding = bindingForClassAndKeyAndType(self, [self class], key, mask);
		if (binding != nil) {
			return [[binding retain] autorelease];
		}
	}

	if (mask & NSKeyValueBindingForSetter) {
		return [[[_NSKeyForwardingSetBinding alloc] initWithKey: key isStored: mask & NSKeyValueBindingIsStored] autorelease];
	} else {
		return [[[_NSKeyForwardingGetBinding alloc] initWithKey: key isStored: mask & NSKeyValueBindingIsStored] autorelease];
	}
}

@end
