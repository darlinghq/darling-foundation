#import <Foundation/NSArchiver.h>
#import <Foundation/NSRaise.h>
#import <Foundation/NSMutableData.h>
#import <Foundation/NSMutableDictionary.h>
#import <Foundation/NSByteOrder.h>
#import <Foundation/NSGeometry.h>
#include <string.h>

@implementation NSObject (NSArchiverCallBack)

- (id)replacementObjectForArchiver:(NSArchiver *)archiver
{
    return self;
}

- (Class)classForArchiver
{
    return [self classForCoder];
}

@end



@implementation NSArchiver

- (void)dealloc
{
    [mdata release];
    if (replacementTable)
        CFRelease(replacementTable);

    [map release];
    [super dealloc];
}

+ (BOOL)archiveRootObject:(id)object toFile:(NSString *)path
{
    NSData *data = [self archivedDataWithRootObject:object];
    return [data writeToFile:path atomically:YES];
}

+ (id)archivedDataWithRootObject:(id)object
{
    NSMutableData *data = [NSMutableData data];
    @autoreleasepool {
        NSArchiver *archiver = [[[self alloc] initForWritingWithMutableData:data] autorelease];
        [archiver encodeRootObject:object];
    }
    return data;
}

static dispatch_once_t encodedClassNamesOnce = 0L;
static NSMutableDictionary *encodedClassNames = nil;

+ (NSString *)classNameEncodedForTrueClassName:(NSString *)name
{
    dispatch_once(&encodedClassNamesOnce, ^{
        encodedClassNames = [[NSMutableDictionary alloc] init];
    });
    return [encodedClassNames objectForKey:name];
}

+ (void)encodeClassName:(NSString *)name intoClassName:(NSString *)encoded
{
    dispatch_once(&encodedClassNamesOnce, ^{
        encodedClassNames = [[NSMutableDictionary alloc] init];
    });
    [encodedClassNames setObject:encoded forKey:name];
}

+ (void)initialize
{
    // I am surprised this is the only one that hits...
    [NSArchiver encodeClassName:@"__NSLocalTimeZone" intoClassName:@"NSLocalTimeZone"];
}

- (NSString *)classNameEncodedForTrueClassName:(NSString *)name
{
    if (map == nil)
    {
        map = [[NSMutableDictionary alloc] init];
    }
    NSString *encodedName = [map objectForKey:name];
    if (encodedName == nil)
    {
        encodedName = [NSArchiver classNameEncodedForTrueClassName:name];
    }
    if (encodedName == nil)
    {
        encodedName = name;
    }
    return encodedName;
}

- (void)encodeClassName:(NSString *)name intoClassName:(NSString *)encoded
{
    if (map == nil)
    {
        map = [[NSMutableDictionary alloc] init];
    }
    [map setObject:encoded forKey:name];
}

- (void)encodeConditionalObject:(id)object
{
    if (mdata != NULL)
    {
        if (ids == NULL)
        {
            // fault; throw exception here for requiring encodeRootObject:
        }
        id replacement = nil;
        if (replacementTable == NULL)
        {
            replacementTable = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, NULL);
        }
        if (!CFDictionaryGetValueIfPresent(replacementTable, object, (const void **)&replacement))
        {
            replacement = [object replacementObjectForArchiver:self];
            CFDictionarySetValue(replacementTable, object, replacement);
        }

        // CFSetGetValue(ids, replacement) ?
        
        if (replacement != nil)
        {
            [self encodeObject:object];
        }
    }
}

- (void)encodeRootObject:(id)object
{

}

- (void)encodeDataObject:(NSData *)object
{
    int len = [object length];
    const void *bytes = [object bytes];
    [self encodeValueOfObjCType:@encode(int) at:&len];
    [self encodeArrayOfObjCType:@encode(char) count:len at:bytes];
}

- (id)initForWritingWithMutableData:(NSMutableData *)data
{
    self = [super init];
    if (self)
    {
        mdata = [data retain];
    }
    return self;
}

- (void)encodeObject:(id)object
{
	NSLog(@"STUB: NSArchiver %@", NSStringFromSelector(_cmd));
}

- (void)encodeBytes:(const void *)addr length:(NSUInteger)len
{
	NSLog(@"STUB: NSArchiver %@", NSStringFromSelector(_cmd));
}

- (void)encodeArrayOfObjCType:(const char *)type 
                        count:(NSUInteger)count 
                           at:(const void *)array
{
	NSLog(@"STUB: NSArchiver %@", NSStringFromSelector(_cmd));
}

- (void)encodeValuesOfObjCTypes:(const char *)types, ...
{
	NSLog(@"STUB: NSArchiver %@", NSStringFromSelector(_cmd));
}

- (void)encodeValueOfObjCType:(const char *)type 
                           at:(const void *)addr
{
	NSLog(@"STUB: NSArchiver %@", NSStringFromSelector(_cmd));
}

- (NSInteger)versionForClassName:(NSString *)className
{
	NSLog(@"STUB: NSArchiver %@", NSStringFromSelector(_cmd));
	return 0;
}

- (void)replaceObject:(id)object withObject:(id)replacement
{
	NSLog(@"STUB: NSArchiver %@", NSStringFromSelector(_cmd));
}

- (id)data
{
	NSLog(@"STUB: NSArchiver %@", NSStringFromSelector(_cmd));
	return nil;
}

- (id)archiverData
{
	NSLog(@"STUB: NSArchiver %@", NSStringFromSelector(_cmd));
	return nil;
}

@end
