//
//  NSPort.m
//  Foundation
//
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import <Foundation/NSPort.h>
#import <Foundation/NSException.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSNotification.h>
#import "NSObjectInternal.h"
#import <CoreFoundation/CFRunLoop.h>
#import <CoreFoundation/CFMachPort.h>
#import <mach/mach_port.h>
#import <mach/vm_map.h>
#import <mach/mach_init.h>
#import <libkern/OSAtomic.h>

extern CFMachPortContext *_CFMachPortGetContext(CFMachPortRef mp);

@interface NSMachPort ()
- (BOOL)sendBeforeTime:(NSTimeInterval)time streamData:(void *)data components:(NSMutableArray *)components from:(NSPort *)receivePort msgid:(NSUInteger)msgID;
+ (BOOL)sendBeforeTime:(NSTimeInterval)time streamData:(void *)data components:(NSMutableArray *)components to:(NSPort*) sendPort from:(NSPort *)receivePort msgid:(NSUInteger)msgID;
@end

NSString *const NSPortDidBecomeInvalidNotification = @"NSPortDidBecomeInvalidNotification";

@implementation NSPort

+ (id)allocWithZone:(NSZone *)zone
{
    if (self == [NSPort class])
    {
        return [NSMachPort allocWithZone:zone];
    }
    else
    {
        return [super allocWithZone:zone];
    }
}

+ (NSPort *)port
{
    return [[[NSPort alloc] init] autorelease];
}

+ (id)portWithMachPort:(uint32_t)port
{
    return [[[self alloc] initWithMachPort:port] autorelease];
}

- (id)initWithMachPort:(uint32_t)port
 {
    NSRequestConcreteImplementation();
    [self release];
    return nil;
 }

- (void)invalidate
{
    NSRequestConcreteImplementation();
}

- (BOOL)isValid
{
    NSRequestConcreteImplementation();
    return NO;
}

- (void)setDelegate:(id <NSPortDelegate>)anObject
{
    NSRequestConcreteImplementation();
}

- (id <NSPortDelegate>)delegate
{
    NSRequestConcreteImplementation();
    return nil;
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode
{
    NSRequestConcreteImplementation();
}

- (void)removeFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode
{
    NSRequestConcreteImplementation();
}

- (NSUInteger)reservedSpaceLength
{
    return 0;
}

- (BOOL)sendBeforeDate:(NSDate *)limitDate components:(NSMutableArray *)components from:(NSPort *)receivePort reserved:(NSUInteger)headerSpaceReserved
{
    NSRequestConcreteImplementation();
    return NO;
}

- (BOOL)sendBeforeDate:(NSDate *)limitDate msgid:(NSUInteger)msgID components:(NSMutableArray *)components from:(NSPort *)receivePort reserved:(NSUInteger)headerSpaceReserved
{
    NSRequestConcreteImplementation();
    return NO;
}

- (Class)classForCoder
{
    [NSException raise:NSInvalidArgumentException format:@"Cannot encode NSPorts"];
    return Nil;
}

@end


@implementation NSMachPort

+ (NSPort *)portWithMachPort:(uint32_t)machPort
{
    return [[[self alloc] initWithMachPort:machPort] autorelease];
}

+ (NSPort *)portWithMachPort:(uint32_t)machPort options:(NSUInteger)f
{
    return [[[self alloc] initWithMachPort:machPort options:f] autorelease];
}

- (id)init
{
    mach_port_name_t port;
    if (mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port) != KERN_SUCCESS) {
        // Cannot call [self release], as self is not TFBed at this point.
        [super release];
        return nil;
    }
    return [self initWithMachPort:port options:0];
}

- (id)initWithMachPort:(uint32_t)machPort
{
    return [self initWithMachPort:machPort options:0];
}

- (void)setDelegate:(id <NSMachPortDelegate>)anObject
{
    if ([self class] != [NSMachPort class])
    {
        _delegate = anObject;
    }
    else if (CFMachPortIsValid((CFMachPortRef)self))
    {
        CFMachPortContext ctx;
        CFMachPortGetContext((CFMachPortRef)self, &ctx);
        *(id *)ctx.info = anObject;
    }
}

- (id <NSMachPortDelegate>)delegate
{
    if ([self class] != [NSMachPort class])
    {
        return _delegate;
    }
    else if (CFMachPortIsValid((CFMachPortRef)self))
    {
        CFMachPortContext ctx;
        CFMachPortGetContext((CFMachPortRef)self, &ctx);
        return *(id *)ctx.info;
    }
    return nil;
}

static void mach_port_callback(CFMachPortRef port, void *msg, CFIndex size, void *info)
{
    id<NSMachPortDelegate> delegate = *(id<NSMachPortDelegate> *) info;

    if ([delegate respondsToSelector: @selector(handleMachMessage:)])
    {
        [delegate handleMachMessage: msg];
        return;
    }
    if (![delegate respondsToSelector: @selector(handlePortMessage:)])
    {
        return;
    }

    struct {
	mach_msg_header_t header;
        mach_msg_body_t body;
        // mach_msg_descriptor_t descriptors[];
    } *message = msg;

    NSMachPort *receivePort = [NSMachPort portWithMachPort: message->header.msgh_local_port];
    NSMachPort *sendPort = [NSMachPort portWithMachPort: message->header.msgh_remote_port];
    uint32_t msgid = message->header.msgh_id;

    NSUInteger count = message->body.msgh_descriptor_count;
    NSMutableArray *components = [NSMutableArray arrayWithCapacity: count];

    char *descriptor = (char *) (message + 1);
    for (NSUInteger i = 0; i < count; i++) {
        mach_msg_type_descriptor_t *type_descriptor = (mach_msg_type_descriptor_t *) descriptor;
        if (type_descriptor->type == MACH_MSG_PORT_DESCRIPTOR) {
            mach_msg_port_descriptor_t *port_descriptor = (mach_msg_port_descriptor_t *) descriptor;
            NSMachPort *port = [NSMachPort portWithMachPort: port_descriptor->name];
            [components addObject: port];
            descriptor += sizeof(mach_msg_port_descriptor_t);
        } else if (type_descriptor->type == MACH_MSG_OOL_DESCRIPTOR) {
            mach_msg_ool_descriptor_t *ool_descriptor = (mach_msg_ool_descriptor_t *) descriptor;
            NSData *data = [[NSData alloc] initWithBytes: ool_descriptor->address
                                                  length: ool_descriptor->size
                                                    copy: NO
                                            freeWhenDone: YES
                                              bytesAreVM: YES];
            [components addObject: data];
            [data release];
            descriptor += sizeof(mach_msg_ool_descriptor_t);
        } else {
            NSLog(@"NSMachPort: cannot decode an object");
            descriptor += sizeof(mach_msg_descriptor_t);
        }
    }

    NSPortMessage *portMessage = [[NSPortMessage alloc] initWithSendPort: sendPort
                                                             receivePort: receivePort
                                                              components: components];
    [portMessage setMsgid: msgid];
    [delegate handlePortMessage: portMessage];
    [portMessage release];
}

- (id)initWithMachPort:(uint32_t)machPort options:(NSUInteger)options
{
    if ([self class] != [NSMachPort class]) {
        self = [super init];
        if (self)
        {
            _machPort = machPort;
            _flags = options;
        }

    } else {
        [self dealloc];
        id *delegateRef = (id *)calloc(sizeof(id), 1);
        CFMachPortContext context = {
            0,
            delegateRef,
            NULL,
            (void (*)(const void *))&free,
            NULL
        };
        Boolean shouldFreeInfo = false;
        self = (NSMachPort*)CFMachPortCreateWithPort(kCFAllocatorDefault, machPort, &mach_port_callback, &context, &shouldFreeInfo);
        if (shouldFreeInfo)
        {
            free(context.info);
        }
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (uint32_t)machPort
{
    if ([self class] != [NSMachPort class])
    {
        return _machPort;
    }
    else
    {
        return CFMachPortGetPort((CFMachPortRef)self);
    }
}

- (void)scheduleInRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode
{
    if ([self class] != [NSMachPort class])
    {
        NSRequestConcreteImplementation();
    }
    else
    {
        CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, (CFMachPortRef)self, 0);
        CFRunLoopAddSource([runLoop getCFRunLoop], source, (CFStringRef)mode);
        CFRelease(source);
    }
}

- (void)removeFromRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode
{
    if ([self class] != [NSMachPort class])
    {
        NSRequestConcreteImplementation();
    }
    else
    {
        CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, (CFMachPortRef)self, 0);
        CFRunLoopRemoveSource([runLoop getCFRunLoop], source, (CFStringRef)mode);
        CFRelease(source);
    }
}

- (void)invalidate
{
    BOOL invalidated = NO;
    if ([self class] != [NSMachPort class])
    {
        if (_machPort != 0)
        {
            [self setDelegate:nil];
            mach_port_deallocate(mach_task_self(), _machPort);
            _machPort = 0;
            invalidated = YES;
        }
    }
    else
    {
        if (CFMachPortIsValid((CFMachPortRef)self))
        {
            uint32_t mach_port = CFMachPortGetPort((CFMachPortRef)self);
            CFMachPortInvalidate((CFMachPortRef)self);
            mach_port_deallocate(0, mach_port);
            invalidated = YES;
        }
    }
    if (invalidated)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:NSPortDidBecomeInvalidNotification object:self userInfo:nil];
    }
}

- (BOOL)isValid
{
    if ([self class] != [NSMachPort class])
    {
        return _machPort != 0;
    }
    else
    {
        return CFMachPortIsValid((CFMachPortRef)self);
    }
}

- (BOOL)sendBeforeDate:(NSDate *)limitDate components:(NSMutableArray *)components from:(NSPort *)receivePort reserved:(NSUInteger)headerSpaceReserved
{
    return [self sendBeforeTime:[limitDate timeIntervalSinceNow] streamData:NULL components:components from:receivePort msgid:0];
}

- (BOOL)sendBeforeDate:(NSDate *)limitDate msgid:(NSUInteger)msgID components:(NSMutableArray *)components from:(NSPort *)receivePort reserved:(NSUInteger)headerSpaceReserved
{
    return [self sendBeforeTime:[limitDate timeIntervalSinceNow] streamData:NULL components:components from:receivePort msgid:msgID];
}

- (BOOL) sendBeforeTime: (NSTimeInterval) time
             streamData: (void *) data
             components: (NSMutableArray *) components
                   from: (NSPort *) receivePort
                  msgid: (NSUInteger) msgID {

    return [NSMachPort sendBeforeTime: time
                           streamData: data
                           components: components
                                   to: self
                                 from: receivePort
                                msgid: msgID];
}

+ (BOOL) sendBeforeTime: (NSTimeInterval) time
             streamData: (void *) data
             components: (NSMutableArray *) components
                     to: (NSPort*) sendPort
                   from: (NSPort *) receivePort
                  msgid: (NSUInteger) msgID {

    NSUInteger count = [components count];

    struct {
        mach_msg_header_t header;
        mach_msg_body_t body;
        // mach_msg_descriptor_t descriptors[];
    } *message;
    size_t size = sizeof(*message) + count * sizeof(mach_msg_descriptor_t);
    message = calloc(1, size);

    mach_msg_type_name_t reply_type_name = (receivePort != MACH_PORT_NULL) ? MACH_MSG_TYPE_MAKE_SEND_ONCE : 0;
    message->header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, reply_type_name) | MACH_MSGH_BITS_COMPLEX;
    message->header.msgh_remote_port = [sendPort machPort];
    message->header.msgh_local_port = [receivePort machPort];
    message->header.msgh_id = msgID;

    message->body.msgh_descriptor_count = count;
    char *descriptor = (char *) (message + 1);
    for (NSUInteger i = 0; i < count; i++) {
        id component = [components objectAtIndex: i];
        if ([component respondsToSelector: @selector(machPort)]) {
            NSMachPort *port = (NSMachPort *) component;
            mach_msg_port_descriptor_t *port_descriptor = (mach_msg_port_descriptor_t *) descriptor;
            port_descriptor->name = [port machPort];
            port_descriptor->disposition = MACH_MSG_TYPE_MAKE_SEND; // ???
            port_descriptor->type = MACH_MSG_PORT_DESCRIPTOR;
            descriptor += sizeof(mach_msg_port_descriptor_t);
        } else if ([component respondsToSelector: @selector(bytes)]) {
            NSData *data = (NSData *) component;
            mach_msg_ool_descriptor_t *ool_descriptor = (mach_msg_ool_descriptor_t *) descriptor;
            ool_descriptor->address = [data bytes];
            ool_descriptor->size = [data length];
            ool_descriptor->deallocate = 0;
            ool_descriptor->copy = MACH_MSG_PHYSICAL_COPY;
            ool_descriptor->type = MACH_MSG_OOL_DESCRIPTOR;
            descriptor += sizeof(mach_msg_ool_descriptor_t);
        } else {
            NSLog(@"[NSMachPort sendBeforeDate:] cannot encode an object of type %@", [component class]);
        }
    }

    kern_return_t kr = mach_msg(&message->header, MACH_SEND_MSG|MACH_SEND_TIMEOUT, size, 0, MACH_PORT_NULL, time * 1000, MACH_PORT_NULL);
    free(message);

    switch (kr) {
        case MACH_MSG_SUCCESS:
             return YES;
        case MACH_SEND_INVALID_DEST:
            [NSException raise: NSInvalidSendPortException format: @"[NSMachPort sendBeforeDate:] invalid send port"];
            return NO;
        case MACH_SEND_INVALID_REPLY:
            [NSException raise: NSInvalidReceivePortException format: @"[NSMachPort sendBeforeDate:] invalid reply port"];
            return NO;
        default:
            [NSException raise: NSPortSendException format: @"[NSMachPort sendBeforeDate:] mach_msg() returned %x", kr];
            return NO;
    }
}

// - (BOOL)isMemberOfClass:(Class)cls;
// - (BOOL)isKindOfClass:(Class)cls;

- (NSUInteger)retainCount
{
    if ([self class] != [NSMachPort class])
    {
        return _reserved + 1;
    }
    else
    {
        return CFGetRetainCount((CFTypeRef)self);
    }
}

- (BOOL)_tryRetain
{
    return NO;
}

- (BOOL)_isDeallocating
{
    return YES;
}

- (oneway void)release
{
    if ([self class] != [NSMachPort class])
    {
        if (OSAtomicDecrement32(&_reserved) == -1)
        {
            [self invalidate]; // this is here just in-case the dealloc is somehow called on a base class instance
            [self dealloc];
        }
    }
    else
    {
        CFRelease((CFTypeRef)self);
    }
}

- (id)retain
{
    if ([self class] != [NSMachPort class])
    {
        OSAtomicIncrement32(&_reserved);
        return self;
    }
    else
    {
        return (id)CFRetain((CFTypeRef)self);
    }
}

- (NSUInteger)hash
{
    if ([self class] != [NSMachPort class])
    {
        return (NSUInteger)_machPort;
    }
    else
    {
        return (NSUInteger)CFHash((CFTypeRef)self);
    }
}

- (BOOL)isEqual:(id)other
{
    if ([other isKindOfClass:[NSMachPort class]])
    {
        return [(NSMachPort *)other machPort] == [self machPort];
    }
    return NO;
}

- (unsigned long)_cfTypeID
{
    return CFMachPortGetTypeID();
}

@end


@implementation NSMessagePort

@end
