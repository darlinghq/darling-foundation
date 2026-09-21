#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

typedef NS_OPTIONS(NSUInteger, NSAttributedStringEnumerationOptions) {
    NSAttributedStringEnumerationReverse                          = (1UL << 1),
    NSAttributedStringEnumerationLongestEffectiveRangeNotRequired = (1UL << 20)
};

// The type modern headers use for attribute dictionary keys.
typedef NSString *NSAttributedStringKey NS_TYPED_EXTENSIBLE_ENUM;

// Declared with no options, deliberately. This type exists so that declarations taking it can be
// parsed; its option bit values are not publicly derivable. That is absence of knowledge, not
// knowledge that the type has no options -- do not read the lack of members as a statement that
// there are none. Inventing a bit would compile cleanly and misbehave at runtime, whereas with
// nothing declared any use of an option is a compile error naming the option that is missing.
// Apple declares this as an NS_OPTIONS; a memberless NS_OPTIONS is not legal C, hence the plain
// typedef. When a verified reference is available, restore the NS_OPTIONS form and add the
// members from it -- never from memory.
typedef NSUInteger NSAttributedStringFormattingOptions;

@interface NSAttributedString : NSObject <NSCopying, NSMutableCopying, NSCoding>

- (NSString *)string;
- (NSDictionary *)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)range;

@end

@interface NSAttributedString (NSExtendedAttributedString)

- (NSUInteger)length;
- (id)attribute:(NSString *)attrName atIndex:(NSUInteger)index effectiveRange:(NSRangePointer)range;
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range;
- (NSDictionary *)attributesAtIndex:(NSUInteger)index longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit;
- (id)attribute:(NSString *)attrName atIndex:(NSUInteger)index longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit;
- (BOOL)isEqualToAttributedString:(NSAttributedString *)other;
- (nonnull instancetype)initWithString:(nonnull NSString *)str;
- (nonnull instancetype)initWithString:(nonnull NSString *)str attributes:(nullable NSDictionary *)attrs;
- (nonnull instancetype)initWithAttributedString:(nonnull NSAttributedString *)attrStr;
#if NS_BLOCKS_AVAILABLE
- (void)enumerateAttributesInRange:(NSRange)enumerationRange options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(NSDictionary * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop))block;
- (void)enumerateAttribute:(NSString *)attrName inRange:(NSRange)enumerationRange options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(id value, NSRange range, BOOL * _Nonnull stop))block;
#endif

@end

@interface NSMutableAttributedString : NSAttributedString

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str;
- (void)setAttributes:(NSDictionary *)attrs range:(NSRange)range;

@end

@interface NSMutableAttributedString (NSExtendedMutableAttributedString)

- (NSMutableString *)mutableString;
- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary *)attrs range:(NSRange)range;
- (void)removeAttribute:(NSString *)name range:(NSRange)range;
- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)attrString;
- (void)insertAttributedString:(NSAttributedString *)attrString atIndex:(NSUInteger)loc;
- (void)appendAttributedString:(NSAttributedString *)attrString;
- (void)deleteCharactersInRange:(NSRange)range;
- (void)setAttributedString:(NSAttributedString *)attrString;
- (void)beginEditing;
- (void)endEditing;

@end
