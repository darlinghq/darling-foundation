//
//  NSOrthographyCheckingResult.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSOrthographyCheckingResult.h"
#import <Foundation/NSOrthography.h>

#import "NSTextCheckingResultCoding.h"
#import <Foundation/NSCoder.h>

@implementation NSOrthographyCheckingResult

- (id)initWithRange:(NSRange)range orthography:(NSOrthography *)orthography
{
    self = [super init];
    if (self)
    {
        _range = range;
        _orthography = [orthography copy];
    }
    return self;
}

- (void)dealloc
{
    [_orthography release];
    [super dealloc];
}

- (NSOrthography *)orthography
{
    return _orthography;
}

- (NSRange)range
{
    return _range;
}

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypeOrthography;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    NSTextCheckingResultEncodeRange(coder, _range);
    [coder encodeObject:_orthography forKey:@"NSOrthography"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSRange range;
    NSOrthography *orthography = [coder decodeObjectOfClass:[NSOrthography class] forKey:@"NSOrthography"];
    if (!NSTextCheckingResultDecodeRange(coder, &range) || orthography == nil)
    {
        [self release];
        return nil;
    }
    return [self initWithRange:range orthography:orthography];
}

@end
