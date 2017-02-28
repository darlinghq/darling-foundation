#import "NSKeyValueProperty.h"

@class NSString;

CF_PRIVATE
@interface NSKeyValueNestedProperty : NSKeyValueProperty
{
	NSString* _relationshipKey;
	NSString* _keyPathFromRelatedObject;
	NSKeyValueProperty* _relationshipProperty;
	NSString* _keyPathWithoutOperatorComponents;
	BOOL _isAllowedToResultInForwarding;
	id _dependentValueKeyOrKeys;
	BOOL _dependentValueKeyOrKeysIsASet;
}

@property (copy, nonatomic) NSString *relationshipKey;
@property (copy, nonatomic) NSString *keyPathFromRelatedObject;
@property (retain, nonatomic) NSKeyValueProperty *relationshipProperty;
@property (copy, nonatomic) NSString *keyPathWithoutOperatorComponents;
@property (assign, nonatomic) BOOL isAllowedToResultInForwarding;
@property (retain, nonatomic) id dependentValueKeyOrKeys; 
@property (assign, nonatomic) BOOL dependentValueKeyOrKeysIsASet; // TODO: this is dumb. Make it always a set.

- (NSString *)_keyPathIfAffectedByValueForMemberOfKeys:(NSSet *)keys;
- (NSString *)_keyPathIfAffectedByValueForKey:(NSString *)key exactMatch:(BOOL *)exactMatch;
- (Class)_isaForAutonotifying;
- (void)_addDependentValueKey:(NSString *)key;
- (void)_givenPropertiesBeingInitialized:(CFMutableSetRef)properties getAffectingProperties:(NSMutableArray *)affectingProperties;
- (instancetype)_initWithContainerClass:(NSKeyValueContainerClass *)containerClass keyPath:(NSString *)keyPath firstDotIndex:(NSUInteger)firstDotIndex propertiesBeingInitialized:(CFMutableSetRef)propertiesBeingInitialized;
@end
