#import <Foundation/NSObject.h>

@class NSArray<ObjectType>;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    unsigned long state;
    id __unsafe_unretained * _Nullable itemsPtr;
    unsigned long * _Nullable mutationsPtr;
    unsigned long extra[5];
} NSFastEnumerationState;

@protocol NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained _Nullable[_Nonnull])buffer count:(NSUInteger)len;

@end

@interface NSEnumerator<ObjectType> : NSObject <NSFastEnumeration>

- (nullable ObjectType)nextObject;

@end

@interface NSEnumerator<ObjectType> (NSExtendedEnumerator)

@property (readonly, copy) NSArray<ObjectType> *allObjects;

@end

NS_ASSUME_NONNULL_END
