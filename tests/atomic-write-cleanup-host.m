// SPDX-License-Identifier: GPL-3.0-or-later
/* Runs _NSWriteBytesToFile() from src/_NSFileIO.m against mock NSString/NSData/NSError classes, checking that a
 * failed atomic write removes its .tmpN file and returns the descriptor. tests/atomic-write-cleanup-host.sh
 * extracts the function at build time. */
#include <dirent.h>
#include <errno.h>
#include <stdint.h>
#include <sys/types.h>
#include <fcntl.h>
#include <objc/runtime.h>
#include <signal.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <unistd.h>

typedef long NSInteger;
typedef unsigned long NSUInteger;
/* BOOL, nil, YES and NO come from <objc/runtime.h> (libobjc2). */
id class_createInstance(Class, unsigned long);
#define NSDataWritingAtomic (1UL << 0)
#define NSDataWritingWithoutOverwriting (1UL << 1)
typedef NSUInteger NSDataWritingOptions;
#define OSAtomicIncrement32(p) (++*(p))

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self, 0); }
@end

@interface NSString : NSObject { const char *chars; }
+ (id)stringWithUTF8String:(const char *)s;
+ (id)stringWithFormat:(NSString *)format, ...;
- (BOOL)isNSString__;
- (const char *)UTF8String;
- (NSString *)path;
- (NSString *)stringByAppendingFormat:(NSString *)format, ...;
@end
@implementation NSString
+ (id)stringWithUTF8String:(const char *)s { NSString *r = [self alloc]; r->chars = strdup(s); return r; }
+ (id)stringWithFormat:(NSString *)format, ... {
    va_list ap; char *out; va_start(ap, format); vasprintf(&out, format->chars, ap); va_end(ap);
    return [self stringWithUTF8String:out];
}
- (BOOL)isNSString__ { return YES; }
- (NSString *)path { return self; }
- (const char *)UTF8String { return chars; }
- (NSString *)stringByAppendingFormat:(NSString *)format, ... {
    va_list ap; char *tail, *out; va_start(ap, format); vasprintf(&tail, format->chars, ap); va_end(ap);
    asprintf(&out, "%s%s", chars, tail);
    return [NSString stringWithUTF8String:out];
}
@end
@interface NSConstantString : NSString { const char *_chars; unsigned int _length; }
@end
@implementation NSConstantString
- (const char *)UTF8String { return _chars; }
@end

@interface NSData : NSObject { const void *b; NSUInteger n; }
+ (id)dataWithBytes:(const void *)bytes length:(NSUInteger)length;
- (const void *)bytes;
- (NSUInteger)length;
@end
@implementation NSData
+ (id)dataWithBytes:(const void *)bytes length:(NSUInteger)length { NSData *d = [self alloc]; d->b = bytes; d->n = length; return d; }
- (const void *)bytes { return b; }
- (NSUInteger)length { return n; }
@end

@interface NSDictionary : NSObject
+ (id)dictionaryWithObjects:(const id *)objects forKeys:(const id *)keys count:(NSUInteger)count;
@end
@implementation NSDictionary
+ (id)dictionaryWithObjects:(const id *)objects forKeys:(const id *)keys count:(NSUInteger)count { return [self alloc]; }
@end

@interface NSError : NSObject { NSInteger c; }
+ (id)errorWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)info;
- (NSInteger)code;
@end
@implementation NSError
+ (id)errorWithDomain:(NSString *)domain code:(NSInteger)code userInfo:(NSDictionary *)info { NSError *e = [self alloc]; e->c = code; return e; }
- (NSInteger)code { return c; }
@end

NSString *const NSPOSIXErrorDomain = nil;
NSString *const NSCocoaErrorDomain = nil;
NSString *const NSLocalizedDescriptionKey = nil;

#include METHODS_INC

static int failures = 0;
static void expect(int ok, const char *what) { if (!ok) { fprintf(stderr, "FAIL: %s\n", what); failures++; } }

static int countTmp(const char *dir) {
    int count = 0;
    DIR *d = opendir(dir);
    for (struct dirent *e; (e = readdir(d));) if (strstr(e->d_name, ".tmp")) count++;
    closedir(d);
    return count;
}

static int openFds(void) {
    int count = 0;
    DIR *d = opendir("/proc/self/fd");
    while (readdir(d)) count++;
    closedir(d);
    return count;
}

int main(void) {
    char dir[] = "/tmp/atomic-write-XXXXXX";
    mkdtemp(dir);
    char text[64];
    NSData *data = [NSData dataWithBytes:"hello world, a hundred bytes" length:28];
    NSError *error = nil;

    // rename fails: the destination is a directory
    snprintf(text, sizeof text, "%s/dest", dir);
    mkdir(text, 0755);
    BOOL ok = _NSWriteBytesToFile(data, [NSString stringWithUTF8String:text], NSDataWritingAtomic, &error);
    expect(!ok && error != nil, "rename onto a directory fails with an error");
    expect(countTmp(dir) == 0, "failed rename leaves no .tmpN file");

    // write fails: the file size limit is smaller than the data
    int fdsBefore = openFds();
    signal(SIGXFSZ, SIG_IGN);
    struct rlimit old;
    getrlimit(RLIMIT_FSIZE, &old);
    struct rlimit limit = { 4, old.rlim_max };  // soft limit only: a hard limit cannot be raised again without root
    if (setrlimit(RLIMIT_FSIZE, &limit) != 0) { perror("setrlimit"); return 2; }
    snprintf(text, sizeof text, "%s/file", dir);
    error = nil;
    ok = _NSWriteBytesToFile(data, [NSString stringWithUTF8String:text], NSDataWritingAtomic, &error);
    if (setrlimit(RLIMIT_FSIZE, &old) != 0) { perror("restore RLIMIT_FSIZE"); return 2; }
    expect(!ok && error != nil, "write beyond the size limit fails with an error");
    expect(countTmp(dir) == 0, "failed write leaves no .tmpN file");
    expect(openFds() == fdsBefore, "failed write closes its descriptor");

    // success still replaces the destination and leaves no .tmpN
    error = nil;
    ok = _NSWriteBytesToFile(data, [NSString stringWithUTF8String:text], NSDataWritingAtomic, &error);
    expect(ok && error == nil, "atomic write succeeds");
    expect(countTmp(dir) == 0, "successful write leaves no .tmpN file");
    struct stat st;
    expect(stat(text, &st) == 0 && st.st_size == 28, "destination holds the data");

    char cmd[128];
    snprintf(cmd, sizeof cmd, "rm -r %s", dir);
    system(cmd);
    if (failures) return 1;
    puts("PASS");
    return 0;
}
