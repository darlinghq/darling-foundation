// Copyright (C) 2026 Lubos Dolezel
//
// Keyed archiving: conditional objects, raising decoders, class-checked unarchiving and
// block-based undo registration, against the documented contracts.
#import <Foundation/Foundation.h>
#include <stdio.h>
#include <stdlib.h>

// Values of NSCoderReadCorruptError and NSCoderValueNotFoundError (FoundationErrors.h).
static const NSInteger kCoderReadCorrupt = 4864, kCoderValueNotFound = 4865;
static int failures;
#define CHECK(cond, ...) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

@interface Node : NSObject <NSCoding, NSSecureCoding>
@property (retain) NSString *name;
@property (assign) Node *weakLink;     // encoded conditionally
@end

@implementation Node
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder:(NSCoder *)c
{
    if ((self = [super init])) {
        _name = [[c decodeObjectOfClass:[NSString class] forKey:@"name"] retain];
        _weakLink = [c decodeObjectOfClass:[Node class] forKey:@"link"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c
{
    [c encodeObject:_name forKey:@"name"];
    [c encodeConditionalObject:_weakLink forKey:@"link"];
}
@end

@interface Holder : NSObject <NSCoding>
@property (retain) Node *a, *b;
@property (assign) int order;           // 0: a then b; 1: b then a
@end

@implementation Holder
- (instancetype)initWithCoder:(NSCoder *)c
{
    if ((self = [super init])) {
        _a = [[c decodeObjectForKey:@"a"] retain];
        _b = [[c decodeObjectForKey:@"b"] retain];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c
{
    if (_order == 0) { [c encodeObject:_a forKey:@"a"]; [c encodeObject:_b forKey:@"b"]; }
    else { [c encodeObject:_b forKey:@"b"]; [c encodeObject:_a forKey:@"a"]; }
}
@end

static NSData *archiveRoot(id root)
{
    NSMutableData *d = [NSMutableData data];
    NSKeyedArchiver *ar = [[NSKeyedArchiver alloc] initForWritingWithMutableData:d];
    [ar setOutputFormat:NSPropertyListBinaryFormat_v1_0];
    [ar encodeObject:root forKey:@"root"];
    [ar finishEncoding];
    [ar release];
    return d;
}

static void test_conditional(int order, BOOL encodeTarget)
{
    Node *a = [[Node alloc] init], *b = [[Node alloc] init];
    a.name = @"a"; b.name = @"b";
    a.weakLink = b;                       // a refers to b conditionally
    Holder *h = [[Holder alloc] init];
    h.order = order;
    h.a = a;
    h.b = encodeTarget ? b : nil;
    NSData *d = archiveRoot(h);
    NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingWithData:d];
    Holder *r = [u decodeObjectForKey:@"root"];
    [u finishDecoding];
    CHECK(r.a != nil && [r.a.name isEqual:@"a"], @"a decoded");
    if (encodeTarget) {
        CHECK(r.b != nil, "b decoded");
        CHECK(r.a.weakLink == r.b, "conditional reference resolves to the same object");
    } else {
        CHECK(r.a.weakLink == nil, "conditional-only object decodes as nil");
    }
    [u release]; [h release]; [a release]; [b release];
}

static NSData *plistArchive(NSDictionary *top, NSArray *objects)
{
    NSDictionary *plist = @{ @"$archiver": @"NSKeyedArchiver", @"$version": @100000,
                             @"$top": top, @"$objects": objects };
    // Dictionaries of the form {CF$UID: n} become keyed-archive UIDs when read back from XML.
    NSData *xml = [NSPropertyListSerialization dataWithPropertyList:plist
                                                             format:NSPropertyListXMLFormat_v1_0
                                                            options:0 error:NULL];
    id parsed = [NSPropertyListSerialization propertyListWithData:xml options:0 format:NULL error:NULL];
    return [NSPropertyListSerialization dataWithPropertyList:parsed
                                                      format:NSPropertyListBinaryFormat_v1_0
                                                     options:0 error:NULL];
}

static void test_unarchivedObjectOfClass(void)
{
    NSError *err = nil;
    NSData *good = archiveRoot(@"hello");
    id o = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSString class] fromData:good error:&err];
    CHECK([o isEqual:@"hello"] && err == nil, "matching class decodes");

    err = nil;
    o = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSNumber class] fromData:good error:&err];
    CHECK(o == nil && err != nil, "wrong root class fails");
    CHECK([err.domain isEqual:NSCocoaErrorDomain] && err.code == kCoderReadCorrupt,
          "wrong class: kCoderReadCorrupt, got %ld", (long)err.code);

    err = nil;
    o = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSString class]
                                          fromData:[@"not an archive" dataUsingEncoding:NSUTF8StringEncoding]
                                             error:&err];
    CHECK(o == nil && err != nil && err.code == kCoderReadCorrupt, "garbage: kCoderReadCorrupt");

    // An archive without a root key: kCoderValueNotFound.
    err = nil;
    o = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSString class]
                                          fromData:plistArchive(@{}, @[ @"$null" ]) error:&err];
    CHECK(o == nil && err != nil && err.code == kCoderValueNotFound,
          "no root: kCoderValueNotFound, got %ld", (long)(err ? err.code : 0));

    NSData *arr = archiveRoot(@[ @"x", @1 ]);
    o = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObject:[NSArray class]] fromData:arr error:&err];
    CHECK([o count] == 2, "plist classes in an array are allowed with the array class");

    o = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSString class] fromData:nil error:&err];
    CHECK(o == nil && err != nil, "nil data fails with an error");
}

@interface Probe : NSObject <NSCoding> { @public double d; float f; BOOL b; }
@end
@implementation Probe
- (instancetype)initWithCoder:(NSCoder *)c
{
    if ((self = [super init])) {
        d = [c decodeDoubleForKey:@"d"];
        f = [c decodeFloatForKey:@"f"];
        b = [c decodeBoolForKey:@"b"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {}
@end

// QUIRK coverage: test_quirk_decode_double_from_integer and test_quirk_decode_bool_from_integer.
// The archive holds integer-typed values, as nib archives do.
static void test_quirk_integer_values(void)
{
    NSDictionary *uid1 = [NSDictionary dictionaryWithObject:@1 forKey:@"CF$UID"];
    NSDictionary *uid2 = [NSDictionary dictionaryWithObject:@2 forKey:@"CF$UID"];
    NSData *d = plistArchive(@{ @"root": uid1 },
        @[ @"$null",
           @{ @"$class": uid2, @"d": @3, @"f": @-2, @"b": @1 },
           @{ @"$classname": @"Probe", @"$classes": @[ @"Probe", @"NSObject" ] } ]);
    NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingWithData:d];
    Probe *p = nil;
    @try { p = [u decodeObjectForKey:@"root"]; } @catch (NSException *e) { printf("raised: %s\n", [[e reason] UTF8String]); }
    CHECK(p != nil, "archive decodes");
    CHECK(p != nil && p->d == 3.0, "decodeDouble from integer");
    CHECK(p != nil && p->f == -2.0f, "decodeFloat from negative integer");
    CHECK(p != nil && p->b == YES, "decodeBool from integer");
    [u release];
}

static void test_raise_on_mismatch(void)
{
    NSData *d = archiveRoot(@"s");
    NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingWithData:d];
    BOOL raised = NO;
    @try { (void)[u decodeBytesForKey:@"root" returnedLength:NULL]; }
    @catch (NSException *e) { raised = [e.name isEqual:NSInvalidUnarchiveOperationException]; }
    CHECK(raised, "decoding a string as bytes raises NSInvalidUnarchiveOperationException");
    [u release];
}

@interface UndoTarget : NSObject { @public int value; }
@end
@implementation UndoTarget @end

static void test_undo_handler(void)
{
    NSUndoManager *um = [[NSUndoManager alloc] init];
    [um setGroupsByEvent:NO];
    UndoTarget *t = [[UndoTarget alloc] init];
    t->value = 1;
    [um beginUndoGrouping];
    [um registerUndoWithTarget:t handler:^(UndoTarget *x) {
        int old = x->value; x->value = 1;
        [um registerUndoWithTarget:x handler:^(UndoTarget *y) { y->value = old; }];
    }];
    [um endUndoGrouping];
    t->value = 2;
    CHECK([um canUndo], "undo registered");
    [um undo];
    CHECK(t->value == 1, "undo handler ran with the target");
    CHECK([um canRedo], "redo registered from the handler");
    [um redo];
    CHECK(t->value == 2, "redo handler ran");
    [um removeAllActionsWithTarget:t];
    CHECK(![um canUndo] && ![um canRedo], "removeAllActionsWithTarget: removes handler actions");
    [t release]; [um release];
}

int main(void)
{
    @autoreleasepool {
        test_conditional(0, YES);   // conditional reference before the unconditional encode
        test_conditional(1, YES);   // after
        test_conditional(0, NO);    // never encoded
        test_unarchivedObjectOfClass();
        test_quirk_integer_values();
        test_raise_on_mismatch();
        test_undo_handler();
    }
    printf(failures ? "FAILED (%d)\n" : "PASS\n", failures);
    return failures != 0;
}
