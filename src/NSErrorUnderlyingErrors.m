//
//  NSErrorUnderlyingErrors.m
//  Foundation
//
//  Copyright (C) 2026 Lubos Dolezel
//

#import <Foundation/NSError.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>

// -underlyingErrors (Apple's NSError reference, macOS 11.3). NSError itself is
// CoreFoundation's; the method reads the userInfo keys, which are Foundation's.
@implementation NSError (NSErrorUnderlyingErrors)

- (NSArray<NSError *> *)underlyingErrors
{
    NSDictionary *userInfo = [self userInfo];
    NSMutableArray *errors = [NSMutableArray array];
    id underlying = [userInfo objectForKey:NSUnderlyingErrorKey];
    if ([underlying isKindOfClass:[NSError class]])
        [errors addObject:underlying];
    id multiple = [userInfo objectForKey:NSMultipleUnderlyingErrorsKey];
    if ([multiple isKindOfClass:[NSArray class]])
    {
        for (id error in multiple)
        {
            if ([error isKindOfClass:[NSError class]])
                [errors addObject:error];
        }
    }
    return [[errors copy] autorelease];
}

@end
