#import <Foundation/NSCheapMutableString.h>
#import <Foundation/NSException.h>

// NOTE: NSCheapMutableString is *not* actually mutable.

@implementation NSCheapMutableString

- (void) setContentsNoCopy: (void *) data
                    length: (NSUInteger) length
              freeWhenDone: (BOOL) freeWhenDone
                 isUnicode: (BOOL) isFat {

    if (isFat) {
        contents.fat = data;
    } else {
        contents.thin = data;
    }
    numCharacters = length;
    flags.isFat = isFat;
    flags.freeWhenDone = freeWhenDone;
    flags.refs = 1;
}

- (void) dealloc {
    if (flags.freeWhenDone) {
        if (flags.isFat) {
            free(contents.fat);
        } else {
            free(contents.thin);
        }
    }
    [super dealloc];
}

- (const char *) cString {
     if (!flags.isFat) {
          return contents.thin;
     }
     return [super cString];
}

- (NSUInteger) cStringLength {
     if (!flags.isFat) {
          return numCharacters;
     }
     return [super cStringLength];
}

- (unichar) characterAtIndex: (NSUInteger) index {
    if (index >= numCharacters) {
        [NSException raise:NSRangeException format:@"specified index is beyond the end of the string"];
        return 0;
    }
    if (flags.isFat) {
        return contents.fat[index];
    }
    return contents.thin[index];
}

- (NSUInteger) length {
    return numCharacters;
}

- (void) getCharacters: (unichar *) buffer range: (NSRange) range {
    if (NSMaxRange(range) > numCharacters) {
        [NSException raise:NSRangeException format:@"specified range is out of bounds of string"];
        return;
    }

    NSUInteger idx = 0;
    for (NSUInteger location = range.location; location < NSMaxRange(range); location++) {
        buffer[idx++] = flags.isFat ? contents.fat[location] : contents.thin[location];
    }
}

- (const char *) lossyCString {
    if (!flags.isFat) {
        return contents.thin;
    }
    return [super lossyCString];
}

- (NSStringEncoding) fastestEncoding {
    if (!flags.isFat) {
        return [NSString defaultCStringEncoding];
    }
    return [super fastestEncoding];
}

// TODO:
// getBytes:maxLength:usedLength:encoding:options:range:remainingRange:

@end
