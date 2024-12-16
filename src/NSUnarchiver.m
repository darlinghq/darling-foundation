/*
Copyright (C) 2015 Frank Illenberger
Copyright (C) 2020 Lubos Dolezel

*/

#import <Foundation/NSArchiver.h>
#import <Foundation/NSRaise.h>
#import <Foundation/NSData.h>
#import <Foundation/NSMutableArray.h>
#import <Foundation/NSByteOrder.h>
#import <Foundation/NSGeometry.h>
#include <CoreFoundation/CFSet.h>
#include <string.h>
#include <dispatch/dispatch.h>
#include <objc/runtime.h>

static NSMutableDictionary<NSString*,NSString*>* globalClassNameMap;

static signed char const Long2Label         = -127;     // 0x81
static signed char const Long4Label         = -126;     // 0x82
static signed char const RealLabel          = -125;     // 0x83
static signed char const NewLabel           = -124;     // 0x84
static signed char const NullLabel          = -123;     // 0x85
static signed char const EndOfObjectLabel   = -122;     // 0x86
static signed char const SmallestLabel      = -110;     // 0x92

#define BIAS(x) (x - SmallestLabel)

//#define DEBUG_NSUNARCHIVER
#ifndef DEBUG_NSUNARCHIVER
#  define NSUDEBUG(...)
#else
#  define NSUDEBUG NSLog
#endif

static const char* uniqueString(const char* str);
static const char* sizeofType(const char* type, unsigned int* size, unsigned int* align);
static const char* skipStructName(const char* str);
static unsigned int roundUp(unsigned int size, unsigned int align);

@implementation NSUnarchiver

+ (id)unarchiveObjectWithFile:(NSString *)path
{
   NSData* data= [NSData dataWithContentsOfFile: path];

   if (data == nil)
      return nil;

   NSUnarchiver* unarchiver = [[[NSUnarchiver alloc] initForReadingWithData: data] autorelease];

   return [unarchiver decodeObject];
}

+ (id)unarchiveObjectWithData:(NSData *)data
{
   NSUnarchiver* unarchiver = [[[NSUnarchiver alloc] initForReadingWithData: data] autorelease];
   return [unarchiver decodeObject];
}

- (NSData *)decodeDataObject
{
   int length;
   NSMutableData* data;

   [self decodeValuesOfObjCTypes: "i", &length];

   data = [[NSMutableData alloc] initWithLength: length];

   [self decodeArrayOfObjCType: "c" count: length at: [data mutableBytes]];

   return [data autorelease];
}

-(NSZone *)objectZone
{
   return _objectZone;
}

-(NSData*)data
{
   return _data;
}

-(void)setObjectZone:(NSZone *) zone
{
   _objectZone = zone;
}

+(void)initialize
{
	globalClassNameMap = [[NSMutableDictionary alloc] init];
}

- (void)dealloc
{
    [_sharedStrings release];
    [_sharedObjects release];
    [_versionByClassName release];
    [_classNameMap release];
    [_data release];

    [super dealloc];
}

- (id)initForReadingWithData:(NSData*)data
{
    NSParameterAssert(data.length > 0);
    
    if(self = [super init])
    {
        _data = [data copy];
        _pos = 0;
        _sharedObjects = [[NSMutableDictionary alloc] init];
        _sharedStrings = [[NSMutableArray alloc] init];
        _versionByClassName = [[NSMutableDictionary alloc] init];
        if(![self readHeader])
            return nil;
    }
    return self;
}

- (BOOL)isAtEnd
{
    return _pos >= _data.length;
}
- (Class)classForName:(NSString*)className
{
   NSParameterAssert(className);

   NSString* replacement = [self classNameDecodedForArchiveClassName: className];
   if (replacement == className)
      replacement = [NSUnarchiver classNameDecodedForArchiveClassName: className];
    
   return NSClassFromString(replacement);
}

- (BOOL)readHeader
{
    signed char streamerVersion;
    if(![self decodeChar:&streamerVersion])
        return NO;
    _streamerVersion = streamerVersion;
    NSAssert(streamerVersion == 4, nil);    // we currently only support v4
    
    NSString* header;
    if(![self decodeCharsAsString:&header])
        return NO;
    
    BOOL isBig = (NSHostByteOrder() == NS_BigEndian);
    if([header isEqualToString:@"typedstream"])
        _swap = !isBig;
    else if([header isEqualToString:@"streamtyped"])
        _swap = isBig;
    else
        return NO;
    
    if(![self decodeInt: (int*)&_systemVersion])
        return NO;
    
    return YES;
}

- (unsigned)systemVersion
{
    return _systemVersion;
}

- (BOOL)readObject:(id*)outObject
{
    NSString* string;
    *outObject = nil;

    if(![self decodeSharedString:&string])
    {
       NSUDEBUG(@"NSUnarchiver readObject: decodeSharedString failed\n");
        return NO;
    }
    if(![string isEqualToString:@"@"])
    {
       NSUDEBUG(@"NSUnarchiver readObject: unexpected type: %@\n", string);
        return NO;
    }
    
    return [self _readObject:outObject];
}

- (NSNumber*)nextSharedObjectLabel
{
    return @(_sharedObjectCounter++);
}

- (BOOL)_readObject:(id*)outObject
{
    NSParameterAssert(outObject);

    *outObject = nil;
    
    signed char ch;
    if(![self decodeChar:&ch])
    {
       NSUDEBUG(@"NSUnarchiver _readObject: failed to decode char\n");
        return NO;
    }
    
    switch(ch)
    {
        case NullLabel:
            NSUDEBUG(@"readObject -> nil\n");
            *outObject = nil;
            return YES;
            
        case NewLabel:
        {
            NSNumber* label = [self nextSharedObjectLabel];
            NSUDEBUG(@"NSUnarchiver _readObject: new label %@, outObject at %p\n", label, outObject);
            Class objectClass;
            if(![self readClass:&objectClass])
            {
               NSUDEBUG(@"NSUnarchiver _readObject: failed to read class!\n");
                return NO;
            }
            NSUDEBUG(@"Will now initWithCoder on class %@\n", NSStringFromClass(objectClass));

            id object = [objectClass alloc];
            if(!object)
                return NO;
            _sharedObjects[label] = object;

            id object2 = [object initWithCoder:self];
            if (object2 != object)
               NSUDEBUG(@"NSUnarchiver: This may not work out, instance changed\n");

            id objectAfterAwake = [object2 awakeAfterUsingCoder:self];
            if(objectAfterAwake && objectAfterAwake != object2)
                object2 = objectAfterAwake;
            
            _sharedObjects[label] = object2;
            NSUDEBUG(@"Saving %p into outObject at %p\n", object2, outObject);
            *outObject = object2;
            
            signed char endMarker;
            if(![self decodeChar:&endMarker] || endMarker != EndOfObjectLabel)
            {
                NSLog(@"BUG: End of object label not found! This means [%@ initWithCoder:] (or super-class) isn't properly implemented.\n", NSStringFromClass(objectClass));
                NSLog(@"Decoded byte had value 0x%02x (should be 0x86)\n", ((unsigned) endMarker) & 0xff);

                uint8_t buf[8];
                [_data getBytes:buf range:NSMakeRange(_pos, 8)];
                NSLog(@"Following bytes: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x\n", buf[0], buf[1], buf[2], buf[3], buf[4], buf[5], buf[6], buf[7]);

                // Should be NSInconsistentArchiveException
                [NSException raise:NSInvalidArgumentException format:@"Fix [%@ initWithCoder:]", NSStringFromClass(objectClass)];

                __builtin_unreachable();
            }
            
            return YES;
        }
            
        default:
        {
            NSUDEBUG(@"readObject -> sharedObject\n");
            int label;
            if(![self finishDecodeInt:&label withChar:ch])
            {
               NSUDEBUG(@"readObject -> sharedObject: FAILED to decode int\n");
                return NO;
            }
            label = BIAS(label);
            *outObject = _sharedObjects[@(label)];
            if (!*outObject)
            {
               NSUDEBUG(@"readObject -> sharedObject: non-existent shared obj for label %d\n", label);
               return NO;
            }
            else
                NSUDEBUG(@"sharedObject is %p\n", *outObject);
            return YES;
        }
    }
}

- (BOOL)readClass:(Class*)outClass
{
    NSParameterAssert(outClass);
    
    signed char ch;
    if(![self decodeChar:&ch])
    {
       NSUDEBUG(@"NSUnarchiver readClass: decodeChar failed\n");
        return NO;
    }
    
    switch(ch)
    {
        case NullLabel:
            *outClass = Nil;
            return YES;
            
        case NewLabel:
        {
            NSString* className;
            if(![self decodeSharedString:&className])
            {
               NSUDEBUG(@"NSUnarchiver readClass: decodeSharedString failed\n");
                return NO;
            }
            int version;
            if(![self decodeInt:&version])
            {
               NSUDEBUG(@"NSUnarchiver readClass: decodeInt failed\n");
                return NO;
            }
            
            _versionByClassName[className] = @(version);
            
            *outClass = [self classForName:className];
            if(!*outClass)
            {
               NSUDEBUG(@"NSUnarchiver readClass: classForName %@ failed\n", className);
                return NO;
            }
            
            NSNumber* nextLabel = [self nextSharedObjectLabel];
            NSUDEBUG(@"NSUnarchiver readClass: next label %@ is for class %@\n", nextLabel, className);
            _sharedObjects[nextLabel] = *outClass;
            
            // We do not check the super-class
            Class superClass;
            if(![self readClass:&superClass])
            {
               NSUDEBUG(@"NSUnarchiver readClass: failed to read super class\n");
                return NO;
            }
            return YES;
        }
            
        default:
        {
            int label;
            if(![self finishDecodeInt:&label withChar:ch])
            {
               NSUDEBUG(@"NSUnarchiver readClass: finishDecodeInt failed\n");
                return NO;
            }
            label = BIAS(label);
            *outClass = _sharedObjects[@(label)];
            if (!*outClass)
               return NO;
            return YES;
        }
    }
}

- (BOOL)readBytes:(void*)bytes length:(NSUInteger)length
{
    NSParameterAssert(bytes);
    
    if(_pos + length > _data.length)
        return NO;
    [_data getBytes:bytes range:NSMakeRange(_pos, length)];
    _pos += length;
    return YES;
}

- (BOOL)readData:(NSData**)outData length:(NSUInteger)length
{
    NSParameterAssert(outData);
    
    if(_pos + length > _data.length)
        return NO;
    *outData = [_data subdataWithRange:NSMakeRange(_pos, length)];
    _pos += length;
    return YES;
}

- (uint8_t)decodeByte
{
   uint8_t v = 0;
   [self decodeValuesOfObjCTypes: "c", &v];
   return v;
}

- (BOOL)decodeChar:(signed char*)outChar
{
    NSParameterAssert(outChar);
    return [self readBytes:outChar length:1];
}

- (BOOL)decodeFloat:(float*)outFloat
{
    NSParameterAssert(outFloat);
    
    signed char charValue;
    if(![self decodeChar:&charValue])
        return NO;
    if(charValue != RealLabel)
    {
        int intValue;
        if(![self finishDecodeInt:&intValue withChar:charValue])
            return NO;
        *outFloat = intValue;
        return YES;
    }
    NSSwappedFloat value;
    if(![self readBytes:&value length:sizeof(NSSwappedFloat)])
        return NO;
    
    *outFloat = [self swappedFloat:value];
    
    return YES;
}

- (BOOL)decodeDouble:(double*)outDouble
{
    NSParameterAssert(outDouble);
    
    signed char charValue;
    if(![self decodeChar:&charValue])
        return NO;
    if(charValue != RealLabel)
    {
        int intValue;
        if(![self finishDecodeInt:&intValue withChar:charValue])
            return NO;
        *outDouble = intValue;
        return YES;
    }
    NSSwappedDouble value;
    if(![self readBytes:&value length:sizeof(NSSwappedDouble)])
        return NO;
    
    *outDouble = [self swappedDouble:value];
    return YES;
}

- (BOOL)decodeCharsAsString:(NSString**)outString
{
    NSParameterAssert(outString);
    
    signed char charValue;
    if(![self decodeChar:&charValue])
        return NO;
    
    if(charValue == NullLabel)
    {
        *outString = nil;
        return YES;
    }
    
    int length;
    if(![self finishDecodeInt:&length
                     withChar:charValue])
        return NO;
    if(length <= 0)
        return NO;
    
    char bytes[length];
    if(![self readBytes:bytes length:length])
        return NO;
    *outString = [[NSString alloc] initWithBytes:bytes
                                          length:length
                                        encoding:NSASCIIStringEncoding];
    return YES;
}

- (BOOL)decodeString:(NSString**)outString
{
    NSParameterAssert(outString);
    
    signed char charValue;
    if(![self decodeChar:&charValue])
        return NO;

    switch(charValue)
    {
        case NullLabel:
            *outString = nil;
            return YES;
            
        case NewLabel:
            if(![self decodeSharedString:outString])
                return NO;
            NSAssert(*outString, nil);

            NSNumber* nextLabel = [self nextSharedObjectLabel];
            NSUDEBUG(@"NSunarchiver decodeString: new label %@ for string %@\n", nextLabel, *outString);
            _sharedObjects[nextLabel] = *outString;
            return YES;
        
        default:
        {
            int label;
            if(![self finishDecodeInt:&label withChar:charValue])
                return NO;
            label = BIAS(label);
            *outString = _sharedObjects[@(label)];
            if (!*outString)
               return NO;
            return YES;
        }
    }
}

- (BOOL)decodeSharedString:(NSString**)outString
{
    NSParameterAssert(outString);

    signed char ch;
    if(![self decodeChar:&ch])
        return NO;
    if(ch == NullLabel)
    {
        *outString = nil;
        return YES;
    }
    if(ch == NewLabel)
    {
        if(![self decodeCharsAsString:outString])
            return NO;
        NSAssert(*outString, nil);
        [_sharedStrings addObject:*outString];
    }
    else
    {
        int stringIndex;
        if(![self finishDecodeInt:&stringIndex
                         withChar:ch])
            return NO;
        stringIndex = BIAS(stringIndex);
        if(stringIndex >= _sharedStrings.count)
            return NO;
        *outString = _sharedStrings[stringIndex];
    }
    return YES;
}

- (BOOL)decodeShort:(short*)outShort
{
    NSParameterAssert(outShort);
    
    signed char ch;
    if(![self decodeChar:&ch])
        return NO;
    
    if(ch != Long2Label)
    {
        *outShort = ch;
        return YES;
    }
    
    short value;
    if(![self readBytes:&value length:2])
        return NO;
    
    *outShort = [self swappedShort:value];
    
    return YES;
}

- (BOOL)decodeInt:(int*)outInt
{
    NSParameterAssert(outInt);
    signed char ch;
    if(![self decodeChar:&ch])
        return NO;
    return [self finishDecodeInt:outInt withChar:ch];
}

- (BOOL)finishDecodeInt:(int*)outInt
               withChar:(signed char)charValue
{
    NSParameterAssert(outInt);
    
    switch(charValue)
    {
        case Long2Label:
        {
            short value;
            if(![self readBytes:&value length:2])
                return NO;
            *outInt = [self swappedShort:value];
            break;
        }
            
        case Long4Label:
        {
            int value;
            if(![self readBytes:&value length:4])
                return NO;
            *outInt = [self swappedInt:value];
            break;
        }
            
        default:
            *outInt = charValue;
            break;
    }
    return YES;
}

- (unsigned short)swappedShort:(unsigned short)value
{
    return _swap ? NSSwapShort(value) : value;
}

- (unsigned int)swappedInt:(unsigned int)value
{
    return _swap ? NSSwapInt(value) : value;
}

- (unsigned long long)swappedLongLong:(unsigned long long)value
{
    return _swap ? NSSwapLongLong(value) : value;
}

- (float)swappedFloat:(NSSwappedFloat)value
{
    return _swap ? NSConvertSwappedFloatToHost(NSSwapFloat(value)) : NSConvertSwappedFloatToHost(value);
}

- (double)swappedDouble:(NSSwappedDouble)value
{
    return _swap ? NSConvertSwappedDoubleToHost(NSSwapDouble(value)) : NSConvertSwappedDoubleToHost(value);
}

- (BOOL)readType:(const char*)type data:(void*)data
{
   return [self readType: type data: data outType: NULL];
}

- (BOOL)readType:(const char*)type data:(void*)data outType:(const char**)outType
{
    NSParameterAssert(type);
    NSParameterAssert(data);
    
    BOOL rv = TRUE;
    char ch = type[0];
    type++;

    switch(ch)
    {
        case 'c':
        case 'C':
        {
            signed char value;
            if(![self decodeChar:&value])
            {
                rv = NO;
                break;
            }
            *((char*)data) = (char)value;
            break;
        }
            
        case 's':
        case 'S':
        {
            short value;
            if(![self decodeShort:&value])
            {
                rv = NO;
                break;
            }
            *((short*)data) = value;
            break;
        }
            
        case 'i':
        case 'I':
        case 'l':
        case 'L':
        {
            int value;
            if(![self decodeInt:&value])
            {
                rv = NO;
                break;
            }
            *((int*)data) = value;
            break;
        }
            
        case 'f':
        {
            float value;
            if(![self decodeFloat:&value])
            {
                rv = NO;
                break;
            }
            *((float*)data) = value;
            break;
        }
            
        case 'd':
        {
            double value;
            if(![self decodeDouble:&value])
            {
                rv = NO;
                break;
            }
            *((double*)data) = value;
            break;
        }
            
        case '@':
        {
            id obj;
            if(![self _readObject:&obj])
            {
                NSUDEBUG(@"_readObject failure reported to readType\n");
                rv = NO;
                break;
            }
            *((__strong id*)data) = obj;
            break;
        }
            
        case '*':
        case '%':
        case ':':
        case '#':
        {
            NSString* string;
            if(![self decodeSharedString:&string])
            {
                rv = NO;
                break;
            }

            // Freeing of the string seems to be the responsibilty of the caller.
            // NSCoding implementations of Foundation classes all seem to do this.
            char* cString = malloc(string.length + 1);  // +1 because of null-termination
            [string getBytes:cString
                   maxLength:string.length
                  usedLength:NULL
                    encoding:NSASCIIStringEncoding
                     options:0
                       range:NSMakeRange(0, string.length)
              remainingRange:NULL];
            cString[string.length] = '\0';

            if (ch == '*')
            {
               *((const char**)data) = cString;
            }
            else if (ch == '%')
            {
               *((const char**)data) = uniqueString(cString);
               free(cString);
            }
            else if (ch == ':')
            {
               *((SEL*) data) = sel_registerName(cString);
               free(cString);
            }
            else if (ch == '#')
            {
                *((Class*) data) = objc_getClass(cString);
                free(cString);
            }
            break;
        }

        case '[':
        {
            unsigned int size, align;
            unsigned int i, count = 0;
            const char* elemType;

            while ('0' <= *type && *type <= '9')
            {
               count = 10 * count + (*type - '0');
               type++;
            }

            elemType = type;
            type = sizeofType(elemType, &size, &align);
            NSUDEBUG(@"size and alignment of %s is %d, %d\n", elemType, size, align);

            for (unsigned int i = 0; i < count; i++)
               [self readType: elemType data:((char*) data)+(i*size)];

            ch = *type;
            type++;
            if (ch != ']')
               NSUDEBUG(@"Missing ] terminator");
            break;
        }

        case '{':
        {
           unsigned int off = 0;
           type = skipStructName(type);

           while (*type != '}')
           {
              unsigned int s, a;

              sizeofType(type, &s, &a);
              off = roundUp(off, a);
              [self readType:type data:((char*) data)+off outType:&type];
              off += s;
           }
           type++;
           break;
        }

        case '(':
        {
            unsigned int s, a;
            type = skipStructName(type);
            type = sizeofType(type - 1, &s, &a);

            for (unsigned int i = 0; i < s; i++)
               [self readType:"C" data:((char*) data) + i];
            break;
        }
            
        default:
            NSLog(@"unsupported archiving type %c", ch);
            rv = NO;
    }

    if (outType)
      *outType = type;
    return rv;
}


#pragma mark - Convenience Methods

+ (id) compatibilityUnarchiveObjectWithData:(NSData*)data
                            decodeClassName:(NSString*)archiveClassName
                                asClassName:(NSString*)className
{
    NSParameterAssert(!archiveClassName || className);
    
    if(!data)
        return nil;
    
    NSUnarchiver* unarchiver = [[NSUnarchiver alloc] initForReadingWithData:data];
    if(archiveClassName)
        [unarchiver decodeClassName:archiveClassName asClassName:className];
    return [unarchiver decodeObject];
}

#pragma mark - NSCoder methods

- (void)decodeValueOfObjCType:(const char*)type at:(void*)data
{
    NSParameterAssert(type);
    NSParameterAssert(data);
    
    // Make sure that even under iOS BOOLs are read with 'c' type.
    if(strcmp(type, @encode(BOOL)) == 0)
        type = "c";
    
    NSString* string;
    if(![self decodeSharedString:&string] || string.length == 0)
        return;
    
    const char* str = string.UTF8String;
    if(strcasecmp(str, type) != 0)
    {
        NSLog(@"wrong type in archive '%s', expected '%s'", str, type);
        [NSException raise:NSInvalidArgumentException format:@"NSUnarchiver decodeValueOfObjCType: wrong type in archive '%s', expected '%s'", str, type];
        return;
    }
    
    [self readType:str data:data];
}

- (void)decodeValuesOfObjCTypes:(const char*)types, ...
{
    NSString* string;
    if(![self decodeSharedString:&string])
        return;

    NSUDEBUG(@"decodeValuesOfObjCTypes:%s at offset 0x%x\n", types, _pos);
    
    if(strcasecmp([string cStringUsingEncoding:NSASCIIStringEncoding], types) != 0)
    {
        NSLog(@"wrong types in archive '%@', expected '%s'", string, types);
        [NSException raise:NSInvalidArgumentException format:@"NSUnarchiver decodeValuesOfObjCTypes: wrong types in archive '%@', expected '%s'", string, types];
        return;
    }

    va_list argList;
    va_start (argList, types);
    
    const char* type = types;
    while(*type != '\0')
    {
        void* data = va_arg(argList, void*);
        NSUDEBUG(@"next type is %c, data is %p\n", *type, data);
        [self readType:type data:data outType:&type];
    }
    
    va_end (argList);
}

- (void*)decodeBytesWithReturnedLength:(NSUInteger*)outLength
{
    NSParameterAssert(outLength);
    
    *outLength = 0;
    NSString* string;
    if(![self decodeSharedString:&string])
        return NULL;
    if(![string isEqualToString:@"+"])
        return NULL;
    
    int length;
    if(![self decodeInt:&length])
        return NULL;
    
    NSData* data;
    if(![self readData:&data length:length])
        return NULL;
    
    *outLength = length;
    return (void*)data.bytes;
}

- (id)decodeObject
{
    id obj;
    if (![self readObject:&obj])
    {
      NSUDEBUG(@"NSUnarchive readObject failed\n");
      return nil;
    }
    return obj;
}

- (NSInteger)versionForClassName:(NSString *)className
{
    NSParameterAssert(className);
    return ((NSNumber*)_versionByClassName[className]).integerValue;
}

-(void)decodeClassName:(NSString *)archiveName asClassName:(NSString *)runtimeName {
	if (_classNameMap == nil)
		_classNameMap = [[NSMutableDictionary alloc] init];
	_classNameMap[archiveName] = runtimeName;
}

-(NSString *)classNameDecodedForArchiveClassName:(NSString *)className {
	if (_classNameMap == nil)
		return className;
	NSString* mapped = _classNameMap[className];
	if (mapped != nil)
		return mapped;
	return className;
}

+(void)decodeClassName:(NSString *)archiveName asClassName:(NSString *)runtimeName {
	globalClassNameMap[archiveName] = runtimeName;
}

+(NSString *)classNameDecodedForArchiveClassName:(NSString *)className {
	NSString* mapped = globalClassNameMap[className];
	if (mapped != nil)
		return mapped;
	return className;
}

-(void)replaceObject:original withObject:replacement {
   NSUnimplementedMethod();
}

@end

static Boolean stringsEqual(const void* s1, const void* s2)
{
   return strcmp((const char*) s1, (const char*) s2) == 0;
}

static CFHashCode stringHash(const void* s)
{
   const char* str = (const char*) s;
   CFHashCode hash = 5381;
   int c;

   while ((c = *str++))
      hash = ((hash << 5) + hash) + c;

   return hash;
}

static const void* stringRetain(CFAllocatorRef allocator, const void* s)
{
   return strdup((char*) s);
}

// Returns a permanently allocated string (atom).
// Atoms can be compared with ==.
static const char* uniqueString(const char* str)
{
   static CFMutableSetRef atoms;
   static dispatch_once_t once;

   dispatch_once(&once, ^{
      CFSetCallBacks cb = {
         .equal = stringsEqual,
         .hash = stringHash,
         .retain = stringRetain,
      };
      atoms = CFSetCreateMutable(NULL, 0, &cb);
   });

   if (!CFSetContainsValue(atoms, str))
      CFSetAddValue(atoms, str);

   return (const char*) CFSetGetValue(atoms, str);
}

static unsigned int roundUp(unsigned int size, unsigned int align)
{
   return ((size + align - 1) / align) * align;
}

static const char* skipStructName(const char* str)
{
   const char* type = str;

   while (TRUE)
   {
      switch (*type++)
      {
         case '=':
            return type;
         case '}':
         case '{':
         case ')':
         case '(':
         case 0:
            return str;
      }
   }
}

// This is NOT a duplicate of NSGetSizeAndAlignment. This function just stops after the 1st type it finds.
const char* sizeofType(const char* type, unsigned int* size, unsigned int* align)
{
   char c = *type++;

#define simpleCase(cc, type) case cc: *size = sizeof(type); *align = __alignof(type); break

   switch (c)
   {
      simpleCase('c', char);
      simpleCase('C', char);
      simpleCase('s', short);
      simpleCase('S', short);
      simpleCase('i', int);
      simpleCase('I', int);
      simpleCase('!', int);
      simpleCase('l', int);
      simpleCase('L', int);
      simpleCase('f', float);
      simpleCase('d', double);
      simpleCase('@', id);
      simpleCase('*', char*);
      simpleCase('%', char*);
      simpleCase(':', SEL);
      simpleCase('#', Class);
      case '[':
      {
         unsigned int count = 0;
         unsigned s, a;

         while ('0' <= *type && *type <= '9')
            count = 10 * count + (*type++ - '0');

         type = sizeofType(type, &s, &a);

         *size = count * roundUp(s, a);
         *align = a;

         c = *type++;
         if (c != ']')
            [NSException raise:NSInvalidArgumentException format:@"Invalid char found in array encoding, expected ], found %c", c];

         break;
      }
      case '(':
      {
         unsigned int unionSize = 0;
         unsigned int unionAlign = 1;

         type = skipStructName(type);

         while (*type != ')')
         {
            unsigned int s, a;

            type = sizeofType(type, &s, &a);

            if (s > unionSize)
               unionSize = s;
            if (a > unionAlign)
               unionAlign = a;
         }

         *size = roundUp(unionSize, unionAlign);
         *align = unionAlign;
         break;
      }
      case '{':
      {
         unsigned int structSize = 0;
         unsigned int structAlign = 1;

         type = skipStructName(type);

         while (*type != '}')
         {
            unsigned int s, a;

            type = sizeofType(type, &s, &a);
            structSize = roundUp(structSize, a);
            structSize += s;
            if (a > structAlign)
               structAlign = a;
         }

         *size = roundUp(structSize, structAlign);
         *align = structAlign;
         break;
      }
   }

#undef simpleCase
    return type;
}

