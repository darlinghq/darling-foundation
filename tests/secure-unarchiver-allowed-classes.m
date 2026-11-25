// Copyright (C) 2026 Lubos Dolezel
//
// Secure NSKeyedUnarchiver: every object decoded with requiresSecureCoding has to be of a class
// allowed for that decode, and its class has to adopt NSSecureCoding, answer YES to
// +supportsSecureCoding and implement +supportsSecureCoding at or below the class whose
// -initWithCoder: it uses. The expected results were observed on macOS 10.14.4 (x86_64, i386)
// and 26.7.3 (x86_64); the test passes there unchanged. Manual reference counting (i386).
#import <Foundation/Foundation.h>
#include <objc/message.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures;
#define CHECK(cond, ...) do { if (!(cond)) { failures++; printf("FAIL %s:%d: ", __func__, __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static int gMode;
static NSSet *gInnerAllowed;

enum { DecodeChildAsBox, DecodeChildForKey, DecodeChildOfNilClasses, DecodeChildAsObject, DecodeChildRecovering };

@interface SecBox : NSObject <NSSecureCoding> { @public id child; id other; }
@end
@implementation SecBox
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c
{
    if (child) [c encodeObject:child forKey:@"child"];
    if (other) [c encodeObject:other forKey:@"other"];
}
- (id)initWithCoder:(NSCoder *)c
{
    self = [super init];
    if (gInnerAllowed == nil) gInnerAllowed = [[c allowedClasses] copy];
    switch (gMode) {
    case DecodeChildAsBox: child = [c decodeObjectOfClass:[SecBox class] forKey:@"child"]; break;
    case DecodeChildForKey: child = [c decodeObjectForKey:@"child"]; break;
    case DecodeChildOfNilClasses: child = [c decodeObjectOfClasses:nil forKey:@"child"]; break;
    case DecodeChildAsObject: child = [c decodeObjectOfClass:[NSObject class] forKey:@"child"]; break;
    case DecodeChildRecovering:
        // a refused decode does not leave its classes in force for the next one
        @try { child = [c decodeObjectOfClass:[NSObject class] forKey:@"child"]; }
        @catch (NSException *e) { child = nil; }
        other = [[c decodeObjectForKey:@"other"] retain];
        break;
    }
    [child retain];
    return self;
}
@end

@interface SecOther : NSObject <NSSecureCoding>
@end
@implementation SecOther
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInt:1 forKey:@"x"]; }
- (id)initWithCoder:(NSCoder *)c { return [super init]; }
@end

@interface Insecure : NSObject <NSCoding>
@end
@implementation Insecure
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInt:1 forKey:@"x"]; }
- (id)initWithCoder:(NSCoder *)c { return [super init]; }
@end

// answers YES but does not adopt the protocol
@interface NoProtocol : NSObject
@end
@implementation NoProtocol
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInt:1 forKey:@"x"]; }
- (id)initWithCoder:(NSCoder *)c { return [super init]; }
@end

@interface SaysNo : NSObject <NSSecureCoding>
@end
@implementation SaysNo
+ (BOOL)supportsSecureCoding { return NO; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInt:1 forKey:@"x"]; }
- (id)initWithCoder:(NSCoder *)c { return [super init]; }
@end

// overrides -initWithCoder: without restating +supportsSecureCoding
@interface OverridingBox : SecBox
@end
@implementation OverridingBox
- (id)initWithCoder:(NSCoder *)c { return [super initWithCoder:c]; }
@end
// inherits such an override
@interface OverridingBoxChild : OverridingBox
@end
@implementation OverridingBoxChild
@end
// inherits everything: fine
@interface PlainBox : SecBox
@end
@implementation PlainBox
@end
// overrides both: fine
@interface RestatingBox : SecBox
@end
@implementation RestatingBox
+ (BOOL)supportsSecureCoding { return YES; }
- (id)initWithCoder:(NSCoder *)c { return [super initWithCoder:c]; }
@end

// archived under its own name, decoded as SecOther
@interface Legacy : SecOther
@end
@implementation Legacy
+ (Class)classForKeyedUnarchiver { return [SecOther class]; }
@end

static NSData *archive(id root, BOOL xml)
{
    NSMutableData *d = [NSMutableData data];
    NSKeyedArchiver *a = [[NSKeyedArchiver alloc] initForWritingWithMutableData:d];
    if (xml) [a setOutputFormat:NSPropertyListXMLFormat_v1_0];
    [a encodeObject:root forKey:@"root"];
    [a finishEncoding];
    [a release];
    return d;
}

static SecBox *box(id child)
{
    SecBox *b = [[[SecBox alloc] init] autorelease];
    b->child = [child retain];
    return b;
}

static id make(Class c) { return [[[c alloc] init] autorelease]; }

typedef id (^Decode)(NSKeyedUnarchiver *u);

typedef struct {
    id object;        // decoded object (autoreleased), nil on failure
    NSString *name;   // exception name, nil when none was raised
    NSString *reason; // exception reason
    NSError *error;   // unarchiver error
} Outcome;

static Outcome decode(NSData *data, int mode, BOOL setError, void (^setup)(NSKeyedUnarchiver *), Decode body)
{
    Outcome o = { nil, nil, nil, nil };
    gMode = mode;
    [gInnerAllowed release];
    gInnerAllowed = nil;
    NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    [u setRequiresSecureCoding:YES];
    if (setError) [u setDecodingFailurePolicy:NSDecodingFailurePolicySetErrorAndReturn];
    if (setup) setup(u);
    @try {
        o.object = [[body(u) retain] autorelease];
    } @catch (NSException *e) {
        o.name = [[[e name] copy] autorelease];
        o.reason = [[[e reason] copy] autorelease];
    }
    o.error = [[[u error] retain] autorelease];
    [u release];
    return o;
}

static Decode ofClass(Class c) { return [[^id(NSKeyedUnarchiver *u) { return [u decodeObjectOfClass:c forKey:@"root"]; } copy] autorelease]; }
static Decode ofClasses(NSSet *s) { return [[^id(NSKeyedUnarchiver *u) { return [u decodeObjectOfClasses:s forKey:@"root"]; } copy] autorelease]; }

#define SET(...) [NSSet setWithObjects:__VA_ARGS__, nil]

// The reason starts like this on all observed versions; what follows it (how the allowed
// classes are listed) differs between them.
static BOOL refusedAsUnexpected(Outcome o, NSString *key, NSString *className)
{
    NSString *prefix = [NSString stringWithFormat:@"value for key '%@' was of unexpected class '%@'", key, className];
    return [o.name isEqualToString:NSInvalidUnarchiveOperationException] && [o.reason hasPrefix:prefix] && o.object == nil;
}

static BOOL refusedWithReason(Outcome o, NSString *reason)
{
    return [o.name isEqualToString:NSInvalidUnarchiveOperationException] && [o.reason isEqualToString:reason] && o.object == nil;
}

static NSString *notAdopted(NSString *c) { return [NSString stringWithFormat:@"This decoder will only decode classes that adopt NSSecureCoding. Class '%@' does not adopt it.", c]; }
static NSString *disallows(NSString *c) { return [NSString stringWithFormat:@"Class '%@' disallows secure coding. It must return YES from supportsSecureCoding.", c]; }
static NSString *overrides(NSString *c) { return [NSString stringWithFormat:@"Class '%@' has a superclass that supports secure coding, but '%@' overrides -initWithCoder: and does not override +supportsSecureCoding. The class must implement +supportsSecureCoding and return YES to verify that its implementation of -initWithCoder: is secure coding compliant.", c, c]; }

static void test_nested_objects_use_the_allowed_classes(BOOL xml)
{
    NSData *boxOther = archive(box(make([SecOther class])), xml);
    NSData *boxBox = archive(box(box(nil)), xml);
    Decode top = ofClass([SecBox class]);
    int modes[] = { DecodeChildAsBox, DecodeChildForKey, DecodeChildOfNilClasses };
    for (int i = 0; i < 3; i++) {
        Outcome o = decode(boxOther, modes[i], NO, nil, top);
        CHECK(refusedAsUnexpected(o, @"child", @"SecOther"), "mode %d xml %d: %s | %s", modes[i], xml, [o.name UTF8String], [o.reason UTF8String]);
        CHECK([gInnerAllowed isEqual:SET([SecBox class])], "mode %d: allowedClasses inside -initWithCoder: %s", modes[i], [[gInnerAllowed description] UTF8String]);
        o = decode(boxBox, modes[i], NO, nil, top);
        CHECK([o.object isKindOfClass:[SecBox class]] && [((SecBox *)o.object)->child isKindOfClass:[SecBox class]], "mode %d xml %d: allowed child refused: %s", modes[i], xml, [o.reason UTF8String]);
    }
    // a class that does not support secure coding is refused as unexpected when not allowed
    Outcome o = decode(archive(box(make([Insecure class])), xml), DecodeChildForKey, NO, nil, top);
    CHECK(refusedAsUnexpected(o, @"child", @"Insecure"), "insecure child: %s", [o.reason UTF8String]);
    // and for not adopting NSSecureCoding when NSObject allows any class
    o = decode(archive(box(make([Insecure class])), xml), DecodeChildAsObject, NO, nil, top);
    CHECK(refusedWithReason(o, notAdopted(@"Insecure")), "insecure child as NSObject: %s", [o.reason UTF8String]);
    o = decode(boxOther, DecodeChildAsObject, NO, nil, top);
    CHECK([((SecBox *)o.object)->child isKindOfClass:[SecOther class]], "secure child as NSObject: %s", [o.reason UTF8String]);
}

static void test_top_level_needs_classes(BOOL xml)
{
    NSData *data = archive(box(nil), xml);
    Outcome o = decode(data, DecodeChildAsBox, NO, nil, ^id(NSKeyedUnarchiver *u) { return [u decodeObjectForKey:@"root"]; });
    CHECK(refusedAsUnexpected(o, @"root", @"SecBox"), "decodeObjectForKey: %s", [o.reason UTF8String]);
    o = decode(data, DecodeChildAsBox, NO, nil, ofClasses(nil));
    CHECK(refusedAsUnexpected(o, @"root", @"SecBox"), "nil classes: %s", [o.reason UTF8String]);
    o = decode(data, DecodeChildAsBox, NO, nil, ofClasses([NSSet set]));
    CHECK(refusedAsUnexpected(o, @"root", @"SecBox"), "empty classes: %s", [o.reason UTF8String]);
}

static void test_secure_coding_adoption(BOOL xml)
{
    Outcome o = decode(archive(make([Insecure class]), xml), 0, NO, nil, ofClass([Insecure class]));
    CHECK(refusedWithReason(o, notAdopted(@"Insecure")), "Insecure: %s", [o.reason UTF8String]);
    o = decode(archive(make([Insecure class]), xml), 0, NO, nil, ofClass([NSObject class]));
    CHECK(refusedWithReason(o, notAdopted(@"Insecure")), "Insecure as NSObject: %s", [o.reason UTF8String]);
    o = decode(archive(make([NoProtocol class]), xml), 0, NO, nil, ofClass([NoProtocol class]));
    CHECK(refusedWithReason(o, notAdopted(@"NoProtocol")), "NoProtocol: %s", [o.reason UTF8String]);
    o = decode(archive(make([SaysNo class]), xml), 0, NO, nil, ofClass([SaysNo class]));
    CHECK(refusedWithReason(o, disallows(@"SaysNo")), "SaysNo: %s", [o.reason UTF8String]);
    o = decode(archive(make([OverridingBox class]), xml), 0, NO, nil, ofClass([OverridingBox class]));
    CHECK(refusedWithReason(o, overrides(@"OverridingBox")), "OverridingBox: %s", [o.reason UTF8String]);
    o = decode(archive(make([OverridingBox class]), xml), 0, NO, nil, ofClass([SecBox class]));
    CHECK(refusedWithReason(o, overrides(@"OverridingBox")), "OverridingBox as SecBox: %s", [o.reason UTF8String]);
    o = decode(archive(make([OverridingBoxChild class]), xml), 0, NO, nil, ofClass([SecBox class]));
    CHECK(refusedWithReason(o, overrides(@"OverridingBoxChild")), "OverridingBoxChild: %s", [o.reason UTF8String]);
    o = decode(archive(make([PlainBox class]), xml), 0, NO, nil, ofClass([SecBox class]));
    CHECK([o.object isMemberOfClass:[PlainBox class]], "PlainBox: %s", [o.reason UTF8String]);
    o = decode(archive(make([RestatingBox class]), xml), 0, NO, nil, ofClass([SecBox class]));
    CHECK([o.object isMemberOfClass:[RestatingBox class]], "RestatingBox: %s", [o.reason UTF8String]);
    o = decode(archive(make([SecOther class]), xml), 0, NO, nil, ofClass([NSObject class]));
    CHECK([o.object isMemberOfClass:[SecOther class]], "SecOther as NSObject: %s", [o.reason UTF8String]);
    o = decode(archive([NSArray arrayWithObject:make([Insecure class])], xml), 0, NO, nil, ofClasses(SET([NSArray class], [Insecure class])));
    CHECK(refusedWithReason(o, notAdopted(@"Insecure")), "array of Insecure: %s", [o.reason UTF8String]);
}

static void test_collection_elements(BOOL xml)
{
    // binary archives name the collection's key, XML archives an empty one
    NSString *elementKey = xml ? @"" : @"NS.objects";
    SecOther *other = make([SecOther class]);
    NSData *array = archive([NSArray arrayWithObject:other], xml);
    Outcome o = decode(array, 0, NO, nil, ofClasses(SET([NSArray class], [SecBox class])));
    CHECK(refusedAsUnexpected(o, elementKey, @"SecOther"), "array: %s", [o.reason UTF8String]);
    o = decode(array, 0, NO, nil, ofClasses(SET([NSArray class], [SecOther class])));
    CHECK([o.object isKindOfClass:[NSArray class]] && [[o.object lastObject] isKindOfClass:[SecOther class]], "array allowed: %s", [o.reason UTF8String]);
    o = decode(array, 0, NO, nil, ofClass([SecOther class]));
    CHECK(refusedAsUnexpected(o, @"root", @"NSArray"), "array class not allowed: %s", [o.reason UTF8String]);
    o = decode(archive([NSArray arrayWithObject:[NSArray arrayWithObject:other]], xml), 0, NO, nil, ofClasses(SET([NSArray class], [SecOther class])));
    CHECK([[[o.object lastObject] lastObject] isKindOfClass:[SecOther class]], "nested arrays: %s", [o.reason UTF8String]);
    o = decode(archive([NSMutableArray arrayWithObject:@"m"], xml), 0, NO, nil, ofClass([NSArray class]));
    CHECK([o.object isKindOfClass:[NSArray class]], "mutable array: %s", [o.reason UTF8String]);

    NSData *dict = archive([NSDictionary dictionaryWithObject:other forKey:@"k"], xml);
    o = decode(dict, 0, NO, nil, ofClasses(SET([NSDictionary class], [NSString class])));
    CHECK(refusedAsUnexpected(o, elementKey, @"SecOther"), "dictionary: %s", [o.reason UTF8String]);
    o = decode(dict, 0, NO, nil, ofClasses(SET([NSDictionary class], [NSString class], [SecOther class])));
    CHECK([[o.object objectForKey:@"k"] isKindOfClass:[SecOther class]], "dictionary allowed: %s", [o.reason UTF8String]);

    NSData *set = archive([NSSet setWithObject:other], xml);
    o = decode(set, 0, NO, nil, ofClasses(SET([NSSet class], [SecBox class])));
    CHECK(refusedAsUnexpected(o, elementKey, @"SecOther"), "set: %s", [o.reason UTF8String]);
    o = decode(set, 0, NO, nil, ofClasses(SET([NSSet class], [SecOther class])));
    CHECK([[o.object anyObject] isKindOfClass:[SecOther class]], "set allowed: %s", [o.reason UTF8String]);

    NSData *oset = archive([NSOrderedSet orderedSetWithObject:other], xml);
    o = decode(oset, 0, NO, nil, ofClasses(SET([NSOrderedSet class], [SecBox class])));
    CHECK(refusedAsUnexpected(o, @"NS.object.0", @"SecOther"), "ordered set: %s", [o.reason UTF8String]);
    o = decode(oset, 0, NO, nil, ofClasses(SET([NSOrderedSet class], [SecOther class])));
    CHECK([o.object isKindOfClass:[NSOrderedSet class]] && [[o.object firstObject] isKindOfClass:[SecOther class]], "ordered set allowed: %s | %s", [o.name UTF8String], [o.reason UTF8String]);

    NSValue *rect = [NSValue valueWithRect:NSMakeRect(1, 2, 3, 4)];
    o = decode(archive(rect, xml), 0, NO, nil, ofClass([NSValue class]));
    CHECK(NSEqualRects([o.object rectValue], NSMakeRect(1, 2, 3, 4)), "NSValue: %s", [o.reason UTF8String]);
    o = decode(archive([NSArray arrayWithObject:rect], xml), 0, NO, nil, ofClass([NSArray class]));
    CHECK(refusedAsUnexpected(o, elementKey, @"NSValue"), "array of NSValue: %s", [o.reason UTF8String]);
    o = decode(archive([NSDate dateWithTimeIntervalSince1970:0], xml), 0, NO, nil, ofClass([NSString class]));
    CHECK(refusedAsUnexpected(o, @"root", @"NSDate"), "NSDate: %s", [o.reason UTF8String]);
    o = decode(archive([NSURL URLWithString:@"http://example.com/"], xml), 0, NO, nil, ofClass([NSString class]));
    CHECK(refusedAsUnexpected(o, @"root", @"NSURL"), "NSURL: %s", [o.reason UTF8String]);
    o = decode(archive([NSURL URLWithString:@"http://example.com/"], xml), 0, NO, nil, ofClass([NSURL class]));
    CHECK([o.object isKindOfClass:[NSURL class]], "NSURL allowed: %s", [o.reason UTF8String]);

    // a box whose -initWithCoder: allows SecBox and NSArray for its child
    gMode = 0;
    NSData *boxArray = archive(box([NSArray arrayWithObject:other]), xml);
    o = decode(boxArray, 0, NO, nil, ^id(NSKeyedUnarchiver *u) { return [u decodeObjectOfClass:[SecBox class] forKey:@"root"]; });
    // mode 0 asks for SecBox only, so the array itself is refused
    CHECK(refusedAsUnexpected(o, @"child", @"NSArray"), "box of array: %s", [o.reason UTF8String]);
}

static void test_quirk_plist_scalars_unchecked(BOOL xml)
{
    // QUIRK (see NSKeyedUnarchiver.m): inline strings, numbers and data are not checked
    Outcome o = decode(archive([NSArray arrayWithObjects:@"s", [NSNumber numberWithInt:1], [NSData data], nil], xml), 0, NO, nil, ofClass([NSArray class]));
    CHECK([o.object count] == 3, "array of scalars: %s", [o.reason UTF8String]);
    o = decode(archive([NSNumber numberWithInt:5], xml), 0, NO, nil, ofClass([NSString class]));
    CHECK([o.object isKindOfClass:[NSNumber class]], "number as string: %s", [o.reason UTF8String]);
    o = decode(archive(@"str", xml), 0, NO, nil, ofClass([NSNumber class]));
    CHECK([o.object isKindOfClass:[NSString class]], "string as number: %s", [o.reason UTF8String]);
    o = decode(archive([NSDictionary dictionaryWithObject:@"v" forKey:[NSNumber numberWithInt:1]], xml), 0, NO, nil, ofClasses(SET([NSDictionary class], [NSString class])));
    CHECK([o.object count] == 1, "number key: %s", [o.reason UTF8String]);
}

static void test_class_substitution(BOOL xml)
{
    NSData *other = archive(make([SecOther class]), xml);
    void (^asBox)(NSKeyedUnarchiver *) = ^(NSKeyedUnarchiver *u) { [u setClass:[SecBox class] forClassName:@"SecOther"]; };
    Outcome o = decode(other, 0, NO, asBox, ofClass([SecBox class]));
    CHECK([o.object isMemberOfClass:[SecBox class]], "substituted allowed: %s", [o.reason UTF8String]);
    o = decode(other, 0, NO, asBox, ofClass([SecOther class]));
    CHECK(refusedAsUnexpected(o, @"root", @"SecBox"), "substituted class checked: %s", [o.reason UTF8String]);
    o = decode(other, 0, NO, ^(NSKeyedUnarchiver *u) { [u setClass:[Insecure class] forClassName:@"SecOther"]; }, ofClass([Insecure class]));
    CHECK(refusedWithReason(o, notAdopted(@"Insecure")), "substituted insecure: %s", [o.reason UTF8String]);
    NSData *legacy = archive(make([Legacy class]), xml);
    o = decode(legacy, 0, NO, nil, ofClass([SecOther class]));
    CHECK([o.object isMemberOfClass:[SecOther class]], "classForKeyedUnarchiver: %s", [o.reason UTF8String]);
    o = decode(legacy, 0, NO, nil, ofClass([Legacy class]));
    CHECK(refusedAsUnexpected(o, @"root", @"SecOther"), "classForKeyedUnarchiver checked: %s", [o.reason UTF8String]);
}

static void test_refused_decode_does_not_widen_classes(BOOL xml)
{
    SecBox *b = box(make([Insecure class]));
    b->other = [make([SecOther class]) retain];
    Outcome o = decode(archive(b, xml), DecodeChildRecovering, NO, nil, ofClass([SecBox class]));
    // Darling drops the classes of the refused decode, so SecBox alone applies again. macOS
    // 10.14.4 and 26.7.3 keep NSObject in force after the caught refusal and return SecOther;
    // Darling deliberately does not copy that, as it widens what later decodes accept.
    if (o.object != nil && [((SecBox *)o.object)->other isKindOfClass:[SecOther class]])
        printf("NOTE: the classes of a refused decode stay in force after it was caught (macOS behaviour)\n");
    else
        CHECK(refusedAsUnexpected(o, @"other", @"SecOther"), "after a caught refusal: %s | %s", [o.name UTF8String], [o.reason UTF8String]);
}

static void test_set_error_policy(BOOL xml)
{
    Outcome o = decode(archive(make([Insecure class]), xml), 0, YES, nil, ofClass([Insecure class]));
    CHECK(o.name == nil && o.object == nil && [[o.error domain] isEqual:NSCocoaErrorDomain] && [o.error code] == NSCoderReadCorruptError, "set error: %s", [[o.error description] UTF8String]);
    CHECK([[[o.error userInfo] objectForKey:NSDebugDescriptionErrorKey] isEqual:notAdopted(@"Insecure")], "debug description: %s", [[o.error description] UTF8String]);
    o = decode(archive([NSArray arrayWithObject:make([SecOther class])], xml), 0, YES, nil, ofClasses(SET([NSArray class], [SecBox class])));
    CHECK(o.name == nil && o.object == nil && [o.error code] == NSCoderReadCorruptError, "set error, array: %s", [[o.error description] UTF8String]);
    // a refused member records the error; later decodes return nil
    o = decode(archive(box(make([SecOther class])), xml), DecodeChildAsBox, YES, nil, ^id(NSKeyedUnarchiver *u) {
        [u decodeObjectOfClass:[SecBox class] forKey:@"root"];
        return [u decodeObjectOfClass:[SecBox class] forKey:@"root"];
    });
    CHECK(o.name == nil && o.object == nil && [o.error code] == NSCoderReadCorruptError, "set error, nested: %s", [[o.error description] UTF8String]);
}

static void test_decode_array_of_objects(BOOL xml)
{
    if (![NSKeyedUnarchiver instancesRespondToSelector:@selector(decodeArrayOfObjectsOfClass:forKey:)]) return; // macOS 11 and later
    NSData *array = archive([NSArray arrayWithObject:make([SecOther class])], xml);
    Outcome o = decode(array, 0, NO, nil, ^id(NSKeyedUnarchiver *u) { return ((id (*)(id, SEL, Class, NSString *))objc_msgSend)(u, @selector(decodeArrayOfObjectsOfClass:forKey:), [SecBox class], @"root"); });
    CHECK(refusedAsUnexpected(o, xml ? @"" : @"NS.objects", @"SecOther"), "decodeArrayOfObjectsOfClass: %s", [o.reason UTF8String]);
    o = decode(array, 0, NO, nil, ^id(NSKeyedUnarchiver *u) { return ((id (*)(id, SEL, Class, NSString *))objc_msgSend)(u, @selector(decodeArrayOfObjectsOfClass:forKey:), [SecOther class], @"root"); });
    CHECK([[o.object lastObject] isKindOfClass:[SecOther class]], "decodeArrayOfObjectsOfClass allowed: %s", [o.reason UTF8String]);
    NSData *dict = archive([NSDictionary dictionaryWithObject:make([SecOther class]) forKey:@"k"], xml);
    o = decode(dict, 0, NO, nil, ^id(NSKeyedUnarchiver *u) { return ((id (*)(id, SEL, Class, Class, NSString *))objc_msgSend)(u, @selector(decodeDictionaryWithKeysOfClass:objectsOfClass:forKey:), [NSString class], [SecBox class], @"root"); });
    CHECK(refusedAsUnexpected(o, xml ? @"" : @"NS.objects", @"SecOther"), "decodeDictionaryWithKeysOfClass: %s", [o.reason UTF8String]);
}

static void test_init_for_reading_from_data(void)
{
    NSError *error = nil;
    NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingFromData:archive(make([Insecure class]), NO) error:&error];
    CHECK(u != nil && error == nil, "init: %s", [[error description] UTF8String]);
    CHECK([u requiresSecureCoding], "initForReadingFromData:error: does not require secure coding");
    CHECK([u decodingFailurePolicy] == NSDecodingFailurePolicySetErrorAndReturn, "failure policy %ld", (long)[u decodingFailurePolicy]);
    id object = [u decodeObjectOfClass:[Insecure class] forKey:@"root"];
    CHECK(object == nil && [[u error] code] == NSCoderReadCorruptError, "Insecure decoded through initForReadingFromData:error:");
    [u release];
}

static void test_unarchived_object_of_classes(void)
{
    gMode = DecodeChildForKey;
    [gInnerAllowed release];
    gInnerAllowed = nil;
    NSError *error = nil;
    NSData *boxOther = archive(box(make([SecOther class])), NO);
    id o = [NSKeyedUnarchiver unarchivedObjectOfClass:[SecBox class] fromData:boxOther error:&error];
    CHECK(o == nil && [[error domain] isEqual:NSCocoaErrorDomain] && [error code] == NSCoderReadCorruptError, "nested: %s", [[error description] UTF8String]);
    CHECK([[[error userInfo] objectForKey:NSDebugDescriptionErrorKey] hasPrefix:@"value for key 'child' was of unexpected class 'SecOther'"], "debug description: %s", [[error description] UTF8String]);
    CHECK([gInnerAllowed isEqual:SET([SecBox class])], "only the given classes are allowed: %s", [[gInnerAllowed description] UTF8String]);
    error = nil;
    o = [NSKeyedUnarchiver unarchivedObjectOfClasses:SET([SecBox class], [SecOther class]) fromData:boxOther error:&error];
    CHECK([((SecBox *)o)->child isKindOfClass:[SecOther class]] && error == nil, "both allowed: %s", [[error description] UTF8String]);
    error = nil;
    o = [NSKeyedUnarchiver unarchivedObjectOfClass:[Insecure class] fromData:archive(make([Insecure class]), NO) error:&error];
    CHECK(o == nil && [error code] == NSCoderReadCorruptError, "Insecure: %s", [[error description] UTF8String]);
    error = nil;
    o = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSArray class] fromData:archive([NSArray arrayWithObject:@"s"], NO) error:&error];
    CHECK([o count] == 1 && error == nil, "array of strings: %s", [[error description] UTF8String]);
    error = nil;
    o = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSArray class] fromData:archive([NSArray arrayWithObject:[NSDate date]], NO) error:&error];
    CHECK(o == nil && [error code] == NSCoderReadCorruptError, "no property list classes are added (NSDate): %s", [[error description] UTF8String]);
    error = nil;
    o = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSDictionary class] fromData:archive([NSDictionary dictionaryWithObject:[NSArray array] forKey:@"k"], NO) error:&error];
    CHECK(o == nil && [error code] == NSCoderReadCorruptError, "no property list classes are added (NSArray): %s", [[error description] UTF8String]);
}

int main(void)
{
    @autoreleasepool {
        for (int xml = 0; xml < 2; xml++) {
            test_nested_objects_use_the_allowed_classes(xml);
            test_top_level_needs_classes(xml);
            test_secure_coding_adoption(xml);
            test_collection_elements(xml);
            test_quirk_plist_scalars_unchecked(xml);
            test_class_substitution(xml);
            test_refused_decode_does_not_widen_classes(xml);
            test_set_error_policy(xml);
            test_decode_array_of_objects(xml);
        }
        test_init_for_reading_from_data();
        test_unarchived_object_of_classes();
    }
    if (failures) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("PASS\n");
    return 0;
}
