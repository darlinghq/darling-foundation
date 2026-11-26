#import <Foundation/NSObject.h>

@class NSString, NSData, NSSet<__covariant ObjectType>;

typedef NS_ENUM(NSInteger, NSDecodingFailurePolicy) {
    NSDecodingFailurePolicyRaiseException,
    NSDecodingFailurePolicySetErrorAndReturn,
} API_AVAILABLE(macos(10.13), ios(11.0), watchos(4.0), tvos(11.0));

@interface NSCoder : NSObject

- (void)encodeValueOfObjCType:(const char *)type at:(const void *)addr;
- (void)encodeDataObject:(NSData *)data;
- (void)decodeValueOfObjCType:(const char *)type at:(void *)data;
- (void)decodeValueOfObjCType:(const char *)type at:(void *)data size:(NSUInteger)size API_AVAILABLE(macos(10.13), ios(11.0), watchos(4.0), tvos(11.0));
- (NSData *)decodeDataObject;
- (NSInteger)versionForClassName:(NSString *)className;

@end

@interface NSCoder (NSExtendedCoder)

- (void)encodeObject:(id)obj;
- (void)encodeRootObject:(id)root;
- (void)encodeBycopyObject:(id)obj;
- (void)encodeByrefObject:(id)obj;
- (void)encodeConditionalObject:(id)object;
- (void)encodeValuesOfObjCTypes:(const char *)types, ...;
- (void)encodeArrayOfObjCType:(const char *)type count:(NSUInteger)count at:(const void *)array;
- (void)encodeBytes:(const void *)addr length:(NSUInteger)len;
- (id)decodeObject;
- (void)decodeValuesOfObjCTypes:(const char *)types, ...;
- (void)decodeArrayOfObjCType:(const char *)itemType count:(NSUInteger)count at:(void *)array;
- (void *)decodeBytesWithReturnedLength:(NSUInteger *)len NS_RETURNS_INNER_POINTER;
- (void)setObjectZone:(NSZone *)zone NS_AUTOMATED_REFCOUNT_UNAVAILABLE;
- (NSZone *)objectZone NS_AUTOMATED_REFCOUNT_UNAVAILABLE;
- (unsigned)systemVersion;
- (BOOL)allowsKeyedCoding;
- (void)encodeObject:(id)obj forKey:(NSString *)key;
- (void)encodeConditionalObject:(id)obj forKey:(NSString *)key;
- (void)encodeBool:(BOOL)value forKey:(NSString *)key;
- (void)encodeInt:(int)value forKey:(NSString *)key;
- (void)encodeInt32:(int32_t)value forKey:(NSString *)key;
- (void)encodeInt64:(int64_t)value forKey:(NSString *)key;
- (void)encodeFloat:(float)value forKey:(NSString *)key;
- (void)encodeDouble:(double)value forKey:(NSString *)key;
- (void)encodeBytes:(const uint8_t *)buffer length:(NSUInteger)len forKey:(NSString *)key;
- (BOOL)containsValueForKey:(NSString *)key;
- (id)decodeObjectForKey:(NSString *)key;
- (BOOL)decodeBoolForKey:(NSString *)key;
- (int)decodeIntForKey:(NSString *)key;
- (int32_t)decodeInt32ForKey:(NSString *)key;
- (int64_t)decodeInt64ForKey:(NSString *)key;
- (float)decodeFloatForKey:(NSString *)key;
- (double)decodeDoubleForKey:(NSString *)key;
- (const uint8_t *)decodeBytesForKey:(NSString *)key returnedLength:(NSUInteger *)len NS_RETURNS_INNER_POINTER;
- (void)encodeInteger:(NSInteger)value forKey:(NSString *)key;
- (NSInteger)decodeIntegerForKey:(NSString *)key;
@property (readonly) BOOL requiresSecureCoding;
- (id)decodeObjectOfClass:(Class)aClass forKey:(NSString *)key;
- (nullable id)decodeObjectOfClasses:(nullable NSSet<Class> *)classes forKey:(NSString *)key;
- (id)decodePropertyListForKey:(NSString *)key;
@property (nullable, readonly, copy) NSSet<Class> *allowedClasses API_AVAILABLE(macos(10.8), ios(6.0), watchos(2.0), tvos(9.0));
- (id)decodeTopLevelObjectAndReturnError:(NSError **)error NS_SWIFT_UNAVAILABLE("Use 'decodeTopLevelObject() throws' instead");
- (id)decodeTopLevelObjectForKey:(NSString *)key error:(NSError **)error NS_SWIFT_UNAVAILABLE("Use 'decodeObject(of:, forKey:)' instead");
- (id)decodeTopLevelObjectOfClass:(Class)aClass forKey:(NSString *)key error:(NSError **)error NS_SWIFT_UNAVAILABLE("Use 'decodeObject(of:, forKey:)' instead");
- (id)decodeTopLevelObjectOfClasses:(NSSet<Class> *)classes forKey:(NSString *)key error:(NSError **)error NS_SWIFT_UNAVAILABLE("Use 'decodeObject(of:, forKey:)' instead");
- (NSArray *)decodeArrayOfObjectsOfClass:(Class)cls forKey:(NSString *)key NS_REFINED_FOR_SWIFT;
- (NSArray *)decodeArrayOfObjectsOfClasses:(NSSet<Class> *)classes forKey:(NSString *)key NS_REFINED_FOR_SWIFT;
- (NSDictionary *)decodeDictionaryWithKeysOfClass:(Class)keyCls objectsOfClass:(Class)objectCls forKey:(NSString *)key NS_REFINED_FOR_SWIFT;
- (NSDictionary *)decodeDictionaryWithKeysOfClasses:(NSSet<Class> *)keyClasses objectsOfClasses:(NSSet<Class> *)objectClasses forKey:(NSString *)key NS_REFINED_FOR_SWIFT;

@end
