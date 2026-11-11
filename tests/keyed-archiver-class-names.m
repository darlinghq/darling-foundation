// NSKeyedArchiver / NSKeyedUnarchiver class-name translation: instance and class-wide
// mappings end up in $classname and $classes, the instance mapping wins, nil removes a
// mapping, the getters report only their own mappings, and archives round-trip through
// the matching unarchiver mappings.
#import <Foundation/Foundation.h>
#include <stdlib.h>

static void expect(BOOL condition, NSString *message)
{
    if (!condition)
    {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface Widget : NSObject <NSCoding>
@property int value;
@end

@implementation Widget
- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init]))
        _value = [coder decodeIntForKey:@"value"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:_value forKey:@"value"];
}
@end

static NSData *archive(NSString *instanceName)
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    if (instanceName != nil)
    {
        [archiver setClassName:instanceName forClass:[Widget class]];
        expect([[archiver classNameForClass:[Widget class]] isEqualToString:instanceName],
               @"-classNameForClass: returns the instance mapping");
    }
    Widget *widget = [[Widget alloc] init];
    widget.value = 42;
    [archiver encodeObject:widget forKey:@"root"];
    [archiver finishEncoding];
    [widget release];
    [archiver release];
    return data;
}

// The $classname and $classes of the archive's only class dictionary.
static void classNames(NSData *data, NSString **className, NSArray **classes)
{
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    *className = nil;
    for (id object in plist[@"$objects"])
    {
        if ([object isKindOfClass:[NSDictionary class]] && object[@"$classname"] != nil)
        {
            *className = object[@"$classname"];
            *classes = object[@"$classes"];
        }
    }
    expect(*className != nil, @"archive has a class dictionary");
}

static void expectCodedAs(NSData *data, NSString *name, NSString *message)
{
    NSString *className;
    NSArray *classes;
    classNames(data, &className, &classes);
    NSLog(@"%@: $classname %@, $classes %@", message, className, classes);
    expect([className isEqualToString:name], message);
    expect([classes isEqualToArray:@[name, @"NSObject"]], [message stringByAppendingString:@" ($classes)"]);
}

static Widget *unarchive(NSData *data, NSString *instanceName)
{
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    if (instanceName != nil)
    {
        [unarchiver setClass:[Widget class] forClassName:instanceName];
        expect([unarchiver classForClassName:instanceName] == [Widget class],
               @"-classForClassName: returns the instance mapping");
    }
    Widget *widget = [[unarchiver decodeObjectForKey:@"root"] retain];
    [unarchiver finishDecoding];
    [unarchiver release];
    return [widget autorelease];
}

int main(void)
{
    @autoreleasepool
    {
        expectCodedAs(archive(nil), @"Widget", @"no mapping: real class name");

        NSData *data = archive(@"X");
        expectCodedAs(data, @"X", @"instance mapping");
        Widget *widget = unarchive(data, @"X");
        expect([widget isKindOfClass:[Widget class]] && widget.value == 42, @"instance mappings round-trip");

        [NSKeyedArchiver setClassName:@"Y" forClass:[Widget class]];
        expect([[NSKeyedArchiver classNameForClass:[Widget class]] isEqualToString:@"Y"],
               @"+classNameForClass: returns the class-wide mapping");
        NSKeyedArchiver *plain = [[NSKeyedArchiver alloc] initForWritingWithMutableData:[NSMutableData data]];
        expect([plain classNameForClass:[Widget class]] == nil,
               @"-classNameForClass: does not consult the class-wide mapping");
        [plain finishEncoding];
        [plain release];

        data = archive(nil);
        expectCodedAs(data, @"Y", @"class-wide mapping");
        expectCodedAs(archive(@"X"), @"X", @"the instance mapping takes precedence");

        [NSKeyedUnarchiver setClass:[Widget class] forClassName:@"Y"];
        expect([NSKeyedUnarchiver classForClassName:@"Y"] == [Widget class],
               @"+classForClassName: returns the class-wide mapping");
        NSKeyedUnarchiver *reader = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        expect([reader classForClassName:@"Y"] == Nil,
               @"-classForClassName: does not consult the class-wide mapping");
        [reader finishDecoding];
        [reader release];
        widget = unarchive(data, nil);
        expect([widget isKindOfClass:[Widget class]] && widget.value == 42, @"class-wide mappings round-trip");

        expect([NSKeyedUnarchiver classForClassName:@"NSString"] == Nil,
               @"+classForClassName: is nil without a mapping");
        [NSKeyedArchiver setClassName:nil forClass:[Widget class]];
        [NSKeyedUnarchiver setClass:Nil forClassName:@"Y"];
        expect([NSKeyedArchiver classNameForClass:[Widget class]] == nil &&
               [NSKeyedUnarchiver classForClassName:@"Y"] == Nil, @"nil removes class-wide mappings");
        expectCodedAs(archive(nil), @"Widget", @"after removal: real class name");
    }
    NSLog(@"PASS");
    return 0;
}
