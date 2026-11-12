//
//  NSSpellCheckingResult.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSSpellCheckingResult.h"

#import "NSTextCheckingResultCoding.h"
#import <Foundation/NSCoder.h>

@implementation NSSpellCheckingResult

- (id)initWithRange:(NSRange)range
{
    self = [super init];
    if (self)
    {
        _range = range;
    }
    return self;
}

- (NSRange)range
{
    return _range;
}

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypeSpelling;
}



- (void)encodeWithCoder:(NSCoder *)coder
{
    NSTextCheckingResultEncodeRange(coder, _range);
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSRange range;
    if (!NSTextCheckingResultDecodeRange(coder, &range))
    {
        [self release];
        return nil;
    }
    return [self initWithRange:range];
}

@end
