//
//  NSPhoneNumberCheckingResult.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSPhoneNumberCheckingResult.h"
#import <Foundation/NSString.h>

#import "NSTextCheckingResultCoding.h"
#import <Foundation/NSCoder.h>

@implementation NSPhoneNumberCheckingResult

- (id)initWithRange:(NSRange)range phoneNumber:(NSString *)phoneNumber
{
    return [self initWithRange:range phoneNumber:phoneNumber underlyingResult:nil];
}

- (id)initWithRange:(NSRange)range phoneNumber:(NSString *)phoneNumber underlyingResult:(void *)underlyingResult
{
    self = [super init];
    if (self)
    {
        _range = range;
        _phoneNumber = [phoneNumber copy];
        _underlyingResult = underlyingResult;
    }
    return self;
}

- (void)dealloc
{
    [_phoneNumber release];
    [super dealloc];
}

- (NSString *)phoneNumber
{
    return _phoneNumber;
}

- (NSRange)range
{
    return _range;
}

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypePhoneNumber;
}

/*
- (NSString *)description
{

}
*/


- (void)encodeWithCoder:(NSCoder *)coder
{
    NSTextCheckingResultEncodeRange(coder, _range);
    [coder encodeObject:_phoneNumber forKey:@"NSPhoneNumber"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSRange range;
    NSString *phoneNumber = [coder decodeObjectOfClass:[NSString class] forKey:@"NSPhoneNumber"];
    if (!NSTextCheckingResultDecodeRange(coder, &range) || phoneNumber == nil)
    {
        [self release];
        return nil;
    }
    return [self initWithRange:range phoneNumber:phoneNumber];
}

@end
