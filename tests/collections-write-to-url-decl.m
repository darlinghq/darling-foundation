// Header-level check: compile only (clang -fsyntax-only). The implementations are in
// darling-corefoundation (NSArray.m, NSDictionary.m).
#import <Foundation/Foundation.h>

BOOL writeBoth(NSArray *array, NSDictionary *dictionary, NSURL *url, NSError **error)
{
    _Static_assert(NSPropertyListWriteInvalidError == 3852, "NSPropertyListWriteInvalidError");
    return [array writeToURL:url error:error] && [dictionary writeToURL:url error:error];
}
