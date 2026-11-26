#import <CoreFoundation/CFCharacterSet.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>
#import <Foundation/NSString.h>

@class NSData;

enum {
    NSOpenStepUnicodeReservedBase = 0xF400
};

@interface NSCharacterSet : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>

@property (class, readonly, copy) NSCharacterSet *controlCharacterSet;
@property (class, readonly, copy) NSCharacterSet *whitespaceCharacterSet;
@property (class, readonly, copy) NSCharacterSet *whitespaceAndNewlineCharacterSet;
@property (class, readonly, copy) NSCharacterSet *decimalDigitCharacterSet;
@property (class, readonly, copy) NSCharacterSet *letterCharacterSet;
@property (class, readonly, copy) NSCharacterSet *lowercaseLetterCharacterSet;
@property (class, readonly, copy) NSCharacterSet *uppercaseLetterCharacterSet;
@property (class, readonly, copy) NSCharacterSet *nonBaseCharacterSet;
@property (class, readonly, copy) NSCharacterSet *alphanumericCharacterSet;
@property (class, readonly, copy) NSCharacterSet *decomposableCharacterSet;
@property (class, readonly, copy) NSCharacterSet *illegalCharacterSet;
@property (class, readonly, copy) NSCharacterSet *punctuationCharacterSet;
@property (class, readonly, copy) NSCharacterSet *capitalizedLetterCharacterSet;
@property (class, readonly, copy) NSCharacterSet *symbolCharacterSet;
@property (class, readonly, copy) NSCharacterSet *newlineCharacterSet;
+ (NSCharacterSet *)characterSetWithRange:(NSRange)range;
+ (NSCharacterSet *)characterSetWithCharactersInString:(NSString *)string;
+ (NSCharacterSet *)characterSetWithBitmapRepresentation:(NSData *)data;
+ (NSCharacterSet *)characterSetWithContentsOfFile:(NSString *)path;

- (BOOL)characterIsMember:(unichar)character;
@property (readonly, copy) NSData *bitmapRepresentation;
@property (readonly, copy) NSCharacterSet *invertedSet;
- (BOOL)longCharacterIsMember:(UTF32Char)character;
- (BOOL)isSupersetOfSet:(NSCharacterSet *)other;
- (BOOL)hasMemberInPlane:(uint8_t)plane;

@end

@interface NSMutableCharacterSet : NSCharacterSet <NSCopying, NSMutableCopying>

- (void)addCharactersInRange:(NSRange)range;
- (void)removeCharactersInRange:(NSRange)range;
- (void)addCharactersInString:(NSString *)string;
- (void)removeCharactersInString:(NSString *)string;
- (void)formUnionWithCharacterSet:(NSCharacterSet *)other;
- (void)formIntersectionWithCharacterSet:(NSCharacterSet *)other;
- (void)invert;

// The same sets as NSCharacterSet's, mutable.
+ (NSMutableCharacterSet *)controlCharacterSet;
+ (NSMutableCharacterSet *)whitespaceCharacterSet;
+ (NSMutableCharacterSet *)whitespaceAndNewlineCharacterSet;
+ (NSMutableCharacterSet *)decimalDigitCharacterSet;
+ (NSMutableCharacterSet *)letterCharacterSet;
+ (NSMutableCharacterSet *)lowercaseLetterCharacterSet;
+ (NSMutableCharacterSet *)uppercaseLetterCharacterSet;
+ (NSMutableCharacterSet *)nonBaseCharacterSet;
+ (NSMutableCharacterSet *)alphanumericCharacterSet;
+ (NSMutableCharacterSet *)decomposableCharacterSet;
+ (NSMutableCharacterSet *)illegalCharacterSet;
+ (NSMutableCharacterSet *)punctuationCharacterSet;
+ (NSMutableCharacterSet *)capitalizedLetterCharacterSet;
+ (NSMutableCharacterSet *)symbolCharacterSet;
+ (NSMutableCharacterSet *)newlineCharacterSet;
+ (NSMutableCharacterSet *)characterSetWithRange:(NSRange)range;
+ (NSMutableCharacterSet *)characterSetWithCharactersInString:(NSString *)string;
+ (NSMutableCharacterSet *)characterSetWithBitmapRepresentation:(NSData *)data;
+ (NSMutableCharacterSet *)characterSetWithContentsOfFile:(NSString *)path;

@end
