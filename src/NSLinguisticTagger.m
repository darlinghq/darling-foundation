/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#import <Foundation/NSLinguisticTagger.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSRange.h>

NSString *const NSLinguisticTagSchemeTokenType = @"TokenType";
NSString *const NSLinguisticTagSchemeLexicalClass = @"LexicalClass";
NSString *const NSLinguisticTagSchemeNameType = @"NameType";
NSString *const NSLinguisticTagSchemeNameTypeOrLexicalClass = @"NameTypeOrLexicalClass";
NSString *const NSLinguisticTagSchemeLemma = @"Lemma";
NSString *const NSLinguisticTagSchemeLanguage = @"Language";
NSString *const NSLinguisticTagSchemeScript = @"Script";
NSString *const NSLinguisticTagWord = @"Word";
NSString *const NSLinguisticTagPunctuation = @"Punctuation";
NSString *const NSLinguisticTagWhitespace = @"Whitespace";
NSString *const NSLinguisticTagOther = @"Other";
NSString *const NSLinguisticTagNoun = @"Noun";
NSString *const NSLinguisticTagVerb = @"Verb";
NSString *const NSLinguisticTagAdjective = @"Adjective";
NSString *const NSLinguisticTagAdverb = @"Adverb";
NSString *const NSLinguisticTagPronoun = @"Pronoun";
NSString *const NSLinguisticTagDeterminer = @"Determiner";
NSString *const NSLinguisticTagParticle = @"Particle";
NSString *const NSLinguisticTagPreposition = @"Preposition";
NSString *const NSLinguisticTagNumber = @"Number";
NSString *const NSLinguisticTagConjunction = @"Conjunction";
NSString *const NSLinguisticTagInterjection = @"Interjection";
NSString *const NSLinguisticTagClassifier = @"Classifier";
NSString *const NSLinguisticTagIdiom = @"Idiom";
NSString *const NSLinguisticTagOtherWord = @"OtherWord";
NSString *const NSLinguisticTagSentenceTerminator = @"SentenceTerminator";
NSString *const NSLinguisticTagOpenQuote = @"OpenQuote";
NSString *const NSLinguisticTagCloseQuote = @"CloseQuote";
NSString *const NSLinguisticTagOpenParenthesis = @"OpenParenthesis";
NSString *const NSLinguisticTagCloseParenthesis = @"CloseParenthesis";
NSString *const NSLinguisticTagWordJoiner = @"WordJoiner";
NSString *const NSLinguisticTagDash = @"Dash";
NSString *const NSLinguisticTagOtherPunctuation = @"Punctuation";
NSString *const NSLinguisticTagParagraphBreak = @"ParagraphBreak";
NSString *const NSLinguisticTagOtherWhitespace = @"Whitespace";
NSString *const NSLinguisticTagPersonalName = @"PersonalName";
NSString *const NSLinguisticTagPlaceName = @"PlaceName";
NSString *const NSLinguisticTagOrganizationName = @"OrganizationName";

@implementation NSLinguisticTagger

+ (NSArray *)availableTagSchemesForLanguage:(NSString *)language
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
    return nil;
}

- (id)initWithTagSchemes:(NSArray *)tagSchemes options:(NSUInteger)opts
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
    return nil;
}

- (NSArray *)tagSchemes
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
    return nil;
}

- (void)setString:(NSString *)string
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
}

- (NSString *)string
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
    return nil;
}

- (void)setOrthography:(NSOrthography *)orthography range:(NSRange)range
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
}

- (NSOrthography *)orthographyAtIndex:(NSUInteger)charIndex effectiveRange:(NSRangePointer)effectiveRange
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
    return nil;
}

- (void)stringEditedInRange:(NSRange)newRange changeInLength:(NSInteger)delta
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
}

#if NS_BLOCKS_AVAILABLE
- (void)enumerateTagsInRange:(NSRange)range scheme:(NSString *)tagScheme options:(NSLinguisticTaggerOptions)opts usingBlock:(void (^)(NSString *tag, NSRange tokenRange, NSRange sentenceRange, BOOL *stop))block
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
}

#endif
- (NSRange)sentenceRangeForRange:(NSRange)range
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
    return NSMakeRange(0, 0);
}

- (NSString *)tagAtIndex:(NSUInteger)charIndex scheme:(NSString *)tagScheme tokenRange:(NSRangePointer)tokenRange sentenceRange:(NSRangePointer)sentenceRange
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
    return nil;
}

- (NSArray *)tagsInRange:(NSRange)range scheme:(NSString *)tagScheme options:(NSLinguisticTaggerOptions)opts tokenRanges:(NSArray **)tokenRanges
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
    return nil;
}

- (NSArray *)possibleTagsAtIndex:(NSUInteger)charIndex scheme:(NSString *)tagScheme tokenRange:(NSRangePointer)tokenRange sentenceRange:(NSRangePointer)sentenceRange scores:(NSArray **)scores
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
    return nil;
}

@end

@implementation NSString (NSLinguisticAnalysis)

- (NSArray *)linguisticTagsInRange:(NSRange)range scheme:(NSString *)tagScheme options:(NSLinguisticTaggerOptions)opts orthography:(NSOrthography *)orthography tokenRanges:(NSArray **)tokenRanges
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
    return nil;
}

#if NS_BLOCKS_AVAILABLE
- (void)enumerateLinguisticTagsInRange:(NSRange)range scheme:(NSString *)tagScheme options:(NSLinguisticTaggerOptions)opts orthography:(NSOrthography *)orthography usingBlock:(void (^)(NSString *tag, NSRange tokenRange, NSRange sentenceRange, BOOL *stop))block
{
    NSLog(@"STUB: [%@ %@]", [self description], NSStringFromSelector(_cmd));
}

#endif

@end
