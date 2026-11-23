//
//  NSLocale.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSLocale.h>

#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSString.h>

NSString *const NSLocaleLanguageConfidenceHigh = @"NSLocaleLanguageConfidenceHigh";
NSString *const NSLocaleLanguageConfidenceMedium = @"NSLocaleLanguageConfidenceMedium";

CF_PRIVATE
@interface NSAutoLocale : NSLocale
{
    NSLocale *loc;
}
- (id)_init;
@end

@interface NSLocale (Internal)
- (id)_prefs;
@end


@implementation NSLocale (NSLocale)

- (Class)classForCoder
{
    return [NSLocale self];
}

+ (id)autoupdatingCurrentLocale
{
    return [[[NSAutoLocale alloc] _init] autorelease];
}

- (NSString *) languageCode {
    return [self objectForKey: NSLocaleLanguageCode];
}

- (NSString *)countryCode {
    return [self objectForKey: NSLocaleCountryCode];
}

- (NSString *)languageIdentifier {
    NSString *identifier = [self localeIdentifier];
    NSRange keywordStart = [identifier rangeOfString:@"@"];
    if (keywordStart.location != NSNotFound) {
        identifier = [identifier substringToIndex:keywordStart.location];
    }
    return [[self class] canonicalLanguageIdentifierFromString:identifier];
}

@end


// Each of these is documented as equivalent to -displayNameForKey:value: with the matching key, so they
// go through it and work for every NSLocale subclass.
@implementation NSLocale (NSLocaleDisplayNames)

- (NSString *)localizedStringForLocaleIdentifier:(NSString *)localeIdentifier
{
    return [self displayNameForKey:NSLocaleIdentifier value:localeIdentifier];
}

- (NSString *)localizedStringForLanguageCode:(NSString *)languageCode
{
    return [self displayNameForKey:NSLocaleLanguageCode value:languageCode];
}

- (NSString *)localizedStringForCountryCode:(NSString *)countryCode
{
    return [self displayNameForKey:NSLocaleCountryCode value:countryCode];
}

- (NSString *)localizedStringForScriptCode:(NSString *)scriptCode
{
    return [self displayNameForKey:NSLocaleScriptCode value:scriptCode];
}

- (NSString *)localizedStringForVariantCode:(NSString *)variantCode
{
    return [self displayNameForKey:NSLocaleVariantCode value:variantCode];
}

- (NSString *)localizedStringForCollationIdentifier:(NSString *)collationIdentifier
{
    return [self displayNameForKey:NSLocaleCollationIdentifier value:collationIdentifier];
}

- (NSString *)localizedStringForCurrencyCode:(NSString *)currencyCode
{
    return [self displayNameForKey:NSLocaleCurrencyCode value:currencyCode];
}

- (NSString *)localizedStringForCollatorIdentifier:(NSString *)collatorIdentifier
{
    return [self displayNameForKey:NSLocaleCollatorIdentifier value:collatorIdentifier];
}

@end


@implementation NSAutoLocale

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (Class)classForCoder
{
    return [NSAutoLocale self];
}

- (id)initWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
    {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"NSLocale does not support non keyed coders"];
        return nil;
    }
    return [self _init];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (![coder allowsKeyedCoding])
    {
        [NSException raise:NSInvalidArgumentException format:@"NSLocale does not support non keyed coders"];
        return;
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (id)description
{
    return [loc description];
}

- (id)_prefs
{
    return [loc _prefs];
}

- (NSString *)displayNameForKey:(id)key value:(id)value
{
    return [loc displayNameForKey:key value:value];
}

- (id)objectForKey:(id)key
{
    return [loc objectForKey:key];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (id)initWithLocaleIdentifier:(NSString *)identifier
{
    return [self _init];
}

- (id)_init
{
    self = [super init];
    if (self)
    {
        loc = [[NSLocale currentLocale] retain];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_update:) name:(NSString *)kCFLocaleCurrentLocaleDidChangeNotification object:nil];
    }
    return self;
}

- (void)_update:(NSNotification *)notif
{
    [loc release];
    loc = [[NSLocale currentLocale] retain];
}


@end
