// SPDX-License-Identifier: GPL-3.0-or-later
/* Runs NSAppleEventManager from src/NSAppleEventManager.m against a minimal mock root class, NSMethodSignature and
 * NSInvocation, and sends it selectors it does not implement the way darling-corefoundation's ____forwarding___
 * (NSForwarding.m) does: ask -methodSignatureForSelector:, build an invocation, call -forwardInvocation:, then copy
 * the invocation's return value (methodReturnLength bytes) into the return storage the caller's register is loaded
 * from. That storage starts out as stale stack, so it is garbage here; the invocation's own return buffer is zeroed
 * like the real one's. A forwarded stub must hand the caller nil/0, which needs a signature with a non-empty return
 * (a void signature copies nothing, so the stale storage would reach the caller).
 * tests/appleeventmanager-forward-host.sh extracts the header and implementation at build time. */
#include <objc/runtime.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned long NSUInteger;
typedef int AEEventClass;
typedef int AEEventID;
typedef short OSErr;
typedef uint32_t UInt32;
typedef struct AEDesc { int descriptorType; void *dataHandle; } AppleEvent;

__attribute__((objc_root_class))
@interface NSObject {
    Class isa;
}
+ (id)alloc;
- (id)init;
- (Class)class;
@end
@implementation NSObject
+ (id)alloc { return class_createInstance(self, 0); }
- (id)init { return self; }
- (Class)class { return object_getClass(self); }
@end

@interface NSString : NSObject @end
@implementation NSString @end
@interface NSAppleEventDescriptor : NSObject @end
@implementation NSAppleEventDescriptor @end

static int logged;
static void NSLog(NSString *format, ...) { (void)format; logged++; }
static NSString *NSStringFromSelector(SEL sel) { (void)sel; return nil; }

#define STALE 0xA5

@interface NSMethodSignature : NSObject {
    const char *_types;
}
+ (NSMethodSignature *)signatureWithObjCTypes:(const char *)types;
- (NSUInteger)methodReturnLength;
@end
@implementation NSMethodSignature
+ (NSMethodSignature *)signatureWithObjCTypes:(const char *)types
{
    NSMethodSignature *sig = [self alloc];
    sig->_types = types;
    return sig;
}
- (NSUInteger)methodReturnLength
{
    switch (_types[0]) {
    case 'v': return 0;
    case 'c': case 'C': case 'B': return 1;
    case 's': case 'S': return 2;
    case 'i': case 'I': return 4;
    default: return sizeof(void *);
    }
}
@end

@interface NSInvocation : NSObject {
@public
    NSMethodSignature *_signature;
    SEL _selector;
    unsigned char *_return;
}
- (NSMethodSignature *)methodSignature;
- (SEL)selector;
- (void)setReturnValue:(void *)value;
- (void)getReturnValue:(void *)value;
@end
@implementation NSInvocation
- (NSMethodSignature *)methodSignature { return _signature; }
- (SEL)selector { return _selector; }
- (void)setReturnValue:(void *)value { memcpy(_return, value, [_signature methodReturnLength]); }
- (void)getReturnValue:(void *)value { memcpy(value, _return, [_signature methodReturnLength]); }
@end

#include HEADER_INC
#include IMPLEMENTATION_INC

// The forwarding path for a message the receiver does not implement; returns what the caller's register holds.
static uint64_t forward(id target, SEL sel)
{
    unsigned char storage[16];
    memset(storage, STALE, sizeof(storage));
    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    NSInvocation *inv = [NSInvocation alloc];
    inv->_signature = sig;
    inv->_selector = sel;
    inv->_return = calloc(1, 16); // like the real -initWithMethodSignature: (callocs _retdata): zeroed, not stale
    [target forwardInvocation:inv];
    [inv getReturnValue:storage];
    uint64_t reg;
    memcpy(&reg, storage, sizeof(reg));
    return reg;
}

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

int main(void)
{
    NSAppleEventManager *manager = [NSAppleEventManager sharedAppleEventManager];
    CK(manager != nil, "sharedAppleEventManager returns an object");

    // Declared in NSAppleEventManager.h, not implemented: returns OSErr.
    SEL dispatchRaw = sel_registerName("dispatchRawAppleEvent:withRawReply:handlerRefCon:");
    CK(!class_respondsToSelector(objc_getClass("NSAppleEventManager"), dispatchRaw),
       "dispatchRawAppleEvent:withRawReply:handlerRefCon: is still forwarded; pick another unimplemented selector");
    uint64_t reg = forward(manager, dispatchRaw);
    CK((OSErr)reg == 0, "forwarded dispatchRawAppleEvent:... returns OSErr 0 (got %d)", (OSErr)reg);
    CK(reg == 0, "forwarded dispatchRawAppleEvent:... leaves no stale bytes in the return register (got %#llx)",
       (unsigned long long)reg);

    // A selector this class has never heard of, read as an object (what crashed in objc_msgSend before).
    SEL unknown = sel_registerName("appleEventManagerSelectorNotImplementedHere");
    reg = forward(manager, unknown);
    CK((id)(uintptr_t)reg == nil, "forwarded object-returning selector returns nil (got %#llx)", (unsigned long long)reg);

    CK(logged == 2, "every forwarded call is still logged (%d of 2)", logged);

    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
