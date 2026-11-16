// Copyright (C) 2026 Lubos Dolezel
// Shared by nsxpc-cross-arch-service.m and nsxpc-cross-arch-client.m.
#import <Foundation/Foundation.h>

#define XARCH_SERVICE_NAME @"org.darlinghq.test.nsxpc-cross-arch"

// Argument and reply types whose size differs between i386 and x86_64: objects, long, NSInteger, NSUInteger,
// NSRange, and reply blocks.
@protocol XArchService
- (void)addInt:(int)a long:(long)l unsigned:(NSUInteger)u reply:(void (^)(long long sum))reply;
- (void)echoString:(NSString *)s array:(NSArray *)a reply:(void (^)(NSString *s, NSArray *a))reply;
- (void)reverseRange:(NSRange)r signed:(NSInteger)i flag:(BOOL)f reply:(void (^)(NSRange r, NSInteger i, BOOL f))reply;
- (void)noteString:(NSString *)s number:(NSNumber *)n; // one-way
- (void)fetchNotesWithReply:(void (^)(NSArray *notes))reply;
@end
