// SPDX-License-Identifier: GPL-3.0-or-later
/* Runs src/NSNotificationCenter.m (extracted by the .sh) on a mock root class and collections. The weak-reference
 * calls are mocked with objc4's semantics (runtime/NSObject.mm, objc-weak.mm): a weak load is nil once deallocation
 * started, references are zeroed after -dealloc ran, objc_storeWeakOrNil stores nil for allowsWeakReference NO and
 * objc_storeWeak aborts. Apple: since macOS 10.11 an observer need not unregister before it is deallocated, so the
 * center must never message a deallocated one. Deallocated objects are not freed; messages to them are counted. */
#include <objc/runtime.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned long NSUInteger;
typedef long dispatch_once_t;
static void dispatch_once(dispatch_once_t *once, void (^block)(void)) { if (!*once) { *once = 1; block(); } }
void *_Block_copy(const void *block);
#define Block_copy(b) ((__typeof__(b))_Block_copy((const void *)(b)))

// Reference counts and the deallocating/dead state live in a side table: constant strings (@"...") put their
// characters right after isa, so the root class has no ivar besides isa. Objects not in the table are immortal.
enum { MAX_OBJECTS = 256 };
static struct { void *object; int retainCount; int deallocating; } objects[MAX_OBJECTS];
static int deadMessages;

static int slotFor(void *o)
{
    for (int i = 0; i < MAX_OBJECTS; i++) if (objects[i].object == o) return i;
    return -1;
}
static int isDeallocating(id o) { int i = slotFor(o); return i >= 0 && objects[i].deallocating; }

static id weakObjects[64];
static id *weakLocations[64];
static int weakCount;

__attribute__((objc_root_class))
@interface NSObject {
    Class isa;
}
+ (id)alloc;
+ (Class)class;
- (id)init;
- (id)retain;
- (void)release;
- (id)autorelease;
- (id)copy;
- (BOOL)allowsWeakReference;
- (id)performSelector:(SEL)sel withObject:(id)object;
- (void)dealloc;
@end

static id pool[256];
static int pooled;

@implementation NSObject
+ (id)alloc
{
    id o = class_createInstance(self, 0);
    int i = slotFor(NULL);
    if (i < 0) { printf("FAIL: mock object table full\n"); exit(2); }
    objects[i].object = o;
    objects[i].retainCount = 1;
    return o;
}
+ (Class)class { return self; }
- (id)init { return self; }
- (id)retain
{
    int i = slotFor(self);
    if (i >= 0) deadMessages += objects[i].deallocating, objects[i].retainCount++;
    return self;
}
- (void)release
{
    int i = slotFor(self);
    if (i < 0) return;
    if (objects[i].deallocating) { deadMessages++; return; }
    if (--objects[i].retainCount == 0) {
        objects[i].deallocating = 1;
        [self dealloc];
    }
}
- (id)autorelease { pool[pooled++] = self; return self; }
- (id)copy { return [self retain]; }
- (BOOL)allowsWeakReference { return YES; }
- (id)performSelector:(SEL)sel withObject:(id)object
{
    if (isDeallocating(self)) { deadMessages++; return nil; }
    IMP imp = objc_msg_lookup(self, sel);
    return ((id (*)(id, SEL, id))imp)(self, sel, object);
}
// objc_destructInstance: weak references to the object are zeroed after the -dealloc chain has run.
- (void)dealloc
{
    for (int i = 0; i < weakCount; i++)
        if (weakObjects[i] == self) { *weakLocations[i] = nil; weakObjects[i] = nil; weakLocations[i] = NULL; }
}
@end

static void drain(void) { while (pooled > 0) [pool[--pooled] release]; }

static id storeWeak(id *location, id object, int crashIfRejected)
{
    for (int i = 0; i < weakCount; i++)
        if (weakLocations[i] == location) { weakObjects[i] = nil; weakLocations[i] = NULL; }
    if (object != nil && (isDeallocating(object) || ![object allowsWeakReference])) {
        if (crashIfRejected) { printf("FAIL: objc_storeWeak: cannot form weak reference to %p\n", (void *)object); exit(3); }
        object = nil;
    }
    if (object != nil) { weakObjects[weakCount] = object; weakLocations[weakCount++] = location; }
    return *location = object;
}
static id mock_storeWeak(id *location, id object) { return storeWeak(location, object, 1); }
static id mock_storeWeakOrNil(id *location, id object) { return storeWeak(location, object, 0); }
static id mock_loadWeakRetained(id *location) { return isDeallocating(*location) ? nil : [*location retain]; }
static id mock_loadWeak(id *location) { return [mock_loadWeakRetained(location) autorelease]; }
BOOL _objc_rootIsDeallocating(id obj) { return isDeallocating(obj); }
#define objc_storeWeak mock_storeWeak
#define objc_storeWeakOrNil mock_storeWeakOrNil
#define objc_loadWeak mock_loadWeak
#define objc_loadWeakRetained mock_loadWeakRetained

@interface NSString : NSObject
- (BOOL)isEqualToString:(NSString *)other;
@end
@interface NSConstantString : NSString { @public const char *_chars; unsigned int _length; } @end
@implementation NSConstantString @end
@implementation NSString
- (BOOL)isEqualToString:(NSString *)other
{
    return other != nil && strcmp(((NSConstantString *)self)->_chars, ((NSConstantString *)other)->_chars) == 0;
}
@end

typedef struct { unsigned long state; id *itemsPtr; unsigned long *mutationsPtr; unsigned long extra[5]; } NSFastEnumerationState;
@interface NSIndexSet : NSObject { @public unsigned char _set[64]; } @end
@implementation NSIndexSet @end

@interface NSArray : NSObject {
@public
    id _items[64];
    NSUInteger _count;
    unsigned long _mutations;
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)buffer count:(NSUInteger)len;
- (NSIndexSet *)indexesOfObjectsPassingTest:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))predicate;
@end
@implementation NSArray
- (id)copy
{
    NSArray *c = [NSArray alloc];
    while (c->_count < _count) c->_items[c->_count] = [_items[c->_count] retain], c->_count++;
    return c;
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)buffer count:(NSUInteger)len
{
    (void)buffer; (void)len;
    if (state->state++) return 0;
    state->itemsPtr = _items;
    state->mutationsPtr = &_mutations;
    return _count;
}
- (NSIndexSet *)indexesOfObjectsPassingTest:(BOOL (^)(id obj, NSUInteger idx, BOOL *stop))predicate
{
    NSIndexSet *set = [[NSIndexSet alloc] autorelease];
    BOOL stop = NO;
    for (NSUInteger i = 0; i < _count && !stop; i++)
        set->_set[i] = predicate(_items[i], i, &stop);
    return set;
}
- (void)dealloc
{
    for (NSUInteger i = 0; i < _count; i++) [_items[i] release];
    [super dealloc];
}
@end
@interface NSMutableArray : NSArray
- (void)addObject:(id)object;
- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes;
@end
@implementation NSMutableArray
- (void)addObject:(id)object { _items[_count++] = [object retain]; _mutations++; }
- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes
{
    NSUInteger kept = 0, n = _count, nremoved = 0;
    id removed[64];
    for (NSUInteger i = 0; i < n; i++)
        if (indexes->_set[i]) removed[nremoved++] = _items[i]; else _items[kept++] = _items[i];
    _count = kept;
    _mutations++;
    while (nremoved > 0) [removed[--nremoved] release];
}
@end

@class NSDictionary;
@interface NSOperationQueue : NSObject
- (void)addOperationWithBlock:(void (^)(void))block;
@end

@interface NSNotification : NSObject
- (NSString *)name;
- (id)object;
- (NSDictionary *)userInfo;
@end
@implementation NSNotification @end
@interface NSConcreteNotification : NSNotification {
    NSString *name;
    id object;
}
+ (id)newTempNotificationWithName:(NSString *)name object:(id)anObject userInfo:(NSDictionary *)aUserInfo;
- (void)recycle;
@end
@implementation NSConcreteNotification
+ (id)newTempNotificationWithName:(NSString *)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo
{
    (void)aUserInfo;
    NSConcreteNotification *n = [self alloc];
    n->name = aName, n->object = anObject;
    return n;
}
- (NSString *)name { return name; }
- (id)object { return object; }
- (void)recycle { [self release]; }
@end

@interface NSNotificationCenter : NSObject {
@public
    NSMutableArray *_observers;
    pthread_mutex_t _observersLock;
}
- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName object:(id)anObject;
- (void)postNotificationName:(NSString *)aName object:(id)anObject;
- (void)removeObserver:(id)observer;
- (void)removeObserver:(id)observer name:(NSString *)aName object:(id)anObject;
@end

#include SOURCE_INC

static int received;

@interface Observer : NSObject {
@public
    NSNotificationCenter *center;
    int removeInDealloc; // 1: removeObserver:, 2: removeObserver:name:object:
    int releaseInHandler;
}
- (void)handle:(NSNotification *)note;
@end
@implementation Observer
- (void)handle:(NSNotification *)note
{
    (void)note;
    received++;
    if (releaseInHandler) {
        releaseInHandler = 0;
        [self release];
        // Still handling the notification: the object must not have been deallocated under us.
        if (isDeallocating(self)) deadMessages++;
    }
}
- (void)dealloc
{
    if (removeInDealloc == 1) [center removeObserver:self];
    if (removeInDealloc == 2) [center removeObserver:self name:@"Ping" object:nil];
    [super dealloc];
}
@end

@interface NoWeakObserver : Observer @end
@implementation NoWeakObserver
- (BOOL)allowsWeakReference { return NO; }
@end

static int fails, checks;
#define CK(c, ...) do { checks++; if (!(c)) { fails++; printf("FAIL line %d: ", __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static Observer *observe(NSNotificationCenter *center, Class cls)
{
    Observer *o = [[cls alloc] init];
    o->center = center;
    [center addObserver:o selector:@selector(handle:) name:@"Ping" object:nil];
    return o;
}
static int weakRefsTo(id object)
{
    int n = 0;
    for (int i = 0; i < weakCount; i++) n += weakObjects[i] == object;
    return n;
}
static void post(NSNotificationCenter *center) { [center postNotificationName:@"Ping" object:nil]; drain(); }

int main(void)
{
    NSNotificationCenter *center = [[NSNotificationCenter alloc] init];

    Observer *o = observe(center, [Observer class]);
    post(center);
    CK(received == 1, "a registered observer receives the notification (%d)", received);
    CK(isDeallocating(o) == 0, "the center does not keep the observer from being deallocated by its owner");
    [o release];
    CK(isDeallocating(o), "the observer is deallocated when its owner releases it (the center does not retain it)");
    received = deadMessages = 0;
    post(center);
    CK(deadMessages == 0 && received == 0,
       "an observer deallocated without removing itself is not messaged (%d messages to it)", deadMessages);
    [center removeObserver:o];
    CK(center->_observers->_count == 0, "removeObserver: drops a dead observer (%lu left)", center->_observers->_count);

    o = observe(center, [Observer class]);
    o->removeInDealloc = 1;
    [o release];
    CK(center->_observers->_count == 0, "removeObserver:self from -dealloc removes the registration (%lu left)",
       center->_observers->_count);

    o = observe(center, [Observer class]);
    o->removeInDealloc = 2;
    [o release];
    CK(center->_observers->_count == 0, "removeObserver:self name:object: from -dealloc removes the registration "
       "(%lu left)", center->_observers->_count);

    o = observe(center, [Observer class]);
    o->releaseInHandler = 1;
    received = deadMessages = 0;
    post(center);
    CK(received == 1 && deadMessages == 0,
       "an observer that drops its last reference in the handler stays alive until the handler returns");
    CK(isDeallocating(o), "and is deallocated afterwards");
    [center removeObserver:o];

    o = observe(center, [NoWeakObserver class]);
    received = 0;
    post(center);
    CK(received == 1, "an observer that refuses weak references is registered and receives the notification");
    [center removeObserver:o];
    CK(center->_observers->_count == 0, "and removeObserver: removes it (%lu left)", center->_observers->_count);
    received = 0;
    post(center);
    CK(received == 0, "and it receives nothing after removal");

    // An observer added while it is deallocating (from another object's dealloc, say) must not be registered, since
    // objc_storeWeakOrNil refuses it exactly like a class that rejects weak references.
    o = [[Observer alloc] init];
    o->center = center;
    [o release];
    CK(isDeallocating(o), "setup: the observer is deallocated");
    [center addObserver:o selector:@selector(handle:) name:@"Ping" object:nil];
    CK(center->_observers->_count == 0, "an observer that is already deallocating is not registered (%lu)",
       center->_observers->_count);
    received = deadMessages = 0;
    post(center);
    CK(deadMessages == 0 && received == 0, "and it is not messaged (%d messages to it)", deadMessages);

    // The weak slot of a registered observer is cleaned up: when the registration is dropped while the observer
    // lives, the record's -dealloc unregisters its weak slot (else the runtime would later write to freed memory);
    // when the observer dies first, the slot is zeroed and no later post messages it.
    o = observe(center, [Observer class]);
    CK(weakRefsTo(o) == 1, "a registered observer is held by exactly one weak slot (%d)", weakRefsTo(o));
    [center removeObserver:o];
    CK(weakRefsTo(o) == 0, "removing the registration unregisters its weak slot (%d left)", weakRefsTo(o));
    [o release];

    o = observe(center, [Observer class]);
    [o release];
    CK(weakRefsTo(o) == 0, "the weak slot is cleared when the observer deallocates (%d left)", weakRefsTo(o));
    received = deadMessages = 0;
    post(center);
    CK(deadMessages == 0 && received == 0, "and a later post does not message it (%d messages)", deadMessages);
    [center removeObserver:o];

    printf("%s: %d checks, %d failed\n", fails ? "FAIL" : "PASS", checks, fails);
    return fails != 0;
}
