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
#include <string.h>

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
#  define NSLog(...)
#endif

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
   // TODO
   return nil;
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
    
    int systemVersion;
    if(![self decodeInt:&systemVersion])
        return NO;
    
    return YES;
}

- (BOOL)readObject:(id*)outObject
{
    NSString* string;
    *outObject = nil;

    if(![self decodeSharedString:&string])
    {
       NSLog(@"NSUnarchiver readObject: decodeSharedString failed\n");
        return NO;
    }
    if(![string isEqualToString:@"@"])
    {
       NSLog(@"NSUnarchiver readObject: unexpected type: %@\n", string);
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
    
    signed char ch;
    if(![self decodeChar:&ch])
    {
       NSLog(@"NSUnarchiver _readObject: failed to decode char\n");
        return NO;
    }
    
    switch(ch)
    {
        case NullLabel:
            NSLog(@"readObject -> nil\n");
            *outObject = nil;
            return YES;
            
        case NewLabel:
        {
            NSNumber* label = [self nextSharedObjectLabel];
            NSLog(@"NSUnarchiver _readObject: new label %@\n", label);
            Class objectClass;
            if(![self readClass:&objectClass])
            {
               NSLog(@"NSUnarchiver _readObject: failed to read class!\n");
                return NO;
            }
            NSLog(@"Will now initWithCoder on class %@\n", NSStringFromClass(objectClass));

            id object = [objectClass alloc];
            if(!object)
                return NO;
            _sharedObjects[label] = object;

            id object2 = [object initWithCoder:self];
            if (object2 != object)
               NSLog(@"NSUnarchiver: This may not work out, instance changed\n");

            id objectAfterAwake = [object2 awakeAfterUsingCoder:self];
            if(objectAfterAwake && objectAfterAwake != object2)
            {
                object2 = objectAfterAwake;
                _sharedObjects[label] = objectAfterAwake;
            }
            *outObject = object2;
            
            signed char endMarker;
            if(![self decodeChar:&endMarker] || endMarker != EndOfObjectLabel)
                return NO;
            
            return YES;
        }
            
        default:
        {
            NSLog(@"readObject -> sharedObject\n");
            int label;
            if(![self finishDecodeInt:&label withChar:ch])
            {
               NSLog(@"readObject -> sharedObject: FAILED to decode int\n");
                return NO;
            }
            label = BIAS(label);
            *outObject = _sharedObjects[@(label)];
            if (!*outObject)
            {
               NSLog(@"readObject -> sharedObject: non-existent shared obj for label %d\n", label);
               return NO;
            }
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
       NSLog(@"NSUnarchiver readClass: decodeChar failed\n");
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
               NSLog(@"NSUnarchiver readClass: decodeSharedString failed\n");
                return NO;
            }
            int version;
            if(![self decodeInt:&version])
            {
               NSLog(@"NSUnarchiver readClass: decodeInt failed\n");
                return NO;
            }
            
            _versionByClassName[className] = @(version);
            
            *outClass = [self classForName:className];
            if(!*outClass)
            {
               NSLog(@"NSUnarchiver readClass: classForName %@ failed\n", className);
                return NO;
            }
            
            NSNumber* nextLabel = [self nextSharedObjectLabel];
            NSLog(@"NSUnarchiver readClass: next label %@ is for class %@\n", nextLabel, className);
            _sharedObjects[nextLabel] = *outClass;
            
            // We do not check the super-class
            Class superClass;
            if(![self readClass:&superClass])
            {
               NSLog(@"NSUnarchiver readClass: failed to read super class\n");
                return NO;
            }
            return YES;
        }
            
        default:
        {
            int label;
            if(![self finishDecodeInt:&label withChar:ch])
            {
               NSLog(@"NSUnarchiver readClass: finishDecodeInt failed\n");
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
   [self readBytes: &v length:1];
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
            NSLog(@"NSunarchiver decodeString: new label %@ for string %@\n", nextLabel, *outString);
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
    NSParameterAssert(type);
    NSParameterAssert(data);
    
    char ch = type[0];

    switch(ch)
    {
        case 'c':
        case 'C':
        {
            signed char value;
            if(![self decodeChar:&value])
                return NO;
            *((char*)data) = (char)value;
            break;
        }
            
        case 's':
        case 'S':
        {
            short value;
            if(![self decodeShort:&value])
                return NO;
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
                return NO;
            *((int*)data) = value;
            break;
        }
            
        case 'f':
        {
            float value;
            if(![self decodeFloat:&value])
                return NO;
            *((float*)data) = value;
            break;
        }
            
        case 'd':
        {
            double value;
            if(![self decodeDouble:&value])
                return NO;
            *((double*)data) = value;
            break;
        }
            
        case '@':
        {
            id obj;
            if(![self _readObject:&obj])
                return NO;
            *((__strong id*)data) = obj;
            break;
        }
            
        case '*':
        {
            NSString* string;
            if(![self decodeString:&string])
                return NO;
            
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
            *((const char**)data) = cString;
            break;
        }
            
        default:
            NSLog(@"unsupported archiving type %c", ch);
            return NO;
    }
    return YES;
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
    if(strcmp(str, type) != 0)
    {
        NSLog(@"wrong type in archive '%s', expected '%s'", str, type);
        return;
    }
    
    [self readType:str data:data];
}

- (void)decodeValuesOfObjCTypes:(const char*)types, ...
{
    NSString* string;
    if(![self decodeSharedString:&string])
        return;
    
    if(strcmp([string cStringUsingEncoding:NSASCIIStringEncoding], types) != 0)
    {
        NSLog(@"wrong types in archive '%@', expected '%s'", string, types);
        return;
    }

    va_list argList;
    va_start (argList, types);
    
    const char* type = types;
    while(*type != '\0')
    {
        void* data = va_arg(argList, void*);
        [self readType:type data:data];
        type++;
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
      NSLog(@"NSUnarchive readObject failed\n");
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
