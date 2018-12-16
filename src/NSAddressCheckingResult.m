//
//  NSAddressCheckingResult.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSAddressCheckingResult.h"
#import <Foundation/NSDictionary.h>

@implementation NSAddressCheckingResult

@synthesize underlyingResult=_underlyingResult;

- (id)initWithRange:(NSRange)range components:(NSDictionary *)components
{
    return [self initWithRange:range components:components underlyingResult:NULL];
}

- (id)initWithRange:(NSRange)range components:(NSDictionary *)components underlyingResult:(void *)underlyingResult
{
    self = [super init];
    if (self)
    {
        _range = range;
        _components = [components copy];
        _underlyingResult = underlyingResult;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	self = [super init];
	NSLog(@"STUB NSAddressCheckingResult initWithCoder");
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	NSLog(@"STUB NSAddressCheckingResult encodeWithCoder");
}

- (id)resultByAdjustingRangesWithOffset:(NSInteger)offset
{
	NSLog(@"STUB NSAddressCheckingResult resultByAdjustingRangesWithOffset");
	return nil;
}

- (BOOL)_adjustRangesWithOffset:(NSInteger)offset
{
	NSLog(@"STUB NSAddressCheckingResult _adjustRangesWithOffset");
	return YES;
}
- (void)dealloc
{
    [_components release];
    [super dealloc];
}

- (NSDictionary *)components
{
    return _components;
}

- (NSRange)range
{
    return _range;
}

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypeAddress;
}


@end
