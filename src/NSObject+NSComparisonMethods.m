/** Implementation of NSObject+NSComparisonMethods for GNUStep
   Copyright (C) 2008 Free Software Foundation, Inc.
   Written by:  Gregory Casamento <greg_casamento@yahoo.com>
   Date: 2008
   This file is part of the GNUstep Base Library.
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   <title>NSObject+NSComparisonMethods category reference</title>
   $Date: 2008-11-26 04:20:34 -0500 (Wed, 26 Nov 2008) $ $Revision: 27135 $
*/

#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>

@interface NSObject (NSComparisonMethods)
- (BOOL) doesContain: (id) object;
- (BOOL) isCaseInsensitiveLike: (NSString *)object;
- (BOOL) isEqualTo: (id) object;
- (BOOL) isGreaterThan: (id) object;
- (BOOL) isGreaterThanOrEqualTo: (id) object;
- (BOOL) isLessThan: (id) object;
- (BOOL) isLessThanOrEqualTo: (id) object;
- (BOOL) isLike: (NSString *)object;
- (BOOL) isNotEqualTo: (id) object;
@end

@interface NSString (NSComparisonMethods)
- (BOOL) isCaseInsensitiveLike: (NSString *)object;
- (BOOL) isLike: (NSString *)object;
@end

@implementation NSObject (NSComparisonMethods)
- (BOOL) doesContain: (id) object
{
  if (object)
    {
      if ([self isKindOfClass: [NSArray class]])
	{
	  return [(NSArray *)self indexOfObjectIdenticalTo: object] != NSNotFound;
	}
    }
  return NO;
}

- (BOOL) isCaseInsensitiveLike: (NSString *)object
{
  return NO;
}

- (BOOL) isEqualTo: (id) object
{
  return [self isEqual: object];
}

- (BOOL) isGreaterThan: (id) object
{
  return ([self compare: object] == NSOrderedDescending);
}

- (BOOL) isGreaterThanOrEqualTo: (id) object
{
  return ([self compare: object] == NSOrderedDescending ||
	  [self compare: object] == NSOrderedSame);
}

- (BOOL) isLessThan: (id) object
{
  return ([self compare: object] == NSOrderedAscending);
}

- (BOOL) isLessThanOrEqualTo: (id) object
{
  return ([self compare: object] == NSOrderedAscending ||
	  [self compare: object] == NSOrderedSame);
}

- (BOOL) isLike: (NSString *)object
{
  return NO;
}

- (BOOL) isNotEqualTo: (id) object
{
  return !([self isEqual: object]);
}
@end

/* The simple shell wildcards of -isLike: are '*' (any run of characters,
   possibly empty) and '?' (exactly one character), and the whole receiver
   must match.  The public NSScriptWhoseTests.h comment names these two
   and nothing else, so nothing else is special.
   GUESS: a "character" is a composed character sequence, so '?' does not
   match half of a surrogate pair or a base letter without its accent.
   GUESS: there is no escape for '*' and '?'.
   GUESS: other characters match literally, so canonically equivalent
   spellings (precomposed and decomposed) are different.  The
   case-insensitive form folds case per character sequence with
   NSCaseInsensitiveSearch.
   GUESS: a nil or non-string pattern yields NO. */
static NSArray *characterSequences(NSString *string)
{
  NSMutableArray *sequences = [NSMutableArray array];
  NSUInteger length = [string length];
  NSUInteger index = 0;

  while (index < length)
    {
      NSRange range = [string rangeOfComposedCharacterSequenceAtIndex: index];

      [sequences addObject: [string substringWithRange: range]];
      index = NSMaxRange(range);
    }
  return sequences;
}

static BOOL matchesWildcardPattern(NSString *string, NSString *pattern,
  NSStringCompareOptions options)
{
  NSArray *text = characterSequences(string);
  NSArray *tokens = characterSequences(pattern);
  NSUInteger textCount = [text count];
  NSUInteger tokenCount = [tokens count];
  NSUInteger t = 0;
  NSUInteger p = 0;
  /* Where the last '*' sits in the pattern and how much text it has
     swallowed so far; NSNotFound until a '*' has been seen. */
  NSUInteger starToken = NSNotFound;
  NSUInteger starText = 0;

  while (t < textCount)
    {
      NSString *token = p < tokenCount ? [tokens objectAtIndex: p] : nil;

      if ([token isEqualToString: @"*"])
	{
	  starToken = p++;
	  starText = t;
	}
      else if (token != nil
	&& ([token isEqualToString: @"?"]
	  || [[text objectAtIndex: t] compare: token options: options]
	    == NSOrderedSame))
	{
	  t++;
	  p++;
	}
      else if (starToken != NSNotFound)
	{
	  p = starToken + 1;
	  t = ++starText;
	}
      else
	{
	  return NO;
	}
    }
  while (p < tokenCount && [[tokens objectAtIndex: p] isEqualToString: @"*"])
    {
      p++;
    }
  return p == tokenCount;
}

@implementation NSString (NSComparisonMethods)
- (BOOL) isCaseInsensitiveLike: (NSString *)object
{
  if (![object isKindOfClass: [NSString class]])
    {
      return NO;
    }
  return matchesWildcardPattern(self, object,
    NSLiteralSearch | NSCaseInsensitiveSearch);
}

- (BOOL) isLike: (NSString *)object
{
  if (![object isKindOfClass: [NSString class]])
    {
      return NO;
    }
  return matchesWildcardPattern(self, object, NSLiteralSearch);
}
@end
