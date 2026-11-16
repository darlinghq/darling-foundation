// Copyright (C) 2026 Lubos Dolezel
// Receiver half of nsxpc-cross-arch.sh; built for the architecture opposite to the client's (x86_64 for an i386 client).
#import "nsxpc-cross-arch.h"

@interface XArchImpl : NSObject <XArchService, NSXPCListenerDelegate> {
    NSMutableArray *_notes;
}
@end

@implementation XArchImpl
- (instancetype)init {
    if ((self = [super init])) _notes = [NSMutableArray new];
    return self;
}
- (BOOL)listener:(NSXPCListener *)l shouldAcceptNewConnection:(NSXPCConnection *)c {
    c.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(XArchService)];
    c.exportedObject = self;
    [c resume];
    return YES;
}
- (void)addInt:(int)a long:(long)l unsigned:(NSUInteger)u reply:(void (^)(long long))reply {
    reply((long long)a + l + (long long)u);
}
- (void)echoString:(NSString *)s array:(NSArray *)a reply:(void (^)(NSString *, NSArray *))reply {
    reply([s uppercaseString], [a arrayByAddingObject:@"added by receiver"]);
}
- (void)reverseRange:(NSRange)r signed:(NSInteger)i flag:(BOOL)f reply:(void (^)(NSRange, NSInteger, BOOL))reply {
    reply(NSMakeRange(r.length, r.location), -i, !f);
}
- (void)noteString:(NSString *)s number:(NSNumber *)n {
    @synchronized (self) { [_notes addObject:[NSString stringWithFormat:@"%@:%@", s, n]]; }
}
- (void)fetchNotesWithReply:(void (^)(NSArray *))reply {
    NSArray *copy;
    @synchronized (self) { copy = [_notes copy]; }
    reply(copy);
}
@end

int main(void) {
    @autoreleasepool {
        XArchImpl *impl = [XArchImpl new];
        NSXPCListener *l = [[NSXPCListener alloc] initWithMachServiceName:XARCH_SERVICE_NAME];
        l.delegate = impl;
        [l resume];
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
