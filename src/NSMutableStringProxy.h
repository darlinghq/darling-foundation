/*
  This file is part of Darling.

  Copyright (C) 2020 Lubos Dolezel

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

#import <Foundation/NSDistantObject.h>
#import <Foundation/NSString.h>

CF_PRIVATE
@interface NSMutableStringProxy: NSDistantObject

- (BOOL) getBytes: (void *) buffer
        maxLength: (NSUInteger) maxLength
       usedLength: (NSUInteger *) usedLength
         encoding: (NSStringEncoding) encoding
          options: (NSStringEncodingConversionOptions) options
            range: (NSRange) range
   remainingRange: (NSRange *) remainingRange;

- (void) getCString: (char *) buffer
          maxLength: (NSUInteger) maxLength
              range: (NSRange) range
     remainingRange: (NSRange *) leftover;

- (void) getCString: (char *) buffer;
- (void) getCString: (char *) buffer maxLength: (NSUInteger) maxLength;

- (void) getCharacters: (unichar *) buffer range: (NSRange) range;
- (void) getCharacters: (unichar *) buffer;

@end

@interface NSString (NSDistantString)

- (BOOL) _getBytesAsData: (NSData **) data
               maxLength: (NSUInteger) maxLength
              usedLength: (NSUInteger *) usedLength
                encoding: (NSStringEncoding) encoding
                 options: (NSStringEncodingConversionOptions) options
                   range: (NSRange) range
          remainingRange: (NSRange *) remainingRange;

- (NSString *) _getCharactersAsStringInRange: (NSRange) range;

@end
