// Copyright (C) 2020 Lubos Dolezel

#import <Foundation/NSSerializer.h>
#import <Foundation/NSException.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSByteOrder.h>
#include <CoreFoundation/CFString.h>

id _NSDeserializeObject(NSData* data, unsigned int* cursor, BOOL mutableContainers);

@implementation NSDeserializer
+(id) deserializePropertyListFromData:(NSData*)data mutableContainers:(BOOL)mutableContainers
{
	unsigned int cursor = 0;
	return [_NSDeserializeObject(data, &cursor, mutableContainers) autorelease];
}

+(id) deserializePropertyListFromData:(NSData*)data atCursor:(unsigned int*)cursor mutableContainers:(BOOL)mutableContainers
{
	return [_NSDeserializeObject(data, cursor, mutableContainers) autorelease];
}
@end

@implementation NSData (SerializerAdditions)
-(int)deserializeIntAtCursor:(unsigned int*)cursor
{
	int rv = [self deserializeIntAtIndex: *cursor];
	(*cursor) += 4;
	return rv;
}

-(int)deserializeIntAtIndex:(unsigned int)index
{
	unsigned int rv;
	[self deserializeBytes: &rv length: sizeof(rv) atCursor:&index];
	// Some documentation suggests this should be big endian, but Apple definitely uses little endian here
	return NSSwapLittleIntToHost(rv);
}

-(void)deserializeInts:(int*) array count:(unsigned int) count atCursor:(unsigned int*)cursor;
{
	for (unsigned int c = 0; c < count; c++)
	{
		array[c] = [self deserializeIntAtCursor: cursor];
	}
}

- (void)deserializeBytes: (void*)buffer length: (unsigned int)bytes atCursor: (unsigned int*)cursor
{
	NSRange	range = NSMakeRange(*cursor, bytes);
	[self getBytes: buffer range: range];
	*cursor += bytes;
}

-(unsigned)deserializeAlignedBytesLengthAtCursor:(unsigned int*)cursor
{
	unsigned int v = [self deserializeIntAtCursor: cursor];
	if (v != 0x80000000)
		return v;
	
	v = [self deserializeIntAtCursor: cursor];
	*cursor = [self deserializeIntAtCursor: cursor];
	return v;
}
@end

id _NSDeserializeObject(NSData* data, unsigned int* cursor, BOOL mutableContainers)
{
	int type = [data deserializeIntAtCursor: cursor];
	if (!type)
		type = [data deserializeIntAtCursor: cursor];

	switch (type-2)
	{
		case 0: // array
		{
			Class arrayClass = mutableContainers ? [NSMutableArray class] : [NSArray class];
			int size = [data deserializeIntAtCursor: cursor];
			if (!size)
				return [[arrayClass array] retain];
			if (size >= 0x20000000)
				[NSException raise:NSInvalidArgumentException format:@"Deserialization error: int out of bounds"];

			id* mem = malloc(size * sizeof(id));

			for (int i = 0; i < size; i++)
				mem[i] = _NSDeserializeObject(data, cursor, mutableContainers);

			NSArray* rv = [[arrayClass alloc] initWithObjects: mem count: size];

			for (int i = 0; i < size; i++)
				[mem[i] release];

			free(mem);
			return rv;
		}
		case 2: // data
		{
			unsigned len = [data deserializeAlignedBytesLengthAtCursor: cursor];
			const uint8_t* bytes = [data bytes];
			unsigned limit = [data length];

			if (*cursor+len > limit)
				[NSException raise:NSInvalidArgumentException format:@"Deserialization error: NSData out of range"];

			NSData* rv = [[NSData alloc] initWithBytes:(bytes + *cursor) length:len];

			unsigned off = len + 3;
			off &= 0xFFFFFFFC;
			(*cursor) += off;

			return rv;
		}
		case 3: // nextstep string
		{
			unsigned len = [data deserializeAlignedBytesLengthAtCursor: cursor];
			const uint8_t* bytes = [data bytes];
			unsigned limit = [data length];

			if (*cursor+len > limit)
				[NSException raise:NSInvalidArgumentException format:@"Deserialization error: string out of range"];

			NSString* rv = [[NSString alloc] initWithBytes:(bytes+*cursor) length:len encoding:NSNEXTSTEPStringEncoding];

			return rv;
		}
		case 4: // unicode string
		{
			unsigned len = [data deserializeAlignedBytesLengthAtCursor: cursor];
			const uint8_t* bytes = [data bytes];
			unsigned limit = [data length];

			if (*cursor+len > limit)
				[NSException raise:NSInvalidArgumentException format:@"Deserialization error: CFString out of range"];

			CFStringRef rv = CFStringCreateWithBytes(NULL, bytes + *cursor, len, kCFStringEncodingUnicode, TRUE);

			return (NSString*)rv;
		}
		case 5: // dictionary
		{
			int size = [data deserializeIntAtCursor: cursor];
			if (size >= 0x20000000)
				[NSException raise:NSInvalidArgumentException format:@"Deserialization error: int out of bounds"];

			id* keys = malloc(size * sizeof(id));
			id* values = malloc(size * sizeof(id));

			for (int i = 0; i < size; i++)
				keys[i] = _NSDeserializeObject(data, cursor, mutableContainers);

			for (int i = 0; i < size; i++)
			{
				values[i] = _NSDeserializeObject(data, cursor, mutableContainers);
				if (!keys[i] || !values[i])
				{
					NSLog(@"NSDeserializer: Attempted to store nil in dictionary!\n");
				}
			}

			Class dictClass = mutableContainers ? [NSMutableDictionary class] : [NSDictionary class];
			id rv = [[dictClass alloc] initWithObjects:values forKeys:keys count:size];

			for (int i = 0; i < size; i++)
			{
				[keys[i] release];
				[values[i] release];
			}

			free(keys);
			free(values);
			return rv;
		}
		case 6:
			return nil;
		case 1:
		default:
		{
			[NSException raise:NSInvalidArgumentException format:@"Deserialization error: unknown type: %d", type];
			__builtin_unreachable();
		}
	}
}
