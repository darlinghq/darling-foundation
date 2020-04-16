//
//  NSTimeZone.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSTimeZone.h>
#import <Foundation/NSPortCoder.h>
#import "NSObjectInternal.h"

@implementation NSTimeZone (NSTimeZone)

OBJC_PROTOCOL_IMPL_PUSH
- (id)initWithCoder:(NSCoder *)coder
{
    NSRequestConcreteImplementation();
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSRequestConcreteImplementation();
}
OBJC_PROTOCOL_IMPL_POP

- (Class)classForCoder
{
    return [NSTimeZone self];
}

@end

@implementation NSTimeZone (NSTimeZonePortCoding)

- (id) replacementObjectForPortCoder: (NSPortCoder *) portCoder {
    if ([portCoder isByref]) {
        return [super replacementObjectForPortCoder: portCoder];
    }
    return self;
}

@end
