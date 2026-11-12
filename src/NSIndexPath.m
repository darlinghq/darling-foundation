//
//  NSIndexPath.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSIndexPath.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSData.h>
#import <stdlib.h>

@implementation NSIndexPath

+ (id)indexPathWithIndex:(NSUInteger)index
{
    return [[[self alloc] initWithIndex:index] autorelease];
}

+ (id)indexPathWithIndexes:(const NSUInteger [])indexes length:(NSUInteger)length
{
    return [[[self alloc] initWithIndexes:indexes length:length] autorelease];
}

- (id)initWithIndex:(NSUInteger)index
{
    return [self initWithIndexes:&index length:1];
}

- (id)initWithIndexes:(const NSUInteger [])indexes length:(NSUInteger)length
{
    self = [super init];
    if (self)
    {
        _length = length;
        if (length > 0)
        {
            _indexes = malloc(sizeof(NSUInteger) * length);
            memcpy(_indexes, indexes, sizeof(NSUInteger) * length);
        }
    }
    return self;
}

- (id)_initWithIndexesNoCopy:(NSUInteger *)indexes length:(NSUInteger)length
{
    self = [super init];
    if (self)
    {
        _indexes = indexes;
        _length = length;
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

// The index list of a path with two or more elements is archived as one data
// blob holding each index as an unsigned base-128 varint (low group first).
static void appendVarint(NSMutableData *data, NSUInteger value)
{
    do
    {
        uint8_t byte = value & 0x7f;
        value >>= 7;
        if (value != 0)
        {
            byte |= 0x80;
        }
        [data appendBytes:&byte length:1];
    } while (value != 0);
}

static BOOL readVarint(const uint8_t *bytes, NSUInteger length, NSUInteger *position, NSUInteger *value)
{
    NSUInteger result = 0;
    unsigned shift = 0;
    while (*position < length)
    {
        uint8_t byte = bytes[(*position)++];
        const unsigned bits = sizeof(NSUInteger) * 8;
        if (shift >= bits || (shift + 7 > bits && ((byte & 0x7f) >> (bits - shift)) != 0))
        {
            return NO;
        }
        result |= (NSUInteger)(byte & 0x7f) << shift;
        if ((byte & 0x80) == 0)
        {
            *value = result;
            return YES;
        }
        shift += 7;
    }
    return NO;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (![aDecoder allowsKeyedCoding])
    {
        NSUInteger length = 0;
        [aDecoder decodeValueOfObjCType:@encode(NSUInteger) at:&length];
        NSUInteger *indexes = length > 0 ? malloc(sizeof(NSUInteger) * length) : NULL;
        if (length > 0 && indexes == NULL)
        {
            [self release];
            return nil;
        }
        for (NSUInteger i = 0; i < length; i++)
        {
            [aDecoder decodeValueOfObjCType:@encode(NSUInteger) at:&indexes[i]];
        }
        self = [self initWithIndexes:indexes length:length];
        free(indexes);
        return self;
    }

    int64_t length = [aDecoder decodeInt64ForKey:@"NSIndexPathLength"];
    if (length < 0)
    {
        [self release];
        return nil;
    }
    if (length == 0)
    {
        return [self initWithIndexes:NULL length:0];
    }
    if (length == 1)
    {
        return [self initWithIndex:(NSUInteger)[aDecoder decodeInt64ForKey:@"NSIndexPathValue"]];
    }

    NSData *data = [aDecoder decodeObjectOfClass:[NSData class] forKey:@"NSIndexPathData"];
    const uint8_t *bytes = [data bytes];
    NSUInteger dataLength = [data length];
    // Every index takes at least one byte, which bounds the allocation.
    if (data == nil || (uint64_t)length > dataLength)
    {
        [self release];
        return nil;
    }
    NSUInteger *indexes = malloc(sizeof(NSUInteger) * (NSUInteger)length);
    if (indexes == NULL)
    {
        [self release];
        return nil;
    }
    NSUInteger position = 0;
    for (NSUInteger i = 0; i < (NSUInteger)length; i++)
    {
        if (!readVarint(bytes, dataLength, &position, &indexes[i]))
        {
            free(indexes);
            [self release];
            return nil;
        }
    }
    if (position != dataLength)
    {
        free(indexes);
        [self release];
        return nil;
    }
    self = [self _initWithIndexesNoCopy:indexes length:(NSUInteger)length];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (![aCoder allowsKeyedCoding])
    {
        [aCoder encodeValueOfObjCType:@encode(NSUInteger) at:&_length];
        for (NSUInteger i = 0; i < _length; i++)
        {
            [aCoder encodeValueOfObjCType:@encode(NSUInteger) at:&_indexes[i]];
        }
        return;
    }

    [aCoder encodeInt64:(int64_t)_length forKey:@"NSIndexPathLength"];
    if (_length == 1)
    {
        [aCoder encodeInt64:(int64_t)_indexes[0] forKey:@"NSIndexPathValue"];
    }
    else if (_length > 1)
    {
        NSMutableData *data = [NSMutableData data];
        for (NSUInteger i = 0; i < _length; i++)
        {
            appendVarint(data, _indexes[i]);
        }
        [aCoder encodeObject:data forKey:@"NSIndexPathData"];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (void)dealloc
{
    if (_indexes != NULL) {
        free(_indexes);
    }
    [super dealloc];
}

- (NSUInteger)hash
{
    if (_hash == 0)
    {
        NSUInteger length = [self length];
        _hash = length;
        if (length > 0)
        {
            _hash += [self indexAtPosition:0];
            _hash += [self indexAtPosition:length - 1];
        }
    }
    
    return _hash;
}

- (BOOL)isEqual:(id)other
{
    BOOL isEqual = NO;
    if (other == self) 
    {
        isEqual = YES;
    } 
    else if ([other isKindOfClass:[NSIndexPath class]])
    {
        isEqual = [self compare:other] == NSOrderedSame;
    }

    return isEqual;
}

- (NSIndexPath *)indexPathByAddingIndex:(NSUInteger)index
{
    NSUInteger *indexes = malloc(sizeof(NSUInteger) * (_length + 1));
    if (_length > 0)
    {
        memcpy(indexes, _indexes, sizeof(NSUInteger) * _length);
    }
    indexes[_length] = index;
    return [[[NSIndexPath alloc] _initWithIndexesNoCopy:indexes length:_length + 1] autorelease];
}

- (NSIndexPath *)indexPathByRemovingLastIndex
{
    if (_length > 0)
    {
        return [[[NSIndexPath alloc] initWithIndexes:_indexes length:_length - 1] autorelease];
    }
    else
    {
        return [[[NSIndexPath alloc] initWithIndexes:NULL length:0] autorelease];
    }
}

- (NSUInteger)indexAtPosition:(NSUInteger)position
{
    if (position > _length)
    {
        return NSNotFound;
    }
    return _indexes[position];
}

- (NSUInteger)length
{
    return _length;
}

- (void)getIndexes:(NSUInteger *)indexes
{
    if (_length > 0)
    {
        memcpy(indexes, _indexes, sizeof(NSUInteger) * _length);
    }
}

- (NSComparisonResult)compare:(NSIndexPath *)otherObject
{
    NSUInteger l1 = [self length];
    NSUInteger l2 = [otherObject length];
    for (NSUInteger pos = 0; pos < MIN(l1, l2); pos ++)
    {
        NSUInteger i1 = [self indexAtPosition:pos];
        NSUInteger i2 = [otherObject indexAtPosition:pos];
        if (i1 < i2)
        {
            return NSOrderedAscending;
        }
        else if (i1 > i2)
        {
            return NSOrderedDescending;
        }
    }
    if (l1 < l2)
    {
        return NSOrderedAscending;
    }
    else if (l1 > l2)
    {
        return NSOrderedDescending;
    }

    return NSOrderedSame;
}

@end
