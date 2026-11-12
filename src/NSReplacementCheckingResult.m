//
//  NSReplacementCheckingResult.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSReplacementCheckingResult.h"
#import <Foundation/NSString.h>

#import "NSTextCheckingResultCoding.h"
#import <Foundation/NSCoder.h>

@implementation NSReplacementCheckingResult

- (id)initWithRange:(NSRange)range replacementString:(NSString *)replacementString
{
    self = [super init];
    if (self)
    {
        _range = range;
        _replacementString = [replacementString copy];
    }
    return self;
}

- (void)dealloc
{
    [_replacementString release];
    [super dealloc];
}

- (NSString *)replacementString
{
    return _replacementString;
}

- (NSRange)range
{
    return _range;
}

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypeReplacement;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSTextCheckingResultEncodeRange(coder, _range);
    [coder encodeObject:_replacementString forKey:@"NSReplacementString"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSRange range;
    NSString *replacement = [coder decodeObjectOfClass:[NSString class] forKey:@"NSReplacementString"];
    if (!NSTextCheckingResultDecodeRange(coder, &range) || replacement == nil)
    {
        [self release];
        return nil;
    }
    return [self initWithRange:range replacementString:replacement];
}

@end

@implementation NSCorrectionCheckingResult

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypeCorrection;
}

@end

@implementation NSDashCheckingResult

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypeDash;
}

@end

@implementation NSQuoteCheckingResult

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypeQuote;
}

@end
