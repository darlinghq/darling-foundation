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
#import <Foundation/NSException.h>

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

/* -isLike: and -isCaseInsensitiveLike: take a shell-style pattern.  The
   public documentation (NSScriptWhoseTests.h) names '*' and '?' and gives
   "Stev*" and "N?XT" as examples; it does not describe anything else.

   QUIRK: the pattern language and the unit of matching go beyond the
   documented wildcards.  Observed on macOS 26.7.3 and 10.14.4 (x86_64),
   identical on both (evidence tier 2, black-box observation through the
   public API):
   - '*' matches any run of UTF-16 units (including none and including a
     newline), '?' matches exactly one UTF-16 unit, not one composed
     character: "e" followed by a combining accent matches "??" and not "?",
     and a surrogate pair needs "??".
   - '[' starts a character class that ends at the first unescaped ']'.  It
     holds units and "lo-hi" ranges; "[a-]" and "[-a]" take the '-' as itself;
     "[]" is an empty class and matches nothing.  There is no negation: '!'
     and '^' are ordinary members.  A class matches one unit.
   - '\' makes the next unit ordinary, inside and outside a class.  A '\' that
     ends the pattern matches nothing.
   - everything else, composed or not, matches itself unit by unit: the
     precomposed and decomposed spellings of a letter are different.
   - a class that is not closed (also "[a-") raises
     NSInternalInconsistencyException when the match reaches it.
   - a nil pattern gives NO; a pattern that is not a string raises
     NSInvalidArgumentException (the pattern is sent -length).
   - for the case-insensitive form, plain units compare case-insensitively on
     both sides; for a class the pattern's members are lowercased and the
     receiver's unit is compared as it is, so [A-C] matches "b" but not "B".
   Test: test_quirk_islike_* in tests/nsstring-is-like.m. */
typedef NS_ENUM(NSInteger, LikeTokenKind) {
  LikeTokenStar,
  LikeTokenAny,
  LikeTokenUnit,
  LikeTokenClass,
  LikeTokenNever,
  LikeTokenBadClass
};

typedef struct {
  LikeTokenKind kind;
  unichar unit;        // LikeTokenUnit
  NSUInteger first;    // LikeTokenClass: first range in the shared range list
  NSUInteger count;    // LikeTokenClass: number of ranges
} LikeToken;

typedef struct {
  unichar low;
  unichar high;
} LikeRange;

static unichar likeLowercase(unichar unit)
{
  if (unit < 0x80)
    {
      return (unit >= 'A' && unit <= 'Z') ? (unichar)(unit + ('a' - 'A')) : unit;
    }

  NSString *single = [NSString stringWithCharacters: &unit length: 1];
  NSString *lowered = [single lowercaseString];

  return [lowered length] == 1 ? [lowered characterAtIndex: 0] : unit;
}

static BOOL likeUnitsEqual(unichar a, unichar b, BOOL caseInsensitive)
{
  if (a == b)
    {
      return YES;
    }
  if (!caseInsensitive)
    {
      return NO;
    }
  if (a < 0x80 && b < 0x80)
    {
      return likeLowercase(a) == likeLowercase(b);
    }

  NSString *left = [NSString stringWithCharacters: &a length: 1];
  NSString *right = [NSString stringWithCharacters: &b length: 1];

  return [left compare: right
	       options: NSCaseInsensitiveSearch | NSLiteralSearch] == NSOrderedSame;
}

// Splits the pattern into tokens; ranges of all classes go to *ranges.
static LikeToken *likeTokenize(const unichar *pattern, NSUInteger length,
  BOOL caseInsensitive, NSUInteger *tokenCount, LikeRange **ranges)
{
  LikeToken *tokens = calloc(length + 1, sizeof(LikeToken));
  *ranges = calloc(length + 1, sizeof(LikeRange));
  NSUInteger rangeCount = 0;
  NSUInteger count = 0;
  NSUInteger i = 0;

  if (tokens == NULL || *ranges == NULL)
    {
      free(tokens);
      free(*ranges);
      [NSException raise: NSMallocException format: @"Could not allocate buffer"];
    }

  while (i < length)
    {
      unichar unit = pattern[i++];
      LikeToken *token = &tokens[count++];

      if (unit == '*')
	{
	  token->kind = LikeTokenStar;
	}
      else if (unit == '?')
	{
	  token->kind = LikeTokenAny;
	}
      else if (unit == '\\')
	{
	  if (i == length)
	    {
	      token->kind = LikeTokenNever;
	    }
	  else
	    {
	      token->kind = LikeTokenUnit;
	      token->unit = pattern[i++];
	    }
	}
      else if (unit == '[')
	{
	  token->kind = LikeTokenClass;
	  token->first = rangeCount;
	  BOOL closed = NO;

	  while (i < length)
	    {
	      unichar low = pattern[i++];

	      if (low == ']')
		{
		  closed = YES;
		  break;
		}
	      if (low == '\\')
		{
		  if (i == length)
		    {
		      break;
		    }
		  low = pattern[i++];
		}

	      unichar high = low;

	      if (i + 1 < length && pattern[i] == '-' && pattern[i + 1] != ']')
		{
		  i++;
		  high = pattern[i++];
		  if (high == '\\')
		    {
		      if (i == length)
			{
			  break;
			}
		      high = pattern[i++];
		    }
		}
	      else if (i < length && pattern[i] == '-' && i + 1 == length)
		{
		  // "[a-" with nothing after the dash is not a complete class.
		  break;
		}
	      if (caseInsensitive)
		{
		  low = likeLowercase(low);
		  high = likeLowercase(high);
		}
	      (*ranges)[rangeCount].low = low;
	      (*ranges)[rangeCount].high = high;
	      rangeCount++;
	    }
	  token->count = rangeCount - token->first;
	  if (!closed)
	    {
	      token->kind = LikeTokenBadClass;
	    }
	}
      else
	{
	  token->kind = LikeTokenUnit;
	  token->unit = unit;
	}
    }
  *tokenCount = count;
  return tokens;
}

static BOOL likeTokenMatches(const LikeToken *token, const LikeRange *ranges,
  unichar unit, BOOL caseInsensitive)
{
  switch (token->kind)
    {
      case LikeTokenAny:
	return YES;
      case LikeTokenUnit:
	return likeUnitsEqual(unit, token->unit, caseInsensitive);
      case LikeTokenClass:
	for (NSUInteger r = 0; r < token->count; r++)
	  {
	    const LikeRange *range = &ranges[token->first + r];

	    if (unit >= range->low && unit <= range->high)
	      {
		return YES;
	      }
	  }
	return NO;
      case LikeTokenBadClass:
	[NSException raise: NSInternalInconsistencyException
		    format: @"The pattern has a character class that is not closed"];
	return NO;
      default:
	return NO;
    }
}

static BOOL likeMatches(NSString *string, NSString *pattern, BOOL caseInsensitive)
{
  NSUInteger textLength = [string length];
  NSUInteger patternLength = [pattern length];
  unichar *buffer = malloc(sizeof(unichar) * (textLength + patternLength + 1));
  NSUInteger tokenCount = 0;
  LikeRange *ranges = NULL;
  LikeToken *tokens = NULL;
  BOOL result = NO;

  if (buffer == NULL)
    {
      [NSException raise: NSMallocException format: @"Could not allocate buffer"];
    }
  [string getCharacters: buffer range: NSMakeRange(0, textLength)];
  [pattern getCharacters: buffer + textLength range: NSMakeRange(0, patternLength)];
  const unichar *text = buffer;

  @try
    {
      tokens = likeTokenize(buffer + textLength, patternLength, caseInsensitive,
	&tokenCount, &ranges);

      NSUInteger t = 0;
      NSUInteger p = 0;
      // Where the last '*' sits in the pattern and how much text it has
      // swallowed so far; NSNotFound until a '*' has been seen.
      NSUInteger starToken = NSNotFound;
      NSUInteger starText = 0;
      BOOL failed = NO;

      while (t < textLength)
	{
	  if (p < tokenCount && tokens[p].kind == LikeTokenStar)
	    {
	      starToken = p++;
	      starText = t;
	    }
	  else if (p < tokenCount
	    && likeTokenMatches(&tokens[p], ranges, text[t], caseInsensitive))
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
	      failed = YES;
	      break;
	    }
	}
      if (!failed)
	{
	  while (p < tokenCount && tokens[p].kind == LikeTokenStar)
	    {
	      p++;
	    }
	  result = (p == tokenCount);
	}
    }
  @finally
    {
      free(tokens);
      free(ranges);
      free(buffer);
    }
  return result;
}

static BOOL likeEntry(NSString *receiver, id pattern, BOOL caseInsensitive)
{
  if (pattern == nil)
    {
      return NO;
    }
  if (![pattern isKindOfClass: [NSString class]])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"-[%@ length]: unrecognized selector sent to instance %p",
	NSStringFromClass([pattern class]), pattern];
    }
  return likeMatches(receiver, pattern, caseInsensitive);
}

@implementation NSString (NSComparisonMethods)
- (BOOL) isCaseInsensitiveLike: (NSString *)object
{
  return likeEntry(self, object, YES);
}

- (BOOL) isLike: (NSString *)object
{
  return likeEntry(self, object, NO);
}
@end
