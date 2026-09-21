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

- (NSDictionary<NSAttributedStringKey, id> * _Nonnull)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRangePointer)range;

@end

// Declared on the category that implements it, not on the primary interface: -string is a class
// cluster primitive, and a primary-interface property would auto-synthesize an _string ivar.
@interface NSAttributedString (NSAttributedString)

@property (readonly, copy) NSString * _Nonnull string;

@end

@interface NSAttributedString (NSExtendedAttributedString)

@property (readonly) NSUInteger length;
- (id)attribute:(NSAttributedStringKey)attrName atIndex:(NSUInteger)index effectiveRange:(NSRangePointer)range;
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range;
- (NSDictionary<NSAttributedStringKey, id> * _Nonnull)attributesAtIndex:(NSUInteger)index longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit;
- (id)attribute:(NSAttributedStringKey)attrName atIndex:(NSUInteger)index longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit;
- (BOOL)isEqualToAttributedString:(NSAttributedString *)other;
- (nonnull instancetype)initWithString:(nonnull NSString *)str;
- (nonnull instancetype)initWithString:(nonnull NSString *)str attributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attrs;
- (nonnull instancetype)initWithAttributedString:(nonnull NSAttributedString *)attrStr;
#if NS_BLOCKS_AVAILABLE
- (void)enumerateAttributesInRange:(NSRange)enumerationRange options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(NSDictionary<NSAttributedStringKey, id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop))block;
- (void)enumerateAttribute:(NSAttributedStringKey)attrName inRange:(NSRange)enumerationRange options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (^)(id value, NSRange range, BOOL * _Nonnull stop))block;
#endif

@end

@interface NSMutableAttributedString : NSAttributedString

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str;
- (void)setAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs range:(NSRange)range;

@end

@interface NSMutableAttributedString (NSExtendedMutableAttributedString)

- (NSMutableString *)mutableString;
- (void)addAttribute:(NSAttributedStringKey)name value:(id)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs range:(NSRange)range;
- (void)removeAttribute:(NSAttributedStringKey)name range:(NSRange)range;
- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)attrString;
- (void)insertAttributedString:(NSAttributedString *)attrString atIndex:(NSUInteger)loc;
- (void)appendAttributedString:(NSAttributedString *)attrString;
- (void)deleteCharactersInRange:(NSRange)range;
- (void)setAttributedString:(NSAttributedString *)attrString;
- (void)beginEditing;
- (void)endEditing;

@end
