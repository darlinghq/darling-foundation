#import <Foundation/NSCoder.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSHashTable.h>
#import <Foundation/NSMapTable.h>
#import <CoreFoundation/CFDictionary.h>

@interface NSArchiver : NSCoder
{
    NSMutableData *mdata;
    void *ids;
    CFMutableDictionaryRef replacementTable;
    NSMutableDictionary<NSString*,NSString*>* map;
}

+ (BOOL)archiveRootObject:(id)object toFile:(NSString *)path;
+ (id)archivedDataWithRootObject:(id)object;
+ (void)initialize;
- (NSString *)classNameEncodedForTrueClassName:(NSString *)name;
- (void)encodeClassName:(NSString *)name intoClassName:(NSString *)encoded;
- (void)encodeConditionalObject:(id)object;
- (void)encodeRootObject:(id)object;
- (void)encodeDataObject:(NSData *)object;
- (void)encodeObject:(id)object;
- (void)encodeBytes:(const void *)addr length:(NSUInteger)len;
- (void)encodeArrayOfObjCType:(const char *)type count:(NSUInteger)count at:(const void *)array;
- (void)encodeValuesOfObjCTypes:(const char *)types, ...;
- (void)encodeValueOfObjCType:(const char *)type at:(const void *)addr;
- (NSInteger)versionForClassName:(NSString *)className;
- (void)replaceObject:(id)object withObject:(id)replacement;
- (void)dealloc;
- (id)data;
- (id)archiverData;
- (id)initForWritingWithMutableData:(NSMutableData *)data;
- (NSString *)classNameEncodedForTrueClassName:(NSString *)trueName;

@end

@interface NSUnarchiver : NSCoder
{
    NSData* _data;
    NSZone* _objectZone;
    NSUInteger              _pos;
    int                     _streamerVersion;
    BOOL                    _swap;
    NSMutableArray*         _sharedStrings;
    NSMutableDictionary*    _sharedObjects;
    NSUInteger              _sharedObjectCounter;
    NSMutableDictionary*    _versionByClassName;
    NSMutableDictionary<NSString*,NSString*>* _classNameMap;
    unsigned _systemVersion;
}

@property (nonatomic, readonly, copy)   NSData* data;
@property (nonatomic, readonly)         BOOL    isAtEnd;
@property (nonatomic) NSZone* objectZone;

+ (void)initialize;
+ (NSString *)classNameDecodedForArchiveClassName:(NSString *)name;
+ (void)decodeClassName:(NSString *)internalName asClassName:(NSString *)externalName;
+ (id)unarchiveObjectWithFile:(NSString *)path;
+ (id)unarchiveObjectWithData:(NSData *)data;
- (id)initForReadingWithData:(NSData *)data;
- (void)dealloc;
- (NSString *)classNameDecodedForArchiveClassName:(NSString *)name;
- (void)decodeClassName:(NSString *)internalName asClassName:(NSString *)externalName;
- (id)decodeDataObject;
- (void *)decodeBytesWithReturnedLength:(NSUInteger *)len;
- (void)decodeValueOfObjCType:(const char *)type at:(void *)data;
- (NSInteger)versionForClassName:(NSString *)className;
- (BOOL)isAtEnd;
- (NSZone *)objectZone;
- (void)setObjectZone:(NSZone *)zone;
- (void)replaceObject:(id)obj withObject:(id)replacement;
- (uint8_t)decodeByte;
- (unsigned)systemVersion;

@end

@interface NSObject (NSArchiverCallBack)
- (id)replacementObjectForArchiver:(NSArchiver *)archiver;
- (Class)classForArchiver;
@end
