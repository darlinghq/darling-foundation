//
//  NSAttributedString.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSAttributedString.h>
#import "NSAttributedStringInternal.h"
#import "NSStringInternal.h"
#import "CFInternal.h"
#import <Foundation/NSLocale.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSPortCoder.h>
#import <dispatch/dispatch.h>

// The keys are stored in archives and AttributedString encodings, so they must match macOS.
// Sources: swift-foundation's LanguageIdentifierAttribute.name; OpenSwiftUI's non-Darwin shim.
NSAttributedStringKey const NSInlinePresentationIntentAttributeName = @"NSInlinePresentationIntent";
NSAttributedStringKey const NSLanguageIdentifierAttributeName = @"NSLanguage";

@implementation NSAttributedString

@end

@implementation NSMutableAttributedString

@end
CF_PRIVATE
@interface NSMutableStringProxyForMutableAttributedString : NSMutableString
{
    NSMutableAttributedString *_owner;
}
- (id)initWithMutableAttributedString:(NSMutableAttributedString *)owner;
@end

@implementation NSAttributedString (NSAttributedString)

OBJC_PROTOCOL_IMPL_PUSH
- (NSString *)string
{
    NSRequestConcreteImplementation();
    return nil;
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    NSRequestConcreteImplementation();
    return nil;
}
OBJC_PROTOCOL_IMPL_POP

@end

@implementation NSAttributedString (NSExtendedAttributedString)

+ (id)allocWithZone:(NSZone *)zone
{
    if (self == [NSMutableAttributedString class])
    {
        return [__NSPlaceholderAttributedString mutablePlaceholder];
    }
    else if (self == [NSAttributedString class])
    {
        return [__NSPlaceholderAttributedString immutablePlaceholder];
    }
    else
    {
        return [super allocWithZone:zone];
    }
}

- (id)initWithString:(NSString *)str
{
    return [self initWithString:str attributes:[NSDictionary dictionary]];
}

- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range
{
    NSString *s = [self string];
    NSUInteger length = [s length];
    if ((uint64_t)range.location + range.length > length)
    {
        @throw [NSException exceptionWithName:NSRangeException reason:[NSString stringWithFormat:@"range (%d,%d) beyond NSAttributedString bounds (%d)", range.location, range.length, [self length]] userInfo:nil];
    }
    NSString *substring = [s substringWithRange:range];
    NSMutableAttributedString *obj = [[[NSMutableAttributedString alloc] initWithString:substring] autorelease];

    NSUInteger delta = range.location;
    NSUInteger newLength;

    for (NSUInteger i = 0; i < range.length; i = i + newLength)
    {
        NSRange effRange;
        NSUInteger selfIndex = i + delta;
        NSDictionary *attrs = [self attributesAtIndex:selfIndex effectiveRange:&effRange];
        newLength = effRange.length;
        if (effRange.location < selfIndex)
        {
            newLength -= selfIndex - effRange.location;
        }
        if (newLength > range.length - i)
        {
            newLength = range.length - i;
        }
        [obj addAttributes:attrs range:NSMakeRange(i, newLength)];
    }
    return obj;
}

- (void)enumerateAttributesInRange:(NSRange)enumerationRange options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(NSDictionary<NSAttributedStringKey, id> * _Nonnull attrs, NSRange range, BOOL *stop))block
{
    if ((uint64_t)enumerationRange.location + enumerationRange.length > [self length])
    {
        @throw [NSException exceptionWithName:NSRangeException reason:[NSString stringWithFormat:@"range (%d,%d) beyond NSAttributedString bounds (%d)", enumerationRange.location, enumerationRange.length, [self length]] userInfo:nil];
    }
    if (enumerationRange.length == 0)
    {
        return;
    }
    if (opts & NSAttributedStringEnumerationReverse)
    {
        NSUInteger previous;
        NSUInteger limit = enumerationRange.location;
        for (NSUInteger i = enumerationRange.location + enumerationRange.length - 1; i >= limit; i = previous)
        {
            NSRange effRange;
            BOOL stop = NO;
            NSDictionary *dict;
            if (opts & NSAttributedStringEnumerationLongestEffectiveRangeNotRequired)
            {
                dict = [self attributesAtIndex:i effectiveRange:&effRange];
            }
            else
            {
                dict = [self attributesAtIndex:i longestEffectiveRange:&effRange inRange:enumerationRange];
            }
            block(dict, effRange, &stop);
            if (stop)
            {
                return;
            }
            if (effRange.location == 0)
            {
                break;
            }
            previous = effRange.location - 1;
        }
        return;
    }
    NSUInteger next;
    NSUInteger limit = enumerationRange.location + enumerationRange.length;
    for (NSUInteger i = enumerationRange.location; i < limit; i = next)
    {
        NSRange effRange;
        BOOL stop = NO;
        NSDictionary *dict;
        if (opts & NSAttributedStringEnumerationLongestEffectiveRangeNotRequired)
        {
            dict = [self attributesAtIndex:i effectiveRange:&effRange];
        }
        else
        {
            dict = [self attributesAtIndex:i longestEffectiveRange:&effRange inRange:enumerationRange];
        }
        block(dict, effRange, &stop);
        if (stop)
        {
            return;
        }
        next = effRange.location + effRange.length;
    }
}

- (void)enumerateAttribute:(NSString *)attrName inRange:(NSRange)enumerationRange options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(id value, NSRange range, BOOL *stop))block
{
    if ((uint64_t)enumerationRange.location + enumerationRange.length > [self length])
    {
        @throw [NSException exceptionWithName:NSRangeException reason:[NSString stringWithFormat:@"range (%d,%d) beyond NSAttributedString bounds (%d)", enumerationRange.location, enumerationRange.length, [self length]] userInfo:nil];
    }
    if (enumerationRange.length == 0)
    {
        return;
    }
    if (opts & NSAttributedStringEnumerationReverse)
    {
        NSUInteger previous;
        NSUInteger limit = enumerationRange.location;
        for (NSUInteger i = enumerationRange.location + enumerationRange.length - 1; i >= limit; i = previous)
        {
            NSRange effRange;
            BOOL stop = NO;
            NSDictionary *dict;
            if (opts & NSAttributedStringEnumerationLongestEffectiveRangeNotRequired)
            {
                dict = [self attributesAtIndex:i effectiveRange:&effRange];
            }
            else
            {
                dict = [self attributesAtIndex:i longestEffectiveRange:&effRange inRange:enumerationRange];
            }
            block(dict, effRange, &stop);
            if (stop)
            {
                return;
            }
            if (effRange.location == 0)
            {
                break;
            }
            previous = effRange.location - 1;
        }
        return;
    }
    NSUInteger next;
    NSUInteger limit = enumerationRange.location + enumerationRange.length;
    for (NSUInteger i = enumerationRange.location; i < limit; i = next)
    {
        NSRange effRange;
        BOOL stop = NO;
        id obj;
        if (opts & NSAttributedStringEnumerationLongestEffectiveRangeNotRequired)
        {
            obj = [self attribute:attrName atIndex:i effectiveRange:&effRange];
        }
        else
        {
            obj = [self attribute:attrName atIndex:i longestEffectiveRange:&effRange inRange:enumerationRange];
        }
        block(obj, effRange, &stop);
        if (stop)
        {
            return;
        }
        next = effRange.location + effRange.length;
    }
}

- (NSAttributedString *)copyWithZone:(NSZone *)zone
{
    // TODO optimize this to retain when input is immutable
    return [self mutableCopyWithZone:zone];
}

- (NSMutableAttributedString *)mutableCopyWithZone:(NSZone *)zone
{
    NSMutableAttributedString *retVal = [[NSMutableAttributedString alloc] initWithString:@""];
    [retVal setAttributedString:self];
    return retVal;
}

- (NSDictionary *)attributesAtIndex:(NSUInteger)index longestEffectiveRange:(NSRangePointer)aRange inRange:(NSRange)rangeLimit
{
    NSDictionary *retVal = [self attributesAtIndex:index effectiveRange:aRange];
    if (aRange == nil)
    {
        return retVal;
    }
    NSUInteger min = aRange->location;  // inclusive end
    NSUInteger max = aRange->location + aRange->length;  // exclusive end
    NSRange tempRange;
    while (min > 0 && [retVal isEqualToDictionary:[self attributesAtIndex:min - 1 effectiveRange:&tempRange]])
    {
        min = tempRange.location;
    }
    while (max < [self length] && [retVal isEqualToDictionary:[self attributesAtIndex:max effectiveRange:&tempRange]])
    {
        max = tempRange.location + tempRange.length;
    }
    aRange->location = min;
    aRange->length = max - min;
    *aRange = NSIntersectionRange(rangeLimit, *aRange);
    return retVal;
}

- (id)attribute:(NSString *)attrName atIndex:(NSUInteger)index longestEffectiveRange:(NSRangePointer)aRange inRange:(NSRange)rangeLimit
{
    id retVal = [self attribute:attrName atIndex:index effectiveRange:aRange];
    if (aRange == nil)
    {
        return retVal;
    }
    NSUInteger min = aRange->location;  // inclusive end
    NSUInteger max = aRange->location + aRange->length;  // exclusive end
    NSRange tempRange;
    while (min > 0 && retVal == [self attribute:attrName atIndex:min - 1 effectiveRange:&tempRange])
    {
        min = tempRange.location;
    }
    while (max < [self length] && retVal == [self attribute:attrName atIndex:max effectiveRange:&tempRange])
    {
        max = tempRange.location + tempRange.length;
    }
    aRange->location = min;
    aRange->length = max - min;
    *aRange = NSIntersectionRange(rangeLimit, *aRange);
    return retVal;
}

- (Class)classForCoder
{
    return [NSAttributedString self];
}

- (NSUInteger)length
{
    return [[self string] length];
}

- (id)attribute:(NSString *)attrName atIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range
{
    NSDictionary *dict = [self attributesAtIndex:location effectiveRange:range];
    return [dict objectForKey:attrName];
}

- (BOOL)isEqualToAttributedString:(NSAttributedString *)other
{
    if (self == other)
    {
        return YES;
    }
    if (other == nil)
    {
        return NO;
    }
    NSUInteger len = [self length];
    if (len != [other length])
    {
        return NO;
    }
    if (![[self string] isEqualToString:[other string]])
    {
        return NO;
    }
    for (NSUInteger next, i = 0; i < len; i = next)
    {
        NSRange r1, r2;
        if (![[self attributesAtIndex:i effectiveRange:&r1] isEqualToDictionary:[other attributesAtIndex:i effectiveRange:&r2]])
        {
            return NO;
        }
        NSUInteger limit1 = r1.location + r1.length;
        NSUInteger limit2 = r2.location + r2.location;
        NSUInteger nextR = MIN(limit1, limit2);
        if (nextR > i)
        {
            next = nextR;
        }
        else
        {
            next = i + 1;
        }
    }
    return YES;
}

- (BOOL)isEqual:(id)other
{
    if (![other isKindOfClass:[NSAttributedString class]])
    {
        return NO;
    }
    return [self isEqualToAttributedString:other];
}

#warning implement NSAttributeString coding

- (NSString *)description
{
    NSMutableString *out = [[[NSMutableString alloc] init] autorelease];
    NSString *s = [self string];
    NSUInteger len = [s length];
    [self enumerateAttributesInRange:NSMakeRange(0, len) options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        [out appendString:[s substringWithRange:range]];
        [out appendString:[attrs description]];
    }];
    return out;
}

- (NSUInteger)hash
{
    return [[self string] hash];
}

- (NSUInteger)_cfTypeID
{
    return CFAttributedStringGetTypeID();
}

@end

// Must match macOS: the key is stored in archives. Source: swift-foundation ReplacementIndexAttribute.name.
NSAttributedStringKey const NSReplacementIndexAttributeName = @"NSReplacementIndex";

static CFStringRef _NSAttributedFormatCopyDescription(void *value, const void *formatOptions)
{
    if ([(id)value isKindOfClass:[NSAttributedString class]])
    {
        return (CFStringRef)[[(NSAttributedString *)value string] copy];
    }
    return _NSCFCopyDescription2(value, formatOptions);
}

static NSUInteger _NSFormatMetadataValue(NSDictionary *entry, CFStringRef key)
{
    return [[entry objectForKey:(NSString *)key] unsignedIntegerValue];
}

static void _NSCopyFormatAttributes(NSAttributedString *format, NSRange formatRange, NSMutableAttributedString *result, NSUInteger resultLocation)
{
    [format enumerateAttributesInRange:formatRange options:0 usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        [result setAttributes:attrs range:NSMakeRange(resultLocation + range.location - formatRange.location, range.length)];
    }];
}

static void _NSRaiseFormatMismatch(NSAttributedString *format)
{
    [NSException raise:NSInvalidArgumentException format:@"arguments could not be applied to attributed format string \"%@\"", [format string]];
}

@implementation NSAttributedString (NSAttributedStringFormatting)

- (instancetype)initWithFormat:(NSAttributedString *)format options:(NSAttributedStringFormattingOptions)options locale:(NSLocale *)locale, ...
{
    va_list args;
    va_start(args, locale);
    self = [self initWithFormat:format options:options locale:locale arguments:args];
    va_end(args);
    return self;
}

- (instancetype)initWithFormat:(NSAttributedString *)format options:(NSAttributedStringFormattingOptions)options locale:(NSLocale *)locale arguments:(va_list)arguments
{
    if (format == nil)
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"nil format"];
        return nil;
    }

    CFArrayRef metadata = NULL;
    NSString *string = (NSString *)_CFStringCreateWithFormatAndArgumentsReturningMetadata(kCFAllocatorDefault, &_NSAttributedFormatCopyDescription, NULL, (CFDictionaryRef)(CFLocaleRef)locale, NULL, (CFStringRef)[format string], &metadata, arguments);
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:string];
    [string release];
    [(id)metadata autorelease];

    // Text between specifiers is copied verbatim, so it maps 1:1 onto the format.
    NSUInteger formatLocation = 0;
    NSUInteger resultLocation = 0;
    for (NSDictionary *entry in (NSArray *)metadata)
    {
        NSRange spec = NSMakeRange(_NSFormatMetadataValue(entry, _kCFStringFormatMetadataSpecifierRangeLocationInFormatStringKey),
                                   _NSFormatMetadataValue(entry, _kCFStringFormatMetadataSpecifierRangeLengthInFormatStringKey));
        NSRange replacement = NSMakeRange(_NSFormatMetadataValue(entry, _kCFStringFormatMetadataReplacementRangeLocationKey),
                                          _NSFormatMetadataValue(entry, _kCFStringFormatMetadataReplacementRangeLengthKey));
        if (spec.location - formatLocation != replacement.location - resultLocation)
        {
            [result release];
            [self release];
            _NSRaiseFormatMismatch(format);
            return nil;
        }
        _NSCopyFormatAttributes(format, NSMakeRange(formatLocation, spec.location - formatLocation), result, resultLocation);

        if (replacement.length > 0)
        {
            NSDictionary *specAttributes = [format attributesAtIndex:spec.location effectiveRange:NULL];
            id argument = [entry objectForKey:(NSString *)_kCFStringFormatMetadataArgumentObjectKey];
            if ([argument isKindOfClass:[NSAttributedString class]])
            {
                BOOL argumentWins = (options & NSAttributedStringFormattingInsertArgumentAttributesWithoutMerging) != 0;
                [argument enumerateAttributesInRange:NSMakeRange(0, MIN(replacement.length, [argument length])) options:0 usingBlock:^(NSDictionary *argumentAttributes, NSRange range, BOOL *stop) {
                    NSMutableDictionary *merged = [(argumentWins ? specAttributes : argumentAttributes) mutableCopy];
                    [merged addEntriesFromDictionary:argumentWins ? argumentAttributes : specAttributes];
                    [result setAttributes:merged range:NSMakeRange(replacement.location + range.location, range.length)];
                    [merged release];
                }];
            }
            else
            {
                [result setAttributes:specAttributes range:replacement];
            }
            NSNumber *index = [entry objectForKey:(NSString *)_kCFStringFormatMetadataReplacementIndexKey];
            if ((options & NSAttributedStringFormattingApplyReplacementIndexAttribute) && index != nil)
            {
                [result addAttribute:NSReplacementIndexAttributeName value:index range:replacement];
            }
        }
        formatLocation = NSMaxRange(spec);
        resultLocation = NSMaxRange(replacement);
    }

    NSUInteger trailing = [format length] - formatLocation;
    if (trailing != [result length] - resultLocation)
    {
        [result release];
        [self release];
        _NSRaiseFormatMismatch(format);
        return nil;
    }
    _NSCopyFormatAttributes(format, NSMakeRange(formatLocation, trailing), result, resultLocation);

    self = [self initWithAttributedString:result];
    [result release];
    return self;
}

+ (instancetype)localizedAttributedStringWithFormat:(NSAttributedString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSAttributedString *result = [[self alloc] initWithFormat:format options:0 locale:[NSLocale currentLocale] arguments:args];
    va_end(args);
    return [result autorelease];
}

+ (instancetype)localizedAttributedStringWithFormat:(NSAttributedString *)format options:(NSAttributedStringFormattingOptions)options, ...
{
    va_list args;
    va_start(args, options);
    NSAttributedString *result = [[self alloc] initWithFormat:format options:options locale:[NSLocale currentLocale] arguments:args];
    va_end(args);
    return [result autorelease];
}

@end

@implementation NSAttributedString (NSAttributedStringPortCoding)

- (id) replacementObjectForPortCoder: (NSPortCoder *) portCoder {
    return self;
}

@end

@implementation NSMutableAttributedString (NSMutableAttributedString)

OBJC_PROTOCOL_IMPL_PUSH
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
    NSRequestConcreteImplementation();
}

- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range
{
    NSRequestConcreteImplementation();
}
OBJC_PROTOCOL_IMPL_POP

@end


@implementation NSMutableAttributedString (NSExtendedMutableAttributedString)

- (NSMutableString *)mutableString
{
    return [[[NSMutableStringProxyForMutableAttributedString alloc] initWithMutableAttributedString:self] autorelease];
}

- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range
{
    NSDictionary *d = @{ name : value };
    [self addAttributes:d range:range];
}

- (void)addAttributes:(NSDictionary *)attrs range:(NSRange)range
{
    [self enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary *innerAttrs, NSRange innerRange, BOOL *stop) {
        NSMutableDictionary *d = [innerAttrs mutableCopy];
        [d addEntriesFromDictionary:attrs];
        [self setAttributes:d range:innerRange];
        [d release];
    }];
}

- (void)removeAttribute:(NSString *)name range:(NSRange)range
{
    [self enumerateAttributesInRange:range options:0 usingBlock:^(NSDictionary *attrs, NSRange innerRange, BOOL *stop) {
        NSMutableDictionary *d = [attrs mutableCopy];
        [d removeObjectForKey:name];
        [self setAttributes:d range:innerRange];
        [d release];
    }];
}

- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)attrString
{
    [self replaceCharactersInRange:range withString:[attrString string]];
    [attrString enumerateAttributesInRange:NSMakeRange(0, [attrString length]) options:0 usingBlock:^(NSDictionary *attrs, NSRange replaceRange, BOOL *stop) {
        [self setAttributes:attrs range:NSMakeRange(range.location + replaceRange.location, replaceRange.length)];
    }];
}

- (void)insertAttributedString:(NSAttributedString *)attrString atIndex:(NSUInteger)loc
{
    [self replaceCharactersInRange:NSMakeRange(loc, 0) withAttributedString:attrString];
}

- (void)appendAttributedString:(NSAttributedString *)attrString
{
    [self replaceCharactersInRange:NSMakeRange([self length], 0) withAttributedString:attrString];
}

- (void)deleteCharactersInRange:(NSRange)range
{
    [self replaceCharactersInRange:range withString:@""];
}

- (void)setAttributedString:(NSAttributedString *)attrString
{
    [self replaceCharactersInRange:NSMakeRange(0, [self length]) withAttributedString:attrString];
}

- (void)appendLocalizedFormat:(NSAttributedString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSAttributedString *formatted = [[NSAttributedString alloc] initWithFormat:format options:0 locale:[NSLocale currentLocale] arguments:args];
    va_end(args);
    [self appendAttributedString:formatted];
    [formatted release];
}

- (void)beginEditing
{
// purposeful nop
}

- (void)endEditing
{
// purposeful nop
}
@end


@implementation __NSPlaceholderAttributedString

static __NSPlaceholderAttributedString *immutablePlaceholder = nil;
static __NSPlaceholderAttributedString *mutablePlaceholder = nil;

+ (id)immutablePlaceholder
{
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        immutablePlaceholder = [__NSPlaceholderAttributedString alloc];
    });
    return immutablePlaceholder;
}

+ (id)mutablePlaceholder
{
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        mutablePlaceholder = [__NSPlaceholderAttributedString alloc];
    });
    return mutablePlaceholder;
}

- (id)init {
    return [self initWithString:@"" attributes:[NSDictionary dictionary]];
}

- (id)initWithString:(NSString *)str attributes:(NSDictionary *)attrs
{
    CFAttributedStringRef string = CFAttributedStringCreate(kCFAllocatorDefault, (CFStringRef)str, (CFDictionaryRef)attrs);
    _CFAttributedStringSetMutable(string, self == mutablePlaceholder);
    return (id)string;
}

- (id)initWithAttributedString:(NSAttributedString *)attrStr
{
    if (self == mutablePlaceholder)
    {
        return (id)CFAttributedStringCreateMutableCopy(kCFAllocatorDefault, 0, (CFAttributedStringRef)attrStr);
    }
    else
    {
        return (id)CFAttributedStringCreateCopy(kCFAllocatorDefault, (CFAttributedStringRef)attrStr);
    }
}

SINGLETON_RR()

@end

@implementation NSMutableStringProxyForMutableAttributedString

- (id)initWithMutableAttributedString:(NSMutableAttributedString *)owner
{
    self = [super init];

    if (self)
    {
        _owner = [owner retain];
    }

    return self;
}

- (NSUInteger)length
{
    return [_owner length];
}

- (unichar)characterAtIndex:(NSUInteger)index
{
    return [[_owner string] characterAtIndex:index];
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)aRange
{
    [[_owner string] getCharacters:buffer range:aRange];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str
{
    [_owner replaceCharactersInRange:range withString:str];
}

- (void)dealloc
{
    [_owner release];
    [super dealloc];
}

@end
