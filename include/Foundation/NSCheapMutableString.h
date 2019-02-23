#import <Foundation/NSString.h>

// NOTE: NSCheapMutableString is *not* actually mutable.

@interface NSCheapMutableString : NSMutableString {
    void *_reserved;

    union {
        unichar *fat;
        char *thin;
    } contents;

    struct {
        unsigned int isFat : 1;
        unsigned int freeWhenDone : 1;
        unsigned int refs : 30; // TODO: what is this used for?
    } flags;

    NSUInteger numCharacters;
}

- (void) setContentsNoCopy: (void *) data
                    length: (NSUInteger) length
              freeWhenDone: (BOOL) freeWhenDone
                 isUnicode: (BOOL) isFat;

@end
