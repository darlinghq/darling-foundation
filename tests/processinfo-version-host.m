// SPDX-License-Identifier: GPL-3.0-or-later
/* Runs -[NSProcessInfo operatingSystemVersionString] and -operatingSystemVersion from src/NSProcessInfo.m against
 * a minimal mock root class and a mock _CFCopySystemVersionDictionary() that returns what CoreFoundation builds
 * from SystemVersion.plist (CFUtilities.c: ProductVersion from the plist, FullVersionString as
 * "Version <ProductVersion> (Build <ProductBuildVersion>)").
 *
 * Apple documents operatingSystemVersionString as human readable and "not appropriate for parsing", so it is the
 * full description, and operatingSystemVersion must come from the numeric ProductVersion, also when a subclass
 * overrides the description. tests/processinfo-version-host.sh extracts both methods at build time. */
#include <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef long NSInteger;
typedef unsigned long NSUInteger;
typedef struct {
    NSInteger majorVersion;
    NSInteger minorVersion;
    NSInteger patchVersion;
} NSOperatingSystemVersion;

// Constant strings (the class name and layout clang emits for @"" with the GNUstep runtime) put their characters
// right after isa, so the root class has no other ivar and objects are not reference counted except the dictionary.
__attribute__((objc_root_class))
@interface NSObject {
    Class isa;
}
+ (id)alloc;
- (id)init;
- (id)retain;
- (void)release;
- (id)autorelease;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self, 0); }
- (id)init { return self; }
- (id)retain { return self; }
- (void)release {}
- (id)autorelease { return self; }
@end

@class NSArray;
@interface NSString : NSObject
- (const char *)UTF8String;
- (BOOL)isEqualToString:(NSString *)other;
- (NSInteger)integerValue;
- (NSArray *)componentsSeparatedByString:(NSString *)separator;
@end

@interface NSConstantString : NSString {
    const char *_chars;
    unsigned int _length;
}
@end
@implementation NSConstantString
- (const char *)UTF8String { return _chars; }
@end

@interface MockString : NSString {
    char *_chars;
}
+ (id)stringWithBytes:(const char *)bytes length:(size_t)length;
@end
@implementation MockString
+ (id)stringWithBytes:(const char *)bytes length:(size_t)length
{
    MockString *s = [self alloc];
    s->_chars = strndup(bytes, length);
    return s;
}
- (const char *)UTF8String { return _chars; }
@end

@interface NSArray : NSObject {
    id _items[8];
    NSUInteger _count;
}
- (NSUInteger)count;
- (id)objectAtIndex:(NSUInteger)index;
- (void)addObject:(id)object;
@end
@implementation NSArray
- (NSUInteger)count { return _count; }
- (id)objectAtIndex:(NSUInteger)index
{
    if (index >= _count) { printf("FAIL: objectAtIndex:%lu beyond %lu\n", index, _count); exit(2); }
    return _items[index];
}
- (void)addObject:(id)object { _items[_count++] = object; }
@end

@implementation NSString
- (const char *)UTF8String { return ""; }
- (BOOL)isEqualToString:(NSString *)other { return strcmp([self UTF8String], [other UTF8String]) == 0; }
- (NSInteger)integerValue { return strtol([self UTF8String], NULL, 10); }
- (NSArray *)componentsSeparatedByString:(NSString *)separator
{
    NSArray *parts = [NSArray alloc];
    const char *s = [self UTF8String], *sep = [separator UTF8String], *hit;
    while ((hit = strstr(s, sep)) != NULL) {
        [parts addObject:[MockString stringWithBytes:s length:(size_t)(hit - s)]];
        s = hit + strlen(sep);
    }
    [parts addObject:[MockString stringWithBytes:s length:strlen(s)]];
    return parts;
}
@end

static int liveDictionaries;
@interface NSDictionary : NSObject {
@public
    NSString *_keys[4];
    id _values[4];
    int _count;
    int _retainCount;
}
- (id)objectForKey:(NSString *)key;
@end
@implementation NSDictionary
- (id)objectForKey:(NSString *)key
{
    for (int i = 0; i < _count; i++)
        if ([_keys[i] isEqualToString:key]) return _values[i];
    return nil;
}
- (id)retain { _retainCount++; return self; }
- (void)release { if (--_retainCount == 0) liveDictionaries--; }
@end

static const char *productVersion = "26.0.1";
static const char *fullVersionString = "Version 26.0.1 (Build Darling)";

// What CoreFoundation's _CFCopySystemVersionDictionary() returns: a new (+1) dictionary per call.
static void *_CFCopySystemVersionDictionary(void)
{
    NSDictionary *d = [NSDictionary alloc];
    const char *pairs[][2] = {
        { "ProductBuildVersion", "Darling" },
        { "ProductVersion", productVersion },
        { "FullVersionString", fullVersionString },
    };
    for (int i = 0; i < 3; i++) {
        d->_keys[i] = [MockString stringWithBytes:pairs[i][0] length:strlen(pairs[i][0])];
        d->_values[i] = [MockString stringWithBytes:pairs[i][1] length:strlen(pairs[i][1])];
    }
    d->_count = 3;
    d->_retainCount = 1;
    liveDictionaries++;
    return d;
}

@interface NSProcessInfo : NSObject
- (NSString *)operatingSystemVersionString;
- (NSOperatingSystemVersion)operatingSystemVersion;
@end

// The methods below come from the Darwin side of NSProcessInfo.m.
#define __APPLE__ 1
@implementation NSProcessInfo
#include METHODS_INC
@end

@interface LocalizedProcessInfo : NSProcessInfo
@end
@implementation LocalizedProcessInfo
- (NSString *)operatingSystemVersionString { return @"Versión 26.0.1 (compilación Darling)"; }
@end

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static void checkVersion(NSProcessInfo *info, NSInteger major, NSInteger minor, NSInteger patch, const char *how)
{
    NSOperatingSystemVersion v = [info operatingSystemVersion];
    CK(v.majorVersion == major && v.minorVersion == minor && v.patchVersion == patch,
       "%s: operatingSystemVersion is %ld.%ld.%ld, want %ld.%ld.%ld", how, v.majorVersion, v.minorVersion,
       v.patchVersion, major, minor, patch);
}

int main(void)
{
    NSProcessInfo *info = [[NSProcessInfo alloc] init];

    NSString *description = [info operatingSystemVersionString];
    CK(description != nil && strcmp([description UTF8String], fullVersionString) == 0,
       "operatingSystemVersionString is the full version description \"%s\" (got \"%s\")", fullVersionString,
       description ? [description UTF8String] : "(nil)");

    checkVersion(info, 26, 0, 1, "ProductVersion 26.0.1");
    checkVersion([[LocalizedProcessInfo alloc] init], 26, 0, 1, "subclass with a localized description");

    productVersion = "15.7";
    fullVersionString = "Version 15.7 (Build Darling)";
    checkVersion(info, 15, 7, 0, "ProductVersion 15.7");

    CK(liveDictionaries == 0, "every system version dictionary is released (%d left)", liveDictionaries);

    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
