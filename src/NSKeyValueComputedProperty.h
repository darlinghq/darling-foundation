#import "NSKeyValueProperty.h"

@class NSString;

CF_PRIVATE
@interface NSKeyValueComputedProperty : NSKeyValueProperty
{
	NSKeyValueProperty* _operationArgumentProperty;
	NSString* _operationArgumentKeyPath;
	NSString* _operationName;
}

@property (nonatomic, retain) NSKeyValueProperty *operationArgumentProperty;
@property (nonatomic, copy) NSString *operationArgumentKeyPath;
@property (nonatomic, copy) NSString *operationName;

- (NSString *)_keyPathIfAffectedByValueForMemberOfKeys:(NSSet *)keys;
- (NSString *)_keyPathIfAffectedByValueForKey:(NSString *)key exactMatch:(BOOL *)exactMatch;
- (Class)_isaForAutonotifying;
- (void)_addDependentValueKey:(NSString *)key;
- (void)_givenPropertiesBeingInitialized:(CFMutableSetRef)properties getAffectingProperties:(NSMutableArray *)affectingProperties;
@end
