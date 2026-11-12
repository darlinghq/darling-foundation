//
//  NSOrthography.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSOrthography.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSString.h>
#import "NSObjectInternal.h"

typedef NS_OPTIONS(NSUInteger, NSOrthographyFlags) {
	__some_enum_elem_to_keep_compiler_happy
};

@interface NSComplexOrthography : NSOrthography
{
    NSString *_dominantScript;
    NSDictionary *_languageMap;
    NSOrthographyFlags _orthographyFlags;
}

+ (void)initialize;
- (id)initWithDominantScript:(NSString *)script languageMap:(NSDictionary *)map;
- (NSOrthographyFlags)orthographyFlags;
- (NSDictionary *)languageMap;
- (NSString *)dominantScript;
- (void)dealloc;

@end

@implementation NSOrthography

+ (void)initialize
{

}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (id)allocWithZone:(NSZone *)zone
{
    if (self == [NSOrthography class])
    {
        return [NSComplexOrthography allocWithZone:zone];
    }
    else
    {
        return [super allocWithZone:zone];
    }
}

+ (id)orthographyWithDominantScript:(NSString *)script languageMap:(NSDictionary *)map
{
    return [[[self alloc] initWithDominantScript:script languageMap:map] autorelease];
}

- (id)initWithDominantScript:(NSString *)script languageMap:(NSDictionary *)map
{
    NSRequestConcreteImplementation();
    [self release];
    return nil;
}

- (NSArray *)allLanguages
{
    NSArray *scripts = [self allScripts];
    NSMutableArray *langs = [[NSMutableArray alloc] initWithCapacity:[scripts count]];
    for (NSString *script in scripts)
    {
        NSArray *scriptLangs = [self languagesForScript:script];
        for (NSString *language in scriptLangs)
        {
            if (![langs containsObject:language])
            {
                [langs addObject:language];
            }
        }
    }
    return langs;
}

- (NSArray *)allScripts
{
    NSArray *scripts = [[self languageMap] allKeys];
    NSMutableArray *all = [[NSMutableArray alloc] initWithArray:scripts];
    NSString *dominant = [self dominantScript];
    // ensure dominant is the first script (even for subclassers)
    [all removeObject:dominant];
    [all insertObject:dominant atIndex:0];
    return [all autorelease];
}

- (NSString *)dominantLanguage
{
    return [self dominantLanguageForScript:[self dominantScript]];
}

- (NSString *)dominantLanguageForScript:(NSString *)script
{
    NSString *dominant = nil;
    NSArray *languages = [self languagesForScript:script];
    if ([languages count] > 0)
    {
        dominant = languages[0];
    }
    return dominant;
}

- (NSArray *)languagesForScript:(NSString *)script
{
    return [[self languageMap] objectForKey:script];
}

- (NSOrthographyFlags)orthographyFlags
{
    // TODO: this is incorrect... (what is it used for?)
    return 0;
}

- (NSDictionary *)languageMap
{
    NSRequestConcreteImplementation();
    return nil;
}

- (NSString *)dominantScript
{
    NSRequestConcreteImplementation();
    return nil;
}

- (BOOL)isEqual:(id)other
{
    if (self == other)
    {
        return YES;
    }
    if (![other isKindOfClass:[NSOrthography class]])
    {
        return NO;
    }
    if (![[self dominantScript] isEqualToString:[other dominantScript]])
    {
        return NO;
    }
    if (![[self languageMap] isEqual:[other languageMap]])
    {
        return NO;
    }
    return YES;
}

- (NSUInteger)hash
{
    return [self orthographyFlags] ^ [[self dominantScript] hash] ^ [[self languageMap] hash];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSRequestConcreteImplementation();
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSRequestConcreteImplementation();
    [self release];
    return nil;
}

@end

@interface NSSimpleOrthography : NSOrthography
{
    NSOrthographyFlags _orthographyFlags;
}

+ (void)initialize;
+ (id)orthographyWithFlags:(NSOrthographyFlags)flags;
- (id)initWithDominantScript:(NSString *)script languageMap:(NSDictionary *)map;
- (id)initWithFlags:(NSOrthographyFlags)flags;
- (NSArray *)allLanguages;
- (NSArray *)allScripts;
- (NSString *)dominantLanguage;
- (NSString *)dominantLanguageForScript:(NSString *)script;
- (NSArray *)languagesForScript:(NSString *)script;
- (NSOrthographyFlags)orthographyFlags;
- (NSDictionary *)languageMap;
- (NSString *)dominantScript;
- (id)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;
- (Class)classForCoder;

@end


@implementation NSSimpleOrthography
@end

@implementation NSComplexOrthography

- (id)initWithDominantScript:(NSString *)script languageMap:(NSDictionary *)map
{
    self = [super init];
    if (self)
    {
        _dominantScript = [script copy];
        _languageMap = [map copy];
    }
    return self;
}

- (void)dealloc
{
    [_dominantScript release];
    [_languageMap release];
    [super dealloc];
}

- (NSString *)dominantScript
{
    return _dominantScript;
}

- (NSDictionary *)languageMap
{
    return _languageMap;
}

- (NSOrthographyFlags)orthographyFlags
{
    return _orthographyFlags;
}

- (Class)classForCoder
{
    return [NSOrthography class];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_dominantScript forKey:@"NSDominantScript"];
    [coder encodeObject:_languageMap forKey:@"NSLanguageMap"];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSString *script = nil;
    NSDictionary *map = nil;
    if ([coder allowsKeyedCoding])
    {
        script = [coder decodeObjectOfClass:[NSString class] forKey:@"NSDominantScript"];
        map = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSArray class], [NSString class], nil] forKey:@"NSLanguageMap"];
    }
    BOOL valid = script != nil && [map isKindOfClass:[NSDictionary class]];
    if (valid)
    {
        for (id key in map)
        {
            id languages = [map objectForKey:key];
            if (![key isKindOfClass:[NSString class]] || ![languages isKindOfClass:[NSArray class]])
            {
                valid = NO;
                break;
            }
            for (id language in languages)
            {
                if (![language isKindOfClass:[NSString class]])
                {
                    valid = NO;
                    break;
                }
            }
        }
    }
    if (!valid)
    {
        [self release];
        return nil;
    }
    return [self initWithDominantScript:script languageMap:map];
}

@end
