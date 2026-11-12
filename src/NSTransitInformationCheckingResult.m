//
//  NSTransitInformationCheckingResult.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSTransitInformationCheckingResult.h"
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>

#import "NSTextCheckingResultCoding.h"
#import <Foundation/NSCoder.h>

@implementation NSTransitInformationCheckingResult

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
    return NSTextCheckingTypeTransitInformation;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    NSTextCheckingResultEncodeRange(coder, _range);
    [coder encodeObject:_components forKey:@"NSTransitInformationComponents"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSRange range;
    NSDictionary *components = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], nil] forKey:@"NSTransitInformationComponents"];
    if (!NSTextCheckingResultDecodeRange(coder, &range) || ![components isKindOfClass:[NSDictionary class]])
    {
        [self release];
        return nil;
    }
    return [self initWithRange:range components:components];
}

@end
