//
//  NSAutoreleasePool.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSAutoreleasePool.h>
#import <objc/objc-internal.h>

@implementation NSAutoreleasePool

+ (id)allocWithZone:(NSZone *)zone
{
    NSAutoreleasePool *pool = [super allocWithZone:zone];
    pool->context = _objc_autoreleasePoolPush();
    return pool;
}

+ (void)addObject:(id)anObject
{
    [anObject autorelease];
}

- (void)addObject:(id)anObject
{
    _objc_rootAutorelease(anObject);
}

- (id)retain
{
    return self; // retaining an autoreleasepool makes little sense
}

- (id)autorelease
{
    return self; // makes even less sense than retaining
}

- (void)drain
{
    _objc_autoreleasePoolPop(context);
    [self dealloc];
}

- (oneway void)release
{
    [self drain];
}

- (void)emptyPool
{
    _objc_autoreleasePoolPop(context);
}

@end
