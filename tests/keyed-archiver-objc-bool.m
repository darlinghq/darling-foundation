// Copyright (C) 2026 Lubos Dolezel
//
// A C99 bool written with -encodeValueOfObjCType:at: (type encoding "B") is archived by a keyed archiver as a boolean
// value, not as an integer, and is read back with -decodeValueOfObjCType:at:size:. macOS 26.7.3 archives it that way
// (read as a property list: the unkeyed slot holds a boolean) and so does 10.14.4. The other one-byte types (char, BOOL)
// stay integers.
#import <Foundation/Foundation.h>
#include <stdio.h>

// Darling's NSKeyedUnarchiver.h does not declare the setter of the property.
@interface NSKeyedUnarchiver (RequiresSecureCodingSetter)
- (void)setRequiresSecureCoding:(BOOL)flag;
@end

static int failures;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); failures++; } } while (0)

@interface Holder : NSObject <NSSecureCoding> { @public bool flag; bool decodedFlag; int decodedAfter; }
@end
@implementation Holder
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {
    int before = 7;
    BOOL yes = YES;
    char c = 1;
    [coder encodeValueOfObjCType:@encode(int) at:&before];
    [coder encodeValueOfObjCType:@encode(bool) at:&flag];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&yes];
    [coder encodeValueOfObjCType:@encode(char) at:&c];
}
- (id)initWithCoder:(NSCoder *)coder {
    int before = 0;
    BOOL yes = NO;
    char c = 0;
    [coder decodeValueOfObjCType:@encode(int) at:&before size:sizeof before];
    [coder decodeValueOfObjCType:@encode(bool) at:&decodedFlag size:sizeof decodedFlag];
    [coder decodeValueOfObjCType:@encode(BOOL) at:&yes size:sizeof yes];
    [coder decodeValueOfObjCType:@encode(char) at:&c size:sizeof c];
    decodedAfter = before + (yes ? 100 : 0) + (c ? 1000 : 0);
    return [super init];
}
@end

static BOOL isBoolean(id value) { return value != nil && CFGetTypeID((CFTypeRef)value) == CFBooleanGetTypeID(); }

int main(void) {
    @autoreleasepool {
        for (int value = 0; value < 2; value++) {
            Holder *h = [[[Holder alloc] init] autorelease];
            h->flag = value;
            NSData *data = nil;
            @try {
                NSKeyedArchiver *a = [[[NSKeyedArchiver alloc] initRequiringSecureCoding:YES] autorelease];
                [a encodeObject:h forKey:NSKeyedArchiveRootObjectKey];
                [a finishEncoding];
                data = [a encodedData];
            } @catch (NSException *exception) {
                printf("FAIL: encoding a C99 bool raised %s\n", [[exception reason] UTF8String]);
                return 1;
            }
            NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
            NSDictionary *object = [plist[@"$objects"] objectAtIndex:1];
            CHECK(isBoolean(object[@"$1"]) && [object[@"$1"] boolValue] == (BOOL)value);
            CHECK(!isBoolean(object[@"$0"]) && [object[@"$0"] intValue] == 7);
            CHECK(!isBoolean(object[@"$2"]) && !isBoolean(object[@"$3"]));
            NSKeyedUnarchiver *u = [[[NSKeyedUnarchiver alloc] initForReadingFromData:data error:NULL] autorelease];
            [u setRequiresSecureCoding:YES];
            Holder *back = [u decodeObjectOfClass:[Holder class] forKey:NSKeyedArchiveRootObjectKey];
            [u finishDecoding];
            CHECK(back != nil && back->decodedFlag == (bool)value && back->decodedAfter == 1107);
        }
        if (failures) { printf("%d failure(s)\n", failures); return 1; }
        printf("PASS: C99 bool in keyed archives\n");
    }
    return 0;
}
