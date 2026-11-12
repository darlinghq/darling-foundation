//
//  NSLinkCheckingResult.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "NSLinkCheckingResult.h"
#import <Foundation/NSURL.h>

#import "NSTextCheckingResultCoding.h"
#import <Foundation/NSCoder.h>

@implementation NSLinkCheckingResult

- (id)initWithRange:(NSRange)range URL:(NSURL *)url
{
    self = [super init];
    if (self)
    {
        _range = range;
        _url = [url copy];
    }
    return self;
}

- (void)dealloc
{
    [_url release];
    [super dealloc];
}

- (NSURL *)URL
{
    return _url;
}

- (NSRange)range
{
    return _range;
}

- (NSTextCheckingType)resultType
{
    return NSTextCheckingTypeLink;
}


- (void)encodeWithCoder:(NSCoder *)coder
{
    NSTextCheckingResultEncodeRange(coder, _range);
    [coder encodeObject:_url forKey:@"NSURL"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSRange range;
    NSURL *url = [coder decodeObjectOfClass:[NSURL class] forKey:@"NSURL"];
    if (!NSTextCheckingResultDecodeRange(coder, &range) || url == nil)
    {
        [self release];
        return nil;
    }
    return [self initWithRange:range URL:url];
}

@end
