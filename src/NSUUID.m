//
//  NSUUID.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSUUID.h>

#import <Foundation/NSCoder.h>
#import <dispatch/dispatch.h>
#import "NSObjectInternal.h"
#import "NSUUIDInternal.h"

static NSString * const NSUUIDBytesKey = @"NS.uuidbytes";

@implementation NSUUID

+ (id)allocWithZone:(NSZone *)zone
{
    if (self == [NSUUID class])
    {
        return [__NSConcreteUUID allocWithZone:zone];
    }
    else
    {
        return [super allocWithZone:zone];
    }
}

+ (FOUNDATION_INSTANCETYPE)UUID
{
    return [[[self alloc] init] autorelease];
}

- (FOUNDATION_INSTANCETYPE)init
{
    return [super init];
}

- (FOUNDATION_INSTANCETYPE)initWithUUIDString:(NSString *)string
{
    NSRequestConcreteImplementation();
    [self release];
    return nil;
}

- (FOUNDATION_INSTANCETYPE)initWithUUIDBytes:(const uuid_t)bytes
{
    NSRequestConcreteImplementation();
    [self release];
    return nil;
}

- (void)getUUIDBytes:(uuid_t)uuid
{
    bzero(uuid, sizeof(uuid_t));
}

- (NSString *)UUIDString
{
    return @"";
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    uuid_t uuid;
    [self getUUIDBytes:uuid];
    return [[NSUUID alloc] initWithUUIDBytes:uuid];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (![aDecoder allowsKeyedCoding])
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"UUIDs can only be decoded by keyed coders"];
        return nil;
    }

    NSUInteger decodedLength;
    const char *uuidBytes = [aDecoder decodeBytesForKey:NSUUIDBytesKey returnedLength:&decodedLength];
    if (decodedLength == sizeof(uuid_t))
    {
        return [self initWithUUIDBytes:uuidBytes];
    }
    else
    {
        return [self init];
    }
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (![aCoder allowsKeyedCoding])
    {
        [NSException raise:NSInvalidArgumentException format:@"UUIDs can only be encoded by keyed coders"];
        return;
    }

    uuid_t uuid;
    [self getUUIDBytes:uuid];
    [aCoder encodeBytes:uuid length:sizeof(uuid) forKey:NSUUIDBytesKey];
}

- (CFStringRef)_cfUUIDString
{
    return (CFStringRef)[[self UUIDString] retain];
}

- (CFTypeID)_cfTypeID
{
    return CFUUIDGetTypeID();
}

@end

@implementation __NSConcreteUUID

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    return NO;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (Class)classForCoder
{
    return [NSUUID class];
}

- (id)description
{
    return [NSString stringWithFormat:@"<%s %p> %@", object_getClassName(self), self, [self UUIDString]];
}

- (CFUUIDBytes)_cfUUIDBytes
{
    return CFUUIDGetUUIDBytes(_cfUUID);
}

- (void)getUUIDBytes:(uuid_t)bytes
{
    CFUUIDBytes uuid = [self _cfUUIDBytes];
    memcpy(bytes, &uuid, sizeof(uuid_t));
}

- (NSString *)UUIDString
{
    CFStringRef uuidString = CFUUIDCreateString(NULL, _cfUUID);
    return [(NSString *)uuidString autorelease];
}

- (BOOL)isEqual:(id)other
{
    if (![other isKindOfClass:objc_lookUpClass("NSUUID")])
    {
        return NO;
    }
    uuid_t u1;
    uuid_t u2;
    [self getUUIDBytes:u1];
    [other getUUIDBytes:u2];
    return uuid_compare(u1, u2) == 0;
}

- (id)initWithUUIDBytes:(const uuid_t)bytes
{
    _cfUUID = CFUUIDCreateWithBytes(kCFAllocatorDefault,
                                    bytes[0],  bytes[1],  bytes[2],  bytes[3],
                                    bytes[4],  bytes[5],  bytes[6],  bytes[7],
                                    bytes[8],  bytes[9], bytes[10], bytes[11],
                                   bytes[12], bytes[13], bytes[14], bytes[15]);
    return self;
}

- (id)initWithUUIDString:(NSString *)string
{
    _cfUUID = CFUUIDCreateFromString(kCFAllocatorDefault, (CFStringRef)string);
    return self;
}

- (id)init
{
    _cfUUID = CFUUIDCreate(kCFAllocatorDefault);
    return self;
}

- (void)dealloc
{
    CFRelease(_cfUUID);
    [super dealloc];
}

- (NSUInteger)hash
{
    return CFHash(_cfUUID);
}

@end
