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
#import <Foundation/NSNotification.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSKeyedArchiver.h>
#import "NSObjectInternal.h"
#import <pthread.h>

NSString * const NSGlobalDomain = @"NSGlobalDomain";
NSString * const NSArgumentDomain = @"NSArgumentDomain";
NSString * const NSRegistrationDomain = @"NSRegistrationDomain";
NSString * const NSUserDefaultsDidChangeNotification = @"NSUserDefaultsDidChangeNotification";

static pthread_mutex_t defaultsLock = PTHREAD_MUTEX_INITIALIZER;
static NSUserDefaults *standardDefaults = nil;
static dispatch_source_t synchronizeTimer;
static dispatch_queue_t synchronizeQueue;
#define SYNC_INTERVAL 30

#define APP_NAME (self->_suiteName != nil ? (CFStringRef) self->_suiteName : kCFPreferencesCurrentApplication)

@implementation NSUserDefaults (NSUserDefaults)

+ (NSUserDefaults *)standardUserDefaults
{
    pthread_mutex_lock(&defaultsLock);
    if (standardDefaults == nil)
    {
        standardDefaults = [[NSUserDefaults alloc] init];
        _startSynchronizeTimer(standardDefaults);
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
    if (synchronizeTimer)
    {
        dispatch_source_cancel(synchronizeTimer);
        synchronizeTimer = nil;
    }
    pthread_mutex_unlock(&defaultsLock);
}

- (id)init
{
    return [self initWithSuiteName: nil];
}

- (id) initWithSuiteName: (NSString *) name {
    _suiteName = [name copy];
    // TODO: parse args
    return self;
}

- (id)initWithUser:(NSString *)user
{
    // Ignore the user; just init a regular defaults instance.
    return [self init];
}

- (void)dealloc
{
    [_suiteName release];
    [super dealloc];
}


void static _startSynchronizeTimer(NSUserDefaults *self)
{
    synchronizeQueue = dispatch_queue_create("com.apportable.synchronize.userdefaults", NULL);

    // create the timer source
    synchronizeTimer = dispatch_source_create(
                       DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                       synchronizeQueue);

    // set interval
    dispatch_source_set_timer(synchronizeTimer,
           dispatch_time(DISPATCH_TIME_NOW, SYNC_INTERVAL * NSEC_PER_SEC), SYNC_INTERVAL * NSEC_PER_SEC, 0);

    dispatch_source_set_event_handler(synchronizeTimer, ^{
        CFPreferencesAppSynchronize(APP_NAME);
    });

    // now that the timer is set up, start it up
    dispatch_resume(synchronizeTimer);
}

- (id)objectForKey:(NSString *)key
{
    __block id value = nil;
    // TODO: args...
    dispatch_sync(synchronizeQueue, ^{
#warning TODO: verify that this does not cause an actual leak https://code.google.com/p/apportable/issues/detail?id=537
        // This likely is a leak however this prevents a crash...
        value = [(id)CFPreferencesCopyAppValue((CFStringRef)key, APP_NAME) retain];
    });
    // TODO: registered
    return [value autorelease];
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
        dispatch_async(synchronizeQueue, ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:NSUserDefaultsDidChangeNotification object:self userInfo:nil];
        });
    });
    [self didChangeValueForKey:key];
}

- (void)registerDefaults:(NSDictionary *)dictionary
{
    [dictionary enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        if ([self objectForKey:key] == nil)
        {
            [self setObject:obj forKey:key];
        }
    }];
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
    return YES;
}

- (NSDictionary *)dictionaryRepresentation
{
    __block NSDictionary *rep = nil;
    // TODO: args, registered
    dispatch_sync(synchronizeQueue, ^{
        rep = (NSDictionary *)CFPreferencesCopyMultiple(
            /* fetch all keys */ nil,
            APP_NAME,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        );
    });
    return [rep autorelease];
}

- (NSArray *) volatileDomainNames {
    // TODO
    return @[];
}

- (NSDictionary *) volatileDomainForName: (NSString *) domainName {
    // TODO
    return nil;
}

// - (void) setVolatileDomain: (NSDictionary *) domain forName: (NSString *) domainName;
// - (void) removeVolatileDomainForName: (NSString *) domainName;

- (NSArray *) persistentDomainNames {
    CFStringRef userName = (CFStringRef) NSUserName();
    NSArray *domains = (NSArray *) _CFPreferencesCreateDomainList(userName, kCFPreferencesAnyHost);
    return [domains autorelease];
}

- (NSDictionary *) persistentDomainForName: (NSString *) domainName {
    CFStringRef userName = (CFStringRef) NSUserName();
    CFPreferencesDomainRef domain = _CFPreferencesStandardDomain(domainName, userName, kCFPreferencesAnyHost);
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
