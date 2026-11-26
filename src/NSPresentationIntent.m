/*
 This file is part of Darling.

 Copyright (C) 2026 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

// NSPresentationIntent (Apple's NSPresentationIntent reference, macOS 12): an
// immutable description of the block a run of text belongs to (a paragraph, a
// header, a list item, a table cell, ...), linked to the blocks around it.

#import <Foundation/NSAttributedString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSException.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSValue.h>

// The key is stored in archives and AttributedString encodings, so it must
// match macOS. Source: swift-foundation's PresentationIntent attribute name.
NSAttributedStringKey const NSPresentationIntentAttributeName = @"NSPresentationIntent";

@implementation NSPresentationIntent

- (instancetype)_initWithKind:(NSPresentationIntentKind)kind identity:(NSInteger)identity value:(NSInteger)value parent:(NSPresentationIntent *)parent {
    self = [super init];
    if (self) {
        _kind = kind;
        _identity = identity;
        _value = value;
        _parent = [parent retain];
    }
    return self;
}

+ (NSPresentationIntent *)_intentWithKind:(NSPresentationIntentKind)kind identity:(NSInteger)identity value:(NSInteger)value parent:(NSPresentationIntent *)parent {
    return [[[self alloc] _initWithKind:kind identity:identity value:value parent:parent] autorelease];
}

- (void)dealloc {
    [_parent release];
    [_languageHint release];
    [_columnAlignments release];
    [super dealloc];
}

+ (NSPresentationIntent *)paragraphIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent {
    return [self _intentWithKind:NSPresentationIntentKindParagraph identity:identity value:0 parent:parent];
}

+ (NSPresentationIntent *)headerIntentWithIdentity:(NSInteger)identity level:(NSInteger)level nestedInsideIntent:(NSPresentationIntent *)parent {
    return [self _intentWithKind:NSPresentationIntentKindHeader identity:identity value:level parent:parent];
}

+ (NSPresentationIntent *)codeBlockIntentWithIdentity:(NSInteger)identity languageHint:(NSString *)languageHint nestedInsideIntent:(NSPresentationIntent *)parent {
    NSPresentationIntent *intent = [self _intentWithKind:NSPresentationIntentKindCodeBlock identity:identity value:0 parent:parent];
    intent->_languageHint = [languageHint copy];
    return intent;
}

+ (NSPresentationIntent *)thematicBreakIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent {
    return [self _intentWithKind:NSPresentationIntentKindThematicBreak identity:identity value:0 parent:parent];
}

+ (NSPresentationIntent *)orderedListIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent {
    return [self _intentWithKind:NSPresentationIntentKindOrderedList identity:identity value:0 parent:parent];
}

+ (NSPresentationIntent *)unorderedListIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent {
    return [self _intentWithKind:NSPresentationIntentKindUnorderedList identity:identity value:0 parent:parent];
}

+ (NSPresentationIntent *)listItemIntentWithIdentity:(NSInteger)identity ordinal:(NSInteger)ordinal nestedInsideIntent:(NSPresentationIntent *)parent {
    return [self _intentWithKind:NSPresentationIntentKindListItem identity:identity value:ordinal parent:parent];
}

+ (NSPresentationIntent *)blockQuoteIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent {
    return [self _intentWithKind:NSPresentationIntentKindBlockQuote identity:identity value:0 parent:parent];
}

+ (NSPresentationIntent *)tableIntentWithIdentity:(NSInteger)identity columnCount:(NSInteger)columnCount alignments:(NSArray<NSNumber *> *)alignments nestedInsideIntent:(NSPresentationIntent *)parent {
    NSPresentationIntent *intent = [self _intentWithKind:NSPresentationIntentKindTable identity:identity value:columnCount parent:parent];
    intent->_columnAlignments = [alignments copy];
    return intent;
}

+ (NSPresentationIntent *)tableHeaderRowIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent {
    return [self _intentWithKind:NSPresentationIntentKindTableHeaderRow identity:identity value:0 parent:parent];
}

+ (NSPresentationIntent *)tableRowIntentWithIdentity:(NSInteger)identity row:(NSInteger)row nestedInsideIntent:(NSPresentationIntent *)parent {
    return [self _intentWithKind:NSPresentationIntentKindTableRow identity:identity value:row parent:parent];
}

+ (NSPresentationIntent *)tableCellIntentWithIdentity:(NSInteger)identity column:(NSInteger)column nestedInsideIntent:(NSPresentationIntent *)parent {
    return [self _intentWithKind:NSPresentationIntentKindTableCell identity:identity value:column parent:parent];
}

- (NSPresentationIntentKind)intentKind {
    return _kind;
}

- (NSPresentationIntent *)parentIntent {
    return _parent;
}

- (NSInteger)identity {
    return _identity;
}

// The kind-specific values are 0 (or nil) for an intent of another kind.

- (NSInteger)ordinal {
    return _kind == NSPresentationIntentKindListItem ? _value : 0;
}

- (NSInteger)headerLevel {
    return _kind == NSPresentationIntentKindHeader ? _value : 0;
}

- (NSInteger)columnCount {
    return _kind == NSPresentationIntentKindTable ? _value : 0;
}

- (NSInteger)row {
    return _kind == NSPresentationIntentKindTableRow ? _value : 0;
}

- (NSInteger)column {
    return _kind == NSPresentationIntentKindTableCell ? _value : 0;
}

- (NSString *)languageHint {
    return _languageHint;
}

- (NSArray<NSNumber *> *)columnAlignments {
    return _columnAlignments;
}

// The number of enclosing lists and block quotes. The reference only says
// that it is the intent's indentation level; counting the blocks that indent
// their contents is our reading of that.
- (NSInteger)indentationLevel {
    NSInteger level = 0;
    for (NSPresentationIntent *intent = self; intent != nil; intent = intent->_parent) {
        switch (intent->_kind) {
        case NSPresentationIntentKindOrderedList:
        case NSPresentationIntentKindUnorderedList:
        case NSPresentationIntentKindBlockQuote:
            level++;
            break;
        default:
            break;
        }
    }
    return level;
}

static BOOL objectsEqual(id a, id b) {
    return a == b || [a isEqual:b];
}

// Same kind, same kind-specific values and equivalent parents; the identities
// may differ.
- (BOOL)isEquivalentToPresentationIntent:(NSPresentationIntent *)other {
    NSPresentationIntent *a = self, *b = other;
    while (a != nil && b != nil) {
        if (a->_kind != b->_kind || a->_value != b->_value
            || !objectsEqual(a->_languageHint, b->_languageHint)
            || !objectsEqual(a->_columnAlignments, b->_columnAlignments))
            return NO;
        a = a->_parent;
        b = b->_parent;
    }
    return a == nil && b == nil;
}

- (BOOL)isEqual:(id)object {
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSPresentationIntent class]])
        return NO;
    NSPresentationIntent *other = object;
    return _identity == other->_identity && [self isEquivalentToPresentationIntent:other]
        && objectsEqual(_parent, other->_parent);
}

- (NSUInteger)hash {
    return (NSUInteger)_identity * 31 + (NSUInteger)_kind;
}

- (id)copyWithZone:(NSZone *)zone {
    // immutable
    return [self retain];
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

// The archive keys are Darling's own: an intent archived on macOS may not
// decode here, nor the other way round.
- (void)encodeWithCoder:(NSCoder *)coder {
    if (![coder allowsKeyedCoding])
        [NSException raise:NSInvalidArgumentException format:@"NSPresentationIntent can only be encoded by a keyed coder"];
    [coder encodeInteger:_kind forKey:@"kind"];
    [coder encodeInteger:_identity forKey:@"identity"];
    [coder encodeInteger:_value forKey:@"value"];
    [coder encodeObject:_parent forKey:@"parent"];
    [coder encodeObject:_languageHint forKey:@"languageHint"];
    [coder encodeObject:_columnAlignments forKey:@"columnAlignments"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (![coder allowsKeyedCoding]) {
        [self release];
        [NSException raise:NSInvalidArgumentException format:@"NSPresentationIntent can only be decoded by a keyed coder"];
        return nil;
    }
    NSInteger kind = [coder decodeIntegerForKey:@"kind"];
    if (kind < NSPresentationIntentKindParagraph || kind > NSPresentationIntentKindTableCell) {
        [self release];
        return nil;
    }
    NSPresentationIntent *parent = [coder decodeObjectOfClass:[NSPresentationIntent class] forKey:@"parent"];
    self = [self _initWithKind:kind identity:[coder decodeIntegerForKey:@"identity"]
                         value:[coder decodeIntegerForKey:@"value"] parent:parent];
    if (self) {
        _languageHint = [[coder decodeObjectOfClass:[NSString class] forKey:@"languageHint"] copy];
        NSSet *classes = [NSSet setWithObjects:[NSArray class], [NSNumber class], nil];
        _columnAlignments = [[coder decodeObjectOfClasses:classes forKey:@"columnAlignments"] copy];
    }
    return self;
}

@end
