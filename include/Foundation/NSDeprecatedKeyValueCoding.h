#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@interface NSKeyBinding : NSObject {
	Class _targetClass;
	NSString* _key;
}

// note: Apple's implemention provides no setter for `targetClass`
@property(assign) Class targetClass;
@property(copy) NSString* key;

+ (void)suppressCapitalizedKeyWarning;

@end

@interface NSKeyGetBinding : NSKeyBinding {
}

- (id)getValueFromObject: (id)object;

@end

@interface NSKeySetBinding : NSKeyBinding {
}

@property(readonly) BOOL isScalarProperty;

- (void)setValue: (id)value inObject: (id)object;

@end

@interface _NSKeyForwardingGetBinding : NSKeyGetBinding {
	BOOL _isStored;
}

- (instancetype)initWithKey: (NSString*)key isStored: (BOOL)isStored;

@end

@interface _NSKeyForwardingSetBinding : NSKeySetBinding {
	BOOL _isStored;
}

- (instancetype)initWithKey: (NSString*)key isStored: (BOOL)isStored;

@end

@class NSKeyValueGetter;
@class NSKeyValueSetter;

// these classes wrap "modern" accessors for key-value bindings
// to avoid duplicating code for the deprecated bindings (because they seem to have the same behavior)

@interface _NSKeyBindingGetWrapper : NSKeySetBinding {
	NSKeyValueGetter* _wrappedAccessor;
}

- (instancetype)initWithAccessor: (NSKeyValueGetter*)accessor forKey: (NSString*)key;

@end

@interface _NSKeyBindingSetWrapper : NSKeySetBinding {
	NSKeyValueSetter* _wrappedAccessor;
	BOOL _isScalar;
}

- (instancetype)initWithAccessor: (NSKeyValueSetter*)accessor forKey: (NSString*)key isScalar: (BOOL)isScalar;

@end

// no clue what the correct names for the type and options are
typedef NS_OPTIONS(NSUInteger, NSKeyValueBindingOptions) {
	NSKeyValueBindingForGetter = 0 << 0,
	NSKeyValueBindingForSetter = 1 << 0,
	NSKeyValueBindingIsStored  = 1 << 1,
};

#define NSKeyValueBindingOptionsMask ( \
		NSKeyValueBindingForGetter | \
		NSKeyValueBindingForSetter | \
		NSKeyValueBindingIsStored \
	)

// again, no clue as to the naming
typedef NS_OPTIONS(NSUInteger, NSKeyValueBindingType) {
	NSKeyValueBindingTypeForGetter = NSKeyValueBindingForGetter,
	NSKeyValueBindingTypeForSetter = NSKeyValueBindingForSetter,
	NSKeyValueBindingTypeNoDirectAccess = 1 << 2,
};

@interface NSObject (NSDeprecatedKeyValueCoding)

+ (BOOL)useStoredAccessor;

- (NSKeyBinding*)_createKeyValueBindingForKey: (NSString*)key name: (const char*)name bindingType: (NSKeyValueBindingType)type;
- (NSKeyBinding*)createKeyValueBindingForKey: (NSString*)key typeMask: (NSKeyValueBindingOptions)mask;
- (NSKeyBinding*)keyValueBindingForKey: (NSString*)key typeMask: (NSKeyValueBindingOptions)mask;

- (id)_oldValueForKey: (NSString*)key;
- (id)storedValueForKey: (NSString*)key;

- (void)takeValue: (id)value forKey: (NSString*)key;
- (void)takeStoredValue: (id)value forKey: (NSString*)key;

- (id)handleQueryWithUnboundKey: (NSString*)key;
- (void)handleTakeValue: (id)value forUnboundKey: (NSString*)key;
- (void)unableToSetNilForKey: (NSString*)key;

@end
