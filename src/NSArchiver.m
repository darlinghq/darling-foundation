#import <Foundation/NSArchiver.h>
#import <Foundation/NSRaise.h>
#import <Foundation/NSMutableData.h>
#import <Foundation/NSMutableDictionary.h>
#import <Foundation/NSByteOrder.h>
#import <Foundation/NSGeometry.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyedArchiver.h>
#include <string.h>
#include <limits.h>
#include <dispatch/dispatch.h>
#include <objc/runtime.h>
#import "NSTypedStream.h"

static const int TypedStreamVersion = 4;
static const int ArchiverSystemVersion = 1000;

enum { NotEncodingRoot, NotingRootObjects, WritingRoot };

static const void *retainObject(CFAllocatorRef allocator, const void *value)
{
    return [(id)value retain];
}

static void releaseObject(CFAllocatorRef allocator, const void *value)
{
    [(id)value release];
}

// Keys are compared by identity: equal but distinct objects are archived separately.
static const CFDictionaryKeyCallBacks identityKeyCallBacks = {0, retainObject, releaseObject, NULL, NULL, NULL};
static const CFDictionaryValueCallBacks objectValueCallBacks = {0, retainObject, releaseObject, NULL, NULL};
static const CFSetCallBacks identitySetCallBacks = {0, retainObject, releaseObject, NULL, NULL, NULL};

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
    if (_objectLabels)
        CFRelease(_objectLabels);
    if (_unconditionalObjects)
        CFRelease(_unconditionalObjects);
    [_sharedStrings release];
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

- (id)initForWritingWithMutableData:(NSMutableData *)data
{
    self = [super init];
    if (self)
    {
        mdata = [data retain];
        replacementTable = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &identityKeyCallBacks, &objectValueCallBacks);
        _objectLabels = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &identityKeyCallBacks, NULL);
        _unconditionalObjects = CFSetCreateMutable(kCFAllocatorDefault, 0, &identitySetCallBacks);
        _sharedStrings = [[NSMutableDictionary alloc] init];

        [self _writeByte:TypedStreamVersion];
        const char *header = NSHostByteOrder() == NS_BigEndian ? "typedstream" : "streamtyped";
        [self _writeInt:strlen(header)];
        [mdata appendBytes:header length:strlen(header)];
        [self _writeInt:ArchiverSystemVersion];
    }
    return self;
}

#pragma mark - Typedstream primitives

- (void)_writeByte:(signed char)byte
{
    [mdata appendBytes:&byte length:1];
}

// Values that collide with a label byte are written in the 2- or 4-byte form.
- (void)_writeInt:(int)value
{
    if (value >= SmallestLabel && value <= SCHAR_MAX)
    {
        [self _writeByte:value];
    }
    else if (value >= SHRT_MIN && value <= SHRT_MAX)
    {
        short v = value;
        [self _writeByte:Long2Label];
        [mdata appendBytes:&v length:sizeof(v)];
    }
    else
    {
        [self _writeByte:Long4Label];
        [mdata appendBytes:&value length:sizeof(value)];
    }
}

- (void)_writeLabelReference:(NSUInteger)label
{
    [self _writeInt:(int)label + SmallestLabel];
}

- (void)_writeSharedString:(const char *)string
{
    if (string == NULL)
    {
        [self _writeByte:NullLabel];
        return;
    }
    NSData *key = [NSData dataWithBytes:string length:strlen(string)];
    NSNumber *index = _sharedStrings[key];
    if (index != nil)
    {
        [self _writeLabelReference:index.unsignedIntegerValue];
        return;
    }
    _sharedStrings[key] = @(_sharedStrings.count);
    [self _writeByte:NewLabel];
    [self _writeInt:(int)key.length];
    [mdata appendData:key];
}

- (NSUInteger)_takeObjectLabel:(id)object
{
    NSUInteger label = _nextObjectLabel++;
    if (object != nil)
        CFDictionarySetValue(_objectLabels, object, (const void *)label);
    return label;
}

- (BOOL)_writeReferenceIfLabeled:(id)object
{
    const void *label;
    if (!CFDictionaryGetValueIfPresent(_objectLabels, object, &label))
        return NO;
    [self _writeLabelReference:(NSUInteger)label];
    return YES;
}

- (void)_writeClass:(Class)cls
{
    if (cls == Nil)
    {
        [self _writeByte:NullLabel];
        return;
    }
    if ([self _writeReferenceIfLabeled:cls])
        return;

    NSString *name = [self classNameEncodedForTrueClassName:NSStringFromClass(cls)];
    [self _writeByte:NewLabel];
    [self _writeSharedString:name.UTF8String];
    [self _writeInt:(int)[cls version]];
    [self _takeObjectLabel:cls];
    [self _writeClass:class_getSuperclass(cls)];
}

- (id)_replacementForObject:(id)object
{
    if (object == nil)
        return nil;
    const void *replacement;
    if (CFDictionaryGetValueIfPresent(replacementTable, object, &replacement))
        return (id)replacement;
    id result = [object replacementObjectForArchiver:self];
    if (result != nil)
        CFDictionarySetValue(replacementTable, object, result);
    return result;
}

// The object label is taken before the class record, the order NSUnarchiver reads them in.
- (void)_writeObject:(id)object
{
    object = [self _replacementForObject:object];
    if (object == nil)
    {
        [self _writeByte:NullLabel];
        return;
    }
    if ([self _writeReferenceIfLabeled:object])
        return;

    if (_rootPass == NotingRootObjects)
        CFSetAddValue(_unconditionalObjects, object);
    [self _writeByte:NewLabel];
    [self _takeObjectLabel:object];
    [self _writeClass:[object classForArchiver]];
    [object encodeWithCoder:self];
    [self _writeByte:EndOfObjectLabel];
}

- (const char *)_writeType:(const char *)type at:(const void *)addr
{
    const char *next = type + 1;

    switch (*type)
    {
        case 'c':
        case 'C':
            [self _writeByte:*(const signed char *)addr];
            break;
        case 's':
        case 'S':
            [self _writeInt:*(const short *)addr];
            break;
        case 'i':
        case 'I':
        case 'l':
        case 'L':
            [self _writeInt:*(const int *)addr];
            break;
        case 'q':
        {
            long long value = *(const long long *)addr;
            if (value < INT_MIN || value > INT_MAX)
                [NSException raise:NSInvalidArchiveOperationException format:@"NSArchiver: %lld does not fit the 32-bit typedstream integer", value];
            [self _writeInt:(int)value];
            break;
        }
        case 'Q':
        {
            unsigned long long value = *(const unsigned long long *)addr;
            if (value > UINT_MAX)
                [NSException raise:NSInvalidArchiveOperationException format:@"NSArchiver: %llu does not fit the 32-bit typedstream integer", value];
            [self _writeInt:(int)(unsigned int)value];
            break;
        }
        case 'f':
            [self _writeByte:RealLabel];
            [mdata appendBytes:addr length:sizeof(float)];
            break;
        case 'd':
            [self _writeByte:RealLabel];
            [mdata appendBytes:addr length:sizeof(double)];
            break;
        case '@':
            [self _writeObject:*(id const *)addr];
            break;
        case '*':
        {
            const char *string = *(const char * const *)addr;
            if (string == NULL)
            {
                [self _writeByte:NullLabel];
                break;
            }
            [self _writeByte:NewLabel];
            [self _writeSharedString:string];
            [self _takeObjectLabel:nil];
            break;
        }
        case '#':
            [self _writeClass:*(Class const *)addr];
            break;
        case '%':
            [self _writeSharedString:*(const char * const *)addr];
            break;
        case ':':
        {
            SEL selector = *(const SEL *)addr;
            [self _writeSharedString:selector ? sel_getName(selector) : NULL];
            break;
        }
        case '[':
        {
            char *elementType;
            unsigned long count = strtoul(next, &elementType, 10);
            unsigned int size, alignment;
            next = sizeofType(elementType, &size, &alignment);
            for (unsigned long i = 0; i < count; i++)
                [self _writeType:elementType at:(const char *)addr + i * size];
            if (*next++ != ']')
                [NSException raise:NSInvalidArgumentException format:@"NSArchiver: bad array type '%s'", type];
            break;
        }
        case '{':
        {
            unsigned int offset = 0;
            const char *field = skipStructName(next);
            while (*field != '}')
            {
                unsigned int size, alignment;
                sizeofType(field, &size, &alignment);
                offset = roundUp(offset, alignment);
                field = [self _writeType:field at:(const char *)addr + offset];
                offset += size;
            }
            next = field + 1;
            break;
        }
        case '(':
        {
            unsigned int size, alignment;
            next = sizeofType(type, &size, &alignment);
            for (unsigned int i = 0; i < size; i++)
                [self _writeByte:((const signed char *)addr)[i]];
            break;
        }
        default:
            [NSException raise:NSInvalidArgumentException format:@"NSArchiver: cannot archive type '%s'", type];
    }
    return next;
}

#pragma mark - NSCoder

- (void)encodeValueOfObjCType:(const char *)type at:(const void *)addr
{
    // NSUnarchiver reads BOOL as 'c', as on platforms where BOOL is a signed char.
    if (strcmp(type, @encode(BOOL)) == 0)
        type = "c";
    [self _writeSharedString:type];
    [self _writeType:type at:addr];
}

- (void)encodeValuesOfObjCTypes:(const char *)types, ...
{
    va_list args;
    va_start(args, types);
    [self _writeSharedString:types];
    for (const char *type = types; *type != '\0'; )
        type = [self _writeType:type at:va_arg(args, const void *)];
    va_end(args);
}

- (void)encodeBytes:(const void *)addr length:(NSUInteger)len
{
    if (len > INT_MAX)
        [NSException raise:NSInvalidArchiveOperationException format:@"NSArchiver: %lu bytes do not fit the typedstream length", (unsigned long)len];
    [self _writeSharedString:"+"];
    [self _writeInt:(int)len];
    [mdata appendBytes:addr length:len];
}

- (void)encodeDataObject:(NSData *)object
{
    int len = [object length];
    const void *bytes = [object bytes];
    [self encodeValueOfObjCType:@encode(int) at:&len];
    [self encodeArrayOfObjCType:@encode(char) count:len at:bytes];
}

// Two passes, as conditional objects are only written if the graph also encodes them unconditionally.
- (void)encodeRootObject:(id)object
{
    if (_rootPass != NotEncodingRoot)
        [NSException raise:NSInvalidArgumentException format:@"NSArchiver: encodeRootObject: called while encoding a root object"];

    NSUInteger length = mdata.length;
    NSUInteger nextLabel = _nextObjectLabel;
    NSMutableDictionary *sharedStrings = [_sharedStrings mutableCopy];
    CFMutableDictionaryRef objectLabels = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, _objectLabels);

    @try
    {
        _rootPass = NotingRootObjects;
        @try
        {
            [self encodeObject:object];
        }
        @finally
        {
            mdata.length = length;
            _nextObjectLabel = nextLabel;
            [_sharedStrings release];
            _sharedStrings = sharedStrings;
            CFRelease(_objectLabels);
            _objectLabels = objectLabels;
        }

        _rootPass = WritingRoot;
        [self encodeObject:object];
    }
    @finally
    {
        CFSetRemoveAllValues(_unconditionalObjects);
        _rootPass = NotEncodingRoot;
    }
}

- (void)encodeConditionalObject:(id)object
{
    [self _writeSharedString:@encode(id)];
    id replacement = [self _replacementForObject:object];
    BOOL wanted = replacement != nil &&
        (CFDictionaryContainsKey(_objectLabels, replacement) ||
         (_rootPass == WritingRoot && CFSetContainsValue(_unconditionalObjects, replacement)));
    if (wanted)
        [self _writeObject:object];
    else
        [self _writeByte:NullLabel];
}

- (NSInteger)versionForClassName:(NSString *)className
{
    Class cls = NSClassFromString(className);
    return cls != Nil ? [cls version] : NSNotFound;
}

- (void)replaceObject:(id)object withObject:(id)replacement
{
    CFDictionarySetValue(replacementTable, object, replacement);
}

- (id)data
{
    return mdata;
}

- (id)archiverData
{
    return mdata;
}

@end
