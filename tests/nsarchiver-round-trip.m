#import <Foundation/Foundation.h>
#include <stdio.h>
#include <string.h>

static int failures;

static void expect(BOOL condition, NSString *label)
{
    printf("%s %s\n", condition ? "PASS" : "FAIL", [label UTF8String]);
    failures += !condition;
}

typedef struct
{
    char tag;
    double value;
    int counts[3];
} Sample;

@interface Node : NSObject <NSCoding>
@property (retain) NSString *name;
@property (retain) Node *child;
@property (assign) Node *parent;
@property (assign) Node *unrelated;
@property (assign) Sample sample;
@property (assign) SEL action;
@property (assign) Class kind;
@property (assign) short small;
@property (assign) float ratio;
@property (assign) BOOL flag;
@property (assign) NSRect frame;
@property (assign) char *note;
@end

@implementation Node

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_name];
    [coder encodeConditionalObject:_parent];
    [coder encodeConditionalObject:_unrelated];
    [coder encodeObject:_child];
    [coder encodeValueOfObjCType:@encode(Sample) at:&_sample];
    [coder encodeValuesOfObjCTypes:":#sfc", &_action, &_kind, &_small, &_ratio, &_flag];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&_flag];
    [coder encodeRect:_frame];
    [coder encodeValueOfObjCType:@encode(char *) at:&_note];
    [coder encodeBytes:"raw\0bytes" length:9];
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    _name = [[coder decodeObject] retain];
    _parent = [coder decodeObject];
    _unrelated = [coder decodeObject];
    _child = [[coder decodeObject] retain];
    [coder decodeValueOfObjCType:@encode(Sample) at:&_sample];
    [coder decodeValuesOfObjCTypes:":#sfc", &_action, &_kind, &_small, &_ratio, &_flag];
    [coder decodeValueOfObjCType:@encode(BOOL) at:&_flag];
    _frame = [coder decodeRect];
    [coder decodeValueOfObjCType:@encode(char *) at:&_note];
    NSUInteger length = 0;
    const void *bytes = [coder decodeBytesWithReturnedLength:&length];
    expect(length == 9 && memcmp(bytes, "raw\0bytes", 9) == 0, @"encodeBytes:length: round-trips");
    return self;
}

@end

@interface Stand : NSObject <NSCoding>
@end

@implementation Stand
- (void)encodeWithCoder:(NSCoder *)coder {}
- (id)initWithCoder:(NSCoder *)coder { return [super init]; }
@end

@interface Stood : NSObject
@end

@implementation Stood
- (id)replacementObjectForArchiver:(NSArchiver *)archiver
{
    return [[[Stand alloc] init] autorelease];
}
@end

int main(void)
{
    @autoreleasepool
    {
        NSData *small = [NSArchiver archivedDataWithRootObject:@"x"];
        const char header[] = "\x04\x0bstreamtyped\x81\xe8\x03";
        expect(small.length > sizeof(header) - 1 && memcmp(small.bytes, header, sizeof(header) - 1) == 0,
               @"archive starts with the typedstream header");

        NSDictionary *plist = @{@"name" : @"Grapher", @"list" : @[ @1, @2.5, @"three" ], @"data" : [NSData dataWithBytes:"\x00\x01\x02" length:3]};
        id plistCopy = [NSUnarchiver unarchiveObjectWithData:[NSArchiver archivedDataWithRootObject:plist]];
        expect([plistCopy isEqual:plist], [NSString stringWithFormat:@"property list round-trips (%@)", plistCopy]);

        Node *root = [[Node alloc] init];
        Node *leaf = [[Node alloc] init];
        Node *stranger = [[Node alloc] init];
        root.name = @"root";
        leaf.name = @"leaf";
        root.child = leaf;
        leaf.parent = root;
        root.parent = leaf;
        leaf.unrelated = stranger;
        root.sample = (Sample){'r', 2.75, {1, -300, 70000}};
        root.action = @selector(performClick:);
        root.kind = [NSString class];
        root.small = -1234;
        root.ratio = 0.5f;
        root.flag = YES;
        root.frame = NSMakeRect(1, 2, 300, 400);
        root.note = "a note";

        NSData *archive = [NSArchiver archivedDataWithRootObject:root];
        expect(archive.length > 0, [NSString stringWithFormat:@"custom graph archives (%lu bytes)", (unsigned long)archive.length]);
        Node *copy = [NSUnarchiver unarchiveObjectWithData:archive];
        expect([copy isKindOfClass:[Node class]] && [copy.name isEqualToString:@"root"], @"root object decodes");
        expect([copy.child.name isEqualToString:@"leaf"], @"child decodes");
        expect(copy.child.parent == copy, @"back-reference resolves to the same object");
        expect(copy.parent == copy.child, @"conditional object encoded later in the graph is kept");
        expect(copy.child.unrelated == nil, @"conditional object not otherwise encoded becomes nil");
        Sample s = copy.sample;
        expect(s.tag == 'r' && s.value == 2.75 && s.counts[0] == 1 && s.counts[1] == -300 && s.counts[2] == 70000,
               [NSString stringWithFormat:@"struct with char, double and int array round-trips (%c %g %d %d %d)", s.tag, s.value, s.counts[0], s.counts[1], s.counts[2]]);
        expect(copy.action == @selector(performClick:), @"selector round-trips");
        expect(copy.kind == [NSString class], @"class round-trips");
        expect(copy.small == -1234 && copy.ratio == 0.5f && copy.flag, @"short, float and BOOL round-trip");
        expect(NSEqualRects(copy.frame, NSMakeRect(1, 2, 300, 400)), @"encodeRect: round-trips");
        expect(copy.note != NULL && strcmp(copy.note, "a note") == 0, @"C string round-trips");

        id stood = [NSUnarchiver unarchiveObjectWithData:[NSArchiver archivedDataWithRootObject:@[ [[Stood new] autorelease] ]]];
        expect([[stood firstObject] isKindOfClass:[Stand class]], @"replacementObjectForArchiver: is honoured");

        NSMutableData *manual = [NSMutableData data];
        NSArchiver *archiver = [[NSArchiver alloc] initForWritingWithMutableData:manual];
        int answer = 42;
        [archiver encodeValueOfObjCType:@encode(int) at:&answer];
        [archiver encodeRootObject:@"tail"];
        expect([archiver archiverData] == manual, @"archiverData is the target data");
        [archiver release];
        NSUnarchiver *unarchiver = [[NSUnarchiver alloc] initForReadingWithData:manual];
        int decoded = 0;
        [unarchiver decodeValueOfObjCType:@encode(int) at:&decoded];
        expect(decoded == 42 && [[unarchiver decodeObject] isEqual:@"tail"], @"values before the root object decode in order");
        [unarchiver release];

        NSMutableArray *many = [NSMutableArray array];
        for (int i = 0; i < 400; i++)
            [many addObject:[NSString stringWithFormat:@"item %d", i]];
        NSArray *twice = @[ many, many.lastObject ];
        NSArray *twiceCopy = [NSUnarchiver unarchiveObjectWithData:[NSArchiver archivedDataWithRootObject:twice]];
        expect([twiceCopy[0] isEqual:many] && twiceCopy[1] == [twiceCopy[0] lastObject],
               @"references to labels beyond the one-byte range resolve");

        typedef union { int i; char c[8]; } Mixed;
        int longs[3] = {7, -8, 90000};
        Mixed mixed = {.c = "union!"};
        char *emptyNote = "", *accented = "caf\xc3\xa9";
        NSMutableData *values = [NSMutableData data];
        NSArchiver *valueArchiver = [[NSArchiver alloc] initForWritingWithMutableData:values];
        [valueArchiver encodeValueOfObjCType:"[3l]" at:longs];
        [valueArchiver encodeValueOfObjCType:@encode(Mixed) at:&mixed];
        [valueArchiver encodeValuesOfObjCTypes:"**%", &emptyNote, &accented, &accented];
        [valueArchiver release];
        NSUnarchiver *valueUnarchiver = [[NSUnarchiver alloc] initForReadingWithData:values];
        int longsCopy[3] = {0};
        Mixed mixedCopy = {0};
        char *emptyCopy = NULL, *accentedCopy = NULL;
        const char *atom = NULL;
        [valueUnarchiver decodeValueOfObjCType:"[3l]" at:longsCopy];
        [valueUnarchiver decodeValueOfObjCType:@encode(Mixed) at:&mixedCopy];
        [valueUnarchiver decodeValuesOfObjCTypes:"**%", &emptyCopy, &accentedCopy, &atom];
        [valueUnarchiver release];
        expect(memcmp(longs, longsCopy, sizeof(longs)) == 0, @"'l' array round-trips");
        expect(memcmp(&mixed, &mixedCopy, sizeof(mixed)) == 0, @"union round-trips");
        expect(emptyCopy && accentedCopy && strcmp(emptyCopy, "") == 0 && strcmp(accentedCopy, accented) == 0 &&
               atom && strcmp(atom, accented) == 0, @"empty and UTF-8 C strings and atoms round-trip");

        BOOL raised = NO;
        @try
        {
            NSInteger big = (NSInteger)1 << 40;
            NSArchiver *a = [[[NSArchiver alloc] initForWritingWithMutableData:[NSMutableData data]] autorelease];
            [a encodeValueOfObjCType:@encode(NSInteger) at:&big];
        }
        @catch (NSException *e)
        {
            raised = [e.name isEqual:NSInvalidArchiveOperationException];
        }
        expect(raised, @"a 64-bit value the format cannot hold raises");
    }
    printf("failures=%d\n", failures);
    return failures != 0;
}
