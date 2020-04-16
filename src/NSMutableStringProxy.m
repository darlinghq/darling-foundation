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

#import "NSMutableStringProxy.h"
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSPortCoder.h>
#import <Foundation/NSException.h>
#import <CoreFoundation/CFString.h>

@implementation NSMutableStringProxy

- (BOOL) getBytes: (void *) buffer
        maxLength: (NSUInteger) maxLength
       usedLength: (NSUInteger *) usedLength
         encoding: (NSStringEncoding) encoding
          options: (NSStringEncodingConversionOptions) options
            range: (NSRange) range
   remainingRange: (NSRange *) remainingRange
{
    NSData *data;
    BOOL ok = [(NSString *) self _getBytesAsData: &data
                                       maxLength: maxLength
                                      usedLength: usedLength
                                        encoding: encoding
                                         options: options
                                           range: range
                                  remainingRange: remainingRange];
    if (ok) {
        [data getBytes: buffer length: maxLength];
    }
    return ok;
}

- (void) getCString: (char *) buffer
          maxLength: (NSUInteger) maxLength
              range: (NSRange) range
     remainingRange: (NSRange *) remainingRange
{
    NSUInteger filledLength = 0;
    CFStringEncoding cfEncoding = CFStringGetSystemEncoding();
    NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
    BOOL ok = [self getBytes: buffer
                   maxLength: maxLength
                  usedLength: &filledLength
                    encoding: encoding
                     options: 0
                       range: range
              remainingRange: remainingRange];
    if (!ok) {
        [NSException raise: NSCharacterConversionException
                    format: @"Could not covert to default C-string encoding"];
        return;
    }
    buffer[filledLength] = '\0';
}

- (void) getCString: (char *) buffer maxLength: (NSUInteger) maxLength {
    NSUInteger length = [(NSString *) self length];
    [self getCString: buffer
           maxLength: maxLength
               range: NSMakeRange(0, length)
      remainingRange: NULL];
}

- (void) getCString: (char *) buffer {
    NSUInteger length = [(NSString *) self length];
    [self getCString: buffer
           maxLength: length
               range: NSMakeRange(0, length)
      remainingRange: NULL];
}

- (void) getCharacters: (unichar *) buffer range: (NSRange) range {
    NSString *str = [(NSString *) self _getCharactersAsStringInRange: range];
    [str getCharacters: buffer range: NSMakeRange(0, range.length)];
}

- (void) getCharacters: (unichar *) buffer {
    NSUInteger length = [(NSString *) self length];
    [self getCharacters: buffer range: NSMakeRange(0, length)];
}

@end


@implementation NSString (NSDistantString)

- (BOOL) _getBytesAsData: (NSData **) data
               maxLength: (NSUInteger) maxLength
              usedLength: (NSUInteger *) usedLength
                encoding: (NSStringEncoding) encoding
                 options: (NSStringEncodingConversionOptions) options
                   range: (NSRange) range
          remainingRange: (NSRange *) remainingRange
{
    NSMutableData *d = [NSMutableData dataWithLength: maxLength];
    NSUInteger filledLength = 0;
    BOOL ok = [self getBytes: [d mutableBytes]
                   maxLength: maxLength
                  usedLength: &filledLength
                    encoding: encoding
                     options: options
                       range: range
                    remainingRange: remainingRange];
    if (ok) {
        [d setLength: filledLength];
        if (usedLength != NULL) {
            *usedLength = filledLength;
        }
        *data = d;
    } else {
        *data = nil;
    }
    return ok;
}

- (NSString *) _getCharactersAsStringInRange: (NSRange) range {
    return [self substringWithRange: range];
}

@end

@implementation NSMutableString (NSDistantString)

- (id) replacementObjectForPortCoder: (NSPortCoder *) portCoder {
    // Note: this overrides the implementation for NSString.
    if ([portCoder isByref]) {
        return [NSMutableStringProxy proxyWithLocal: self
                                         connection: [portCoder connection]];
    }
    return self;
}

@end
