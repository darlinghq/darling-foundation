//
//  NSUserDefaults.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <CoreFoundation/CFPreferences.h>
#include "ForFoundationOnly.h"
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSKeyedArchiver.h>
#import "NSObjectInternal.h"
#import <pthread.h>
#include <stdlib.h>

NSString * const NSGlobalDomain = @"NSGlobalDomain";
NSString * const NSArgumentDomain = @"NSArgumentDomain";
NSString * const NSRegistrationDomain = @"NSRegistrationDomain";
NSString * const NSUserDefaultsDidChangeNotification = @"NSUserDefaultsDidChangeNotification";

static NSUserDefaults *standardDefaults = nil;
static dispatch_queue_t synchronizeQueue;
static dispatch_queue_t notificationQueue;

static pthread_mutex_t defaultsLock = PTHREAD_MUTEX_INITIALIZER;

#define SYNC_INTERVAL 30

#define APP_NAME (self->_suiteName != nil ? (CFStringRef) self->_suiteName : kCFPreferencesCurrentApplication)

static void initQueues() {
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        synchronizeQueue = dispatch_queue_create("com.apportable.synchronize.userdefaults", NULL);
        notificationQueue = dispatch_queue_create("com.apportable.notify.userdefaults", NULL);
    });
};

@implementation NSUserDefaults (NSUserDefaults)

+ (NSUserDefaults *)standardUserDefaults
{
    pthread_mutex_lock(&defaultsLock);
    if (standardDefaults == nil)
    {
        standardDefaults = [[NSUserDefaults alloc] init];
        [standardDefaults setObject:[NSLocale preferredLanguages] forKey:@"AppleLanguages"];
        [standardDefaults setObject:[[NSLocale systemLocale] languageCode] forKey:@"AppleLocale"];
    }
    pthread_mutex_unlock(&defaultsLock);
    return standardDefaults;
}

+ (void)resetStandardUserDefaults
{
    pthread_mutex_lock(&defaultsLock);
    [standardDefaults release];
    standardDefaults = nil;
    pthread_mutex_unlock(&defaultsLock);
}

- (id)init
{
    return [self initWithSuiteName: nil];
}

- (id) initWithSuiteName: (NSString *) name {
    initQueues();

    _suiteName = [name copy];
    _volatileDomains = [[NSMutableDictionary alloc] init];
    _synchronizeTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, synchronizeQueue);

    // set interval
    dispatch_source_set_timer(_synchronizeTimer, dispatch_time(DISPATCH_TIME_NOW, SYNC_INTERVAL * NSEC_PER_SEC), SYNC_INTERVAL * NSEC_PER_SEC, 0);

    NSString* appName = APP_NAME;
    dispatch_source_set_event_handler(_synchronizeTimer, ^{
        CFPreferencesAppSynchronize(appName);
    });

    // now that the timer is set up, start it up
    dispatch_resume(_synchronizeTimer);

    [self setVolatileDomain: [self parseArguments] forName: NSArgumentDomain];
    return self;
}

- (id)initWithUser:(NSString *)user
{
    // Ignore the user; just init a regular defaults instance.
    return [self init];
}

- (void)dealloc
{
    dispatch_source_cancel(_synchronizeTimer);
    dispatch_release(_synchronizeTimer);

    [_suiteName release];
    [_volatileDomains release];
    [super dealloc];
}

- (id) parseArgumentValue: (NSString *) value {
    // TODO: NSPropertyListSerialization
    return value;
}

- (NSDictionary *) parseArguments {
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    NSMutableDictionary *res = [[NSMutableDictionary alloc] init];

    NSUInteger count = [args count];

    for (int i = 1; i + 1 < count; i++) {
        NSString *key = args[i];
        NSString *value = args[i + 1];

        if (![key hasPrefix: @"-"] || [value hasPrefix: @"-"]) continue;
        key = [key substringFromIndex: 1];
        key = [key stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([key length] == 0) continue;

        value = [value stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        res[key] = [self parseArgumentValue: value];

        // Skip the just parsed value and move to the next pair.
        i++;
    }

    return [res autorelease];
}

- (id)objectForKey:(NSString *)key
{
    __block id value = nil;

    value = [self volatileDomainForName: NSArgumentDomain][key];
    if (value != nil) {
        return value;
    }

    dispatch_sync(synchronizeQueue, ^{
        value = [[(id)CFPreferencesCopyAppValue((CFStringRef)key, APP_NAME) retain] autorelease];
    });
    if (value != nil) {
        return value;
    }

    value = [self volatileDomainForName: NSRegistrationDomain][key];
    return value;
}

- (void)setObject:(id)value forKey:(NSString *)key
{
    if (value != NULL && !NSIsPlistType(value))
    {
        NSLog(@"%@ is not a valid type to set in NSUserDefaults", value);
        return;
    }

    // Avoid nuking AppleLanguages since it is used for CFLocale to write plists and such
    // This is likley yet another variation on CFXPreferences vs CFApplicationPreferences
    if (value == nil && [key isEqualToString:@"AppleLanguages"])
    {
        return;
    }

    // For KVO to work, we must synchronize on the value setter; otherwise the
    // "will" and "did" set notifications will lie and wrong values will be
    // received by observers. We additionally dispatch the notification
    // asynchronously to avoid blocking on observers of the notification itself.
    [self willChangeValueForKey:key];
    dispatch_sync(synchronizeQueue, ^{
        CFPreferencesSetAppValue((CFStringRef)key, (CFTypeRef)value, APP_NAME);
        dispatch_async(notificationQueue, ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NSUserDefaultsDidChangeNotification object:self userInfo:nil];
        });
    });
    [self didChangeValueForKey:key];
}

- (void)registerDefaults:(NSDictionary *)dictionary
{
   [self setVolatileDomain: dictionary forName: NSRegistrationDomain];
}

- (void)removeObjectForKey:(NSString *)key
{
    [self setObject:nil forKey:key];
}

- (NSString *)stringForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isNSString__])
    {
        return value;
    }
    else if ([value isNSNumber__])
    {
        return [value stringValue];
    }
    return nil;
}

- (NSArray *)arrayForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isNSArray__])
    {
        return value;
    }
    return nil;
}

- (NSDictionary *)dictionaryForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isNSDictionary__])
    {
        return value;
    }
    return nil;
}

- (NSData *)dataForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isNSData__])
    {
        return value;
    }
    return nil;
}

- (NSArray *)stringArrayForKey:(NSString *)key
{
    NSArray *value = [self objectForKey:key];
    if ([value isNSArray__])
    {
        NSUInteger count = [value count];
        if (count == 0)
        {
            return @[];
        }

        id *objects = malloc(count * sizeof(id));
        id *result = malloc(count * sizeof(id));
        NSUInteger resultCount = 0;
        if (objects == NULL || result == NULL)
        {
            free(objects);
            free(result);
            [NSException raise:NSMallocException format:@"Could not allocate buffer"];
            return nil;
        }

        [value getObjects:objects range:NSMakeRange(0, count)];

        for (NSUInteger idx = 0; idx < count; idx++)
        {
            if ([objects[idx] isNSString__])
            {
                result[resultCount] = objects[idx];
                resultCount++;
            }
        }
        NSArray *found = [[NSArray alloc] initWithObjects:result count:resultCount];
        free(objects);
        free(result);
        return [found autorelease];
    }
    return nil;
}

- (NSInteger)integerForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isNSString__] || [value isNSNumber__])
    {
        return [value integerValue];
    }
    return 0;
}

- (float)floatForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isNSString__] || [value isNSNumber__])
    {
        return [value floatValue];
    }
    return 0.0f;
}

- (double)doubleForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isNSString__] || [value isNSNumber__])
    {
        return [value doubleValue];
    }
    return 0.0f;
}

- (BOOL)boolForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isNSString__] || [value isNSNumber__])
    {
        return [value boolValue]; // this is not exactly correct, but should work ok
    }
    return 0.0f;
}

- (NSURL *)URLForKey:(NSString *)key
{
    id value = [self objectForKey:key];
    if ([value isNSString__])
    {
        return [NSURL fileURLWithPath:[value stringByExpandingTildeInPath]];
    }
    else if ([value isNSData__])
    {
        value = [NSKeyedUnarchiver unarchiveObjectWithData:value];
        if ([value isKindOfClass:[NSURL class]])
        {
            return value;
        }
    }
    return nil;
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key
{
    [self setObject:[NSNumber numberWithInteger:value] forKey:key];
}

- (void)setFloat:(float)value forKey:(NSString *)key
{
    [self setObject:[NSNumber numberWithFloat:value] forKey:key];
}

- (void)setDouble:(double)value forKey:(NSString *)key
{
    [self setObject:[NSNumber numberWithDouble:value] forKey:key];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key
{
    [self setObject:[NSNumber numberWithBool:value] forKey:key];
}

- (void)setURL:(NSURL *)URL forKey:(NSString *)key
{
    if ([URL isFileURL] || [URL isFileReferenceURL])
    {
        [self setObject:[[URL absoluteURL] path] forKey:key];
    }
    else
    {
        [self setObject:[NSKeyedArchiver archivedDataWithRootObject:URL] forKey:key];
    }
}

- (BOOL)synchronize
{
    __block BOOL synced = NO;
    dispatch_sync(synchronizeQueue, ^{
        synced = CFPreferencesAppSynchronize(APP_NAME);
    });
    return synced;
}

- (NSDictionary *)dictionaryRepresentation
{
    __block NSDictionary *cfPrefs = nil;

    dispatch_sync(synchronizeQueue, ^{
        cfPrefs = (NSDictionary *) CFPreferencesCopyMultiple(
            /* fetch all keys */ nil,
            APP_NAME,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        );
    });

    NSMutableDictionary *res = [[cfPrefs autorelease] mutableCopy];

    NSDictionary *domain = [self volatileDomainForName: NSArgumentDomain];
    for (NSString *key in domain) {
        if (res[key] == nil) {
            res[key] = domain[key];
        }
    }

    domain = [self volatileDomainForName: NSRegistrationDomain];
    for (NSString *key in domain) {
        if (res[key] == nil) {
            res[key] = domain[key];
        }
    }

    return [res autorelease];
}

- (NSArray *) volatileDomainNames {
    NSArray *res = nil;

    @synchronized (_volatileDomains) {
        res = [[_volatileDomains allKeys] copy];
    }

    return [res autorelease];
}

- (NSDictionary *) volatileDomainForName: (NSString *) domainName {
    NSDictionary<NSString *, id> *res = nil;

    @synchronized (_volatileDomains) {
        res = [_volatileDomains[domainName] copy];
    }

    return [res autorelease];
}

- (void) setVolatileDomain: (NSDictionary *) domain forName: (NSString *) domainName {
    if (!NSIsPlistType(domain)) {
        NSLog(@"%@ is not a valid type to set in NSUserDefaults", domain);
        return;
    }

    @synchronized (_volatileDomains) {
        NSMutableDictionary<NSString *, id> *existing = _volatileDomains[domainName];
        if (existing == nil) {
            existing = [[[NSMutableDictionary alloc] init] autorelease];
        }
        for (NSString *key in [domain allKeys]) {
            existing[key] = domain[key];
        }
        _volatileDomains[domainName] = existing;
    }
}

- (void) removeVolatileDomainForName: (NSString *) domainName {
    @synchronized (_volatileDomains) {
        [_volatileDomains removeObjectForKey: domainName];
    }
}

- (NSArray *) persistentDomainNames {
    CFStringRef userName = (CFStringRef) NSUserName();
    NSArray *domains = (NSArray *) _CFPreferencesCreateDomainList(userName, kCFPreferencesAnyHost);
    return [domains autorelease];
}

- (NSDictionary *) persistentDomainForName: (NSString *) domainName {
    CFStringRef userName = (CFStringRef) NSUserName();
    CFPreferencesDomainRef domain = _CFPreferencesStandardDomain((CFStringRef) domainName, userName, kCFPreferencesAnyHost);
    NSDictionary *res = (NSDictionary *) _CFPreferencesDomainDeepCopyDictionary(domain);
    return [res autorelease];
}

- (void) setPersistentDomain: (NSDictionary *) domain forName: (NSString *) domainName {
    // Create a different defaults object.
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName: domainName];

    for (id key in [[defaults dictionaryRepresentation] allKeys]) {
        [defaults removeObjectForKey: key];
    }

    [defaults registerDefaults: domain];
    [defaults synchronize];

    // Post a notification on self.
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUserDefaultsDidChangeNotification object:self userInfo:nil];
}

- (void) removePersistentDomainForName: (NSString *) domainName
{
    NSDictionary *defaultsDictionary = [self dictionaryRepresentation];
    for (NSString *key in [defaultsDictionary allKeys]) {
        [self removeObjectForKey:key];
    }
    [self synchronize];
}

- (void) addSuiteNamed: (NSString *) suiteName {
    CFPreferencesAddSuitePreferencesToApp(kCFPreferencesCurrentApplication, (CFStringRef) suiteName);
}

- (void) removeSuiteNamed: (NSString *) suiteName {
    CFPreferencesRemoveSuitePreferencesFromApp(kCFPreferencesCurrentApplication, (CFStringRef) suiteName);
}

@end


@implementation NSUserDefaults(NSKeyValueCoding)

- (id)valueForKey:(NSString *)key
{
#warning TODO https://code.google.com/p/apportable/issues/detail?id=253
    return [self objectForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    if (value == nil)
    {
        [self removeObjectForKey:key];
    }
    else
    {
        [self setObject:value forKey:key];
    }
}

@end
