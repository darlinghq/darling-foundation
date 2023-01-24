//
//  NSProcessInfo.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//  Copyright (c) 2018 Lubos Dolezel
//

#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSUUID.h>
#import <CoreFoundation/CFPriv.h>
#import "NSConnectionInternal.h"
#import "NSObjectInternal.h"
#import <dispatch/dispatch.h>
#import <crt_externs.h>
#import <sys/param.h>
#import <unistd.h>
#import <sys/utsname.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <mach/mach_time.h>
#import <stdio.h>
#import <stdlib.h>
#import <objc/objc-internal.h>

extern char ***_NSGetEnviron();

/*
 TODO: this probably should be more thread safe since some of the underpinnings may not necessarily be
 guaranteed to be stable across all threads; ala setenv etc.
 */

@implementation NSProcessInfo

+ (NSProcessInfo *)processInfo
{
    static NSProcessInfo *processInfo = nil;
    static dispatch_once_t once = 0L;
    dispatch_once(&once, ^{
        processInfo = [[NSProcessInfo alloc] init];
    });
    return processInfo;
}

SINGLETON_RR()

- (NSDictionary *)environment
{
    NSDictionary *e = nil;
    char **env = *_NSGetEnviron();
    NSMutableArray *keys = [[NSMutableArray alloc] init];
    NSMutableArray *values = [[NSMutableArray alloc] init];
    while (*env != NULL)
    {
        char *v = strchr(*env, '=');
        if (v == NULL)
        {
            env++;
            continue;
        }
        
        char *k = NULL;
        if (v != NULL)
        {
            size_t len = v - *env;
            k = strndup(*env, len);
            if (k == NULL)
            {
                env++;
                continue;
            }
            
            v++;
            NSString *key = [[NSString alloc] initWithUTF8String:k];
            NSString *value = [[NSString alloc] initWithUTF8String:v];
            [keys addObject:key];
            [key release];
            [values addObject:value];
            [value release];
            free(k);
        }
        env++;
    }
    e = [[NSDictionary alloc] initWithObjects:values forKeys:keys];
    [values release];
    [keys release];
    return [e autorelease];
}

- (NSArray *)arguments
{
    if (arguments == nil)
    {
        arguments = [[NSMutableArray alloc] init];
        char **argv = *_NSGetArgv();
        while (*argv != NULL)
        {
            NSString *argument = [[NSString alloc] initWithUTF8String:*argv];
            [(NSMutableArray *)arguments addObject:argument];
            [argument release];
            argv++;
        }
    }
    return [[arguments copy] autorelease];
}

- (NSString *)hostName
{
    if (hostName == nil)
    {
        char hname[MAXHOSTNAMELEN];
        if (gethostname(hname, MAXHOSTNAMELEN) == 0)
        {
            hostName = [[NSString alloc] initWithUTF8String:hname];
        }
        else
        {
            hostName = @"localhost";
        }
    }
    return hostName;
}

- (NSString *)processName
{
    if ([[self arguments] count] > 0)
    {
        name = [[[[self arguments] objectAtIndex:0] lastPathComponent] copy];
    }
    else
    {
        name = @"";
    }
    return name;
}

- (int)processIdentifier
{
    return getpid();
}

- (void)setProcessName:(NSString *)newName
{
    if (![name isEqualToString:newName])
    {
        [name release];
        name = [newName copy];
    }
}

- (NSString *)globallyUniqueString
{
    NSString *unique = nil;
    char buffer[128];
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef str = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    if (CFStringGetCString(str, buffer, 128, kCFStringEncodingASCII))
    {
        size_t buffer_len = strlen(buffer);
        snprintf(buffer + buffer_len, 128 - buffer_len, "-%ld-%016llX", (long)getpid(), mach_absolute_time());
        unique = [NSString stringWithUTF8String:buffer];
    }
    CFRelease(str);
    CFRelease(uuid);
    return unique;
}

- (NSUInteger)operatingSystem
{
    struct utsname n;
    NSUInteger os = 0;
    if (uname(&n) == 0)
    {
#define HAS_PREFIX(s, p) ({ \
    size_t s_len = strlen(s); \
    size_t p_len = strlen(p); \
    (s_len >= p_len) && strncmp(s, p, p_len) == 0; \
})
        if (HAS_PREFIX(n.sysname, "darwin"))
        {
            os = NSMACHOperatingSystem;
        }
        else if (HAS_PREFIX(n.sysname, "android"))
        {
            os = NSAndroidOperatingSystem;
        }
        else if (HAS_PREFIX(n.sysname, "mingw"))
        {
            os = NSWindowsNTOperatingSystem;
        }
        else if (HAS_PREFIX(n.sysname, "solaris"))
        {
            os = NSSolarisOperatingSystem;
        }
        else if (HAS_PREFIX(n.sysname, "hpux"))
        {
            os = NSHPUXOperatingSystem;
        }
        else if (HAS_PREFIX(n.sysname, "osf"))
        {
            os = NSOSF1OperatingSystem;
        }
        else if (HAS_PREFIX(n.sysname, "sunos"))
        {
            os = NSSunOSOperatingSystem;
        }
    }
    return os;
}

- (NSString *)operatingSystemName
{
    switch ([self operatingSystem])
    {
        case NSWindowsNTOperatingSystem:
            return @"NSWindowsNTOperatingSystem";
        case NSWindows95OperatingSystem:
            return @"NSWindows95OperatingSystem";
        case NSSolarisOperatingSystem:
            return @"NSSolarisOperatingSystem";
        case NSHPUXOperatingSystem:
            return @"NSHPUXOperatingSystem";
        case NSMACHOperatingSystem:
            return @"NSMACHOperatingSystem";
        case NSSunOSOperatingSystem:
            return @"NSSunOSOperatingSystem";
        case NSOSF1OperatingSystem:
            return @"NSOSF1OperatingSystem";
        case NSAndroidOperatingSystem:
            return @"NSAndroidOperatingSystem";
        default:
            return @"Unknown";
    }
}

- (NSString *)operatingSystemVersionString
{
#ifndef __APPLE__
    struct utsname n;
    if (uname(&n) == 0)
    {
        return [NSString stringWithUTF8String:n.version];
    }
    else
    {
        return @"Unknown";
    }
#else
	NSDictionary* dict = (NSDictionary*) _CFCopySystemVersionDictionary();
	NSString* string = [dict objectForKey: @"ProductVersion"];

	[string retain];
	[dict release];

	return [string autorelease];
#endif
}

- (NSUInteger)processorCount
{
    int count = 1;
    size_t len = sizeof(int);
    if (sysctlbyname("hw.ncpu", &count, &len, 0, 0) != 0)
    {
        count = 1; // reset it to a reasonable value if it fails...
    }
    return count;
}

- (NSUInteger)activeProcessorCount
{
    int count = 1;
    size_t len = sizeof(int);
    if (sysctlbyname("hw.availcpu", &count, &len, 0, 0) != 0)
    {
        count = 1;
    }
    return count;
    
}

- (unsigned long long)physicalMemory
{
    unsigned long long amt = 1;
    size_t len = sizeof(unsigned long long);
    if (sysctlbyname("hw.physmem", &amt, &len, 0, 0) != 0)
    {
        amt = 1;
    }
    return amt;
}

- (NSTimeInterval)systemUptime
{
    struct timeval t;
    size_t len = sizeof(struct timeval);
    if (sysctlbyname("kern.boottime", &t, &len, 0, 0) != 0)
    {
        return 0.0;
    }
    return t.tv_sec + t.tv_usec / (NSTimeInterval)USEC_PER_SEC;
}

- (NSOperatingSystemVersion)operatingSystemVersion
{
	NSOperatingSystemVersion version = { 0, 0, 0 };

	NSString* string = [self operatingSystemVersionString];
	NSArray* arr = [string componentsSeparatedByString:@"."];

	if ([arr count] >= 1)
	{
		version.majorVersion = [[arr objectAtIndex: 0] integerValue];
		if ([arr count] >= 2)
		{
			version.minorVersion = [[arr objectAtIndex: 1] integerValue];

			if ([arr count] >= 3)
			{
				version.patchVersion = [[arr objectAtIndex: 2] integerValue];
			}
		}
	}

	return version;
}

- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version
{
	NSOperatingSystemVersion curver = [self operatingSystemVersion];
	if (curver.majorVersion < version.majorVersion)
		return FALSE;
	else if (curver.majorVersion > version.majorVersion)
		return TRUE;
	else
	{
		if (curver.minorVersion < version.minorVersion)
			return FALSE;
		else if (curver.minorVersion > version.minorVersion)
			return TRUE;
		else
		{
			if (curver.patchVersion < version.patchVersion)
				return FALSE;
			else
				return TRUE;
		}
	}
}

@end

@implementation NSProcessInfo (NSProcessInfoPlatform)
-(BOOL)isMacCatalystApp {
    return NO;
}

-(BOOL)isiOSAppOnMac {
    return NO;
}

@end

#ifdef DARLING

FOUNDATION_EXPORT
__attribute__((constructor))
void __NSInitializeProcess(int argc,const char *argv[]) {
    // This is a Cocotron addition that they use to save the argc/argv of the
    // current process to be later retrieved using NSProcessInfo. Our
    // Foundation instead uses _NSGetArgc/_NSGetArgv directly, so we don't
    // need to do anything here.

    // Instead, we use this function to otherwise initialize Foundation. In
    // particular, we process the NSObjCMessageLoggingEnabled env variable. See
    // http://www.dribin.org/dave/blog/archives/2006/04/22/tracing_objc/
    // for some more details.

    // Note that the upstream Cocotron calls this function from NSApplicationMain();
    // we patch that out and make this function a constructor instead, because
    // there are apps and programs that don't call NSApplicationMain(), but we
    // still want to initialize Foundation properly for them.

    char *messageLoggingEnabled = getenv("NSObjCMessageLoggingEnabled");
    if (messageLoggingEnabled != NULL && strcmp(messageLoggingEnabled, "YES") == 0) {
        instrumentObjcMessageSends(YES);
    }

    char *doLoggingEnabled = getenv("NSDOLoggingEnabled");
    if (doLoggingEnabled != NULL && strcmp(doLoggingEnabled, "YES") == 0) {
        NSDOLoggingEnabled = YES;
    }
}
#endif
