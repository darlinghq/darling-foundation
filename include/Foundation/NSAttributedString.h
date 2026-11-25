#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>

typedef NS_OPTIONS(NSUInteger, NSAttributedStringEnumerationOptions) {
    NSAttributedStringEnumerationReverse                          = (1UL << 1),
    NSAttributedStringEnumerationLongestEffectiveRangeNotRequired = (1UL << 20)
};

// The type modern headers use for attribute dictionary keys.
typedef NSString *NSAttributedStringKey NS_TYPED_EXTENSIBLE_ENUM;

// Values as published in dotnet/macios src/Foundation/Enums.cs (MIT), generated from Apple's SDK headers.
typedef NS_OPTIONS(NSUInteger, NSAttributedStringFormattingOptions) {
    NSAttributedStringFormattingInsertArgumentAttributesWithoutMerging = 1 << 0,
    NSAttributedStringFormattingApplyReplacementIndexAttribute = 1 << 1,
};

@class NSLocale;

@interface NSAttributedString : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>

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

// Value: an NSNumber with the 1-based argument position of a formatted replacement.
FOUNDATION_EXPORT const NSAttributedStringKey NSReplacementIndexAttributeName NS_SWIFT_NAME(replacementIndex);

@interface NSAttributedString (NSAttributedStringFormatting)

- (instancetype)initWithFormat:(NSAttributedString *)format options:(NSAttributedStringFormattingOptions)options locale:(NSLocale *)locale, ...;
- (instancetype)initWithFormat:(NSAttributedString *)format options:(NSAttributedStringFormattingOptions)options locale:(NSLocale *)locale arguments:(va_list)arguments;
+ (instancetype)localizedAttributedStringWithFormat:(NSAttributedString *)format, ...;
+ (instancetype)localizedAttributedStringWithFormat:(NSAttributedString *)format options:(NSAttributedStringFormattingOptions)options, ...;

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

typedef NS_OPTIONS(NSUInteger, NSInlinePresentationIntent) {
    NSInlinePresentationIntentEmphasized         = 1 << 0,
    NSInlinePresentationIntentStronglyEmphasized = 1 << 1,
    NSInlinePresentationIntentCode               = 1 << 2,
    NSInlinePresentationIntentStrikethrough      = 1 << 5,
    NSInlinePresentationIntentSoftBreak          = 1 << 6,
    NSInlinePresentationIntentLineBreak          = 1 << 7,
    NSInlinePresentationIntentInlineHTML         = 1 << 8,
    NSInlinePresentationIntentBlockHTML          = 1 << 9
} NS_SWIFT_NAME(InlinePresentationIntent);

// Value: an NSNumber wrapping an NSInlinePresentationIntent.
FOUNDATION_EXPORT const NSAttributedStringKey NSInlinePresentationIntentAttributeName NS_SWIFT_NAME(inlinePresentationIntent);
// Value: an NSString holding a BCP-47 language identifier.
FOUNDATION_EXPORT const NSAttributedStringKey NSLanguageIdentifierAttributeName NS_SWIFT_NAME(languageIdentifier);

NS_ASSUME_NONNULL_BEGIN

@class NSArray<ObjectType>, NSNumber;

typedef NS_ENUM(NSInteger, NSPresentationIntentKind) {
    NSPresentationIntentKindParagraph,
    NSPresentationIntentKindHeader,
    NSPresentationIntentKindOrderedList,
    NSPresentationIntentKindUnorderedList,
    NSPresentationIntentKindListItem,
    NSPresentationIntentKindCodeBlock,
    NSPresentationIntentKindBlockQuote,
    NSPresentationIntentKindThematicBreak,
    NSPresentationIntentKindTable,
    NSPresentationIntentKindTableHeaderRow,
    NSPresentationIntentKindTableRow,
    NSPresentationIntentKindTableCell
};

typedef NS_ENUM(NSInteger, NSPresentationIntentTableColumnAlignment) {
    NSPresentationIntentTableColumnAlignmentLeft,
    NSPresentationIntentTableColumnAlignmentCenter,
    NSPresentationIntentTableColumnAlignmentRight
};

// The block-level role of a run of text (a paragraph, a list item, ...) and
// the blocks that enclose it.
@interface NSPresentationIntent : NSObject <NSCopying, NSSecureCoding> {
    // here, not in the implementation, as i386 has no non-fragile ivars
    NSPresentationIntentKind _kind;
    NSPresentationIntent *_parent;
    NSInteger _identity;
    // the kind's own value: a header's level, a list item's ordinal, a table
    // row's row, a table cell's column or a table's column count
    NSInteger _value;
    NSString *_languageHint;
    NSArray<NSNumber *> *_columnAlignments;
}

@property (readonly) NSPresentationIntentKind intentKind;
@property (readonly, nullable, strong) NSPresentationIntent *parentIntent;

+ (NSPresentationIntent *)paragraphIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)headerIntentWithIdentity:(NSInteger)identity level:(NSInteger)level nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)codeBlockIntentWithIdentity:(NSInteger)identity languageHint:(nullable NSString *)languageHint nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)thematicBreakIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)orderedListIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)unorderedListIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)listItemIntentWithIdentity:(NSInteger)identity ordinal:(NSInteger)ordinal nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)blockQuoteIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)tableIntentWithIdentity:(NSInteger)identity columnCount:(NSInteger)columnCount alignments:(NSArray<NSNumber *> *)alignments nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)tableHeaderRowIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)tableRowIntentWithIdentity:(NSInteger)identity row:(NSInteger)row nestedInsideIntent:(nullable NSPresentationIntent *)parent;
+ (NSPresentationIntent *)tableCellIntentWithIdentity:(NSInteger)identity column:(NSInteger)column nestedInsideIntent:(nullable NSPresentationIntent *)parent;

@property (readonly) NSInteger identity;
@property (readonly) NSInteger ordinal;
@property (readonly, nullable) NSArray<NSNumber *> *columnAlignments;
@property (readonly) NSInteger columnCount;
@property (readonly) NSInteger headerLevel;
@property (readonly, nullable, copy) NSString *languageHint;
@property (readonly) NSInteger column;
@property (readonly) NSInteger row;
@property (readonly) NSInteger indentationLevel;

- (BOOL)isEquivalentToPresentationIntent:(NSPresentationIntent *)other;

@end

// Value: an NSPresentationIntent.
FOUNDATION_EXPORT const NSAttributedStringKey NSPresentationIntentAttributeName NS_SWIFT_NAME(presentationIntent);

NS_ASSUME_NONNULL_END

@interface NSMutableAttributedString (NSMutableAttributedStringFormatting)

- (void)appendLocalizedFormat:(NSAttributedString *)format, ...;

@end
