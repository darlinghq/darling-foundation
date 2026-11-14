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

// -serializedRepresentation and -initWithSerializedRepresentation: of NSFileWrapper.
//
// The layout was worked out from the data macOS produces for small wrappers (see
// the notes next to the tests); every number is a little-endian 32-bit word.
//
//   data       := "rtfd", 0, 3, dictionary
//   dictionary := count, count x (length, name bytes), count x (size),
//                 then the values, each of the given size
//   value      := 1, length, bytes                   (file contents, link destination)
//              |  3, dictionary                     (directory)
//   "."        := the value of the entry named ".", a 1/length/bytes value holding
//                 the listing: count, count x (length, name), count x 0x10,
//                 count x (modification time in seconds since 1970, POSIX permissions,
//                 kind, 0) where the kind is 0 for a file, 1 for a directory and 4 for a
//                 symbolic link (a directory has no modification time).
//
// A directory's dictionary has one entry per child, named by the child's preferred
// file name, and the "." listing. A file or link is stored as a dictionary with the
// entry ".." (its contents), the "." listing naming "..", and the entries
// "__@PreferredName@__" and "__@UTF8PreferredName@__" when it has a preferred name.
// A directory with a preferred name has those two entries as well.

#import <Foundation/NSFileWrapper.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSString.h>
#include <stdlib.h>
#include <string.h>

static NSString *const kListingName = @".";
static NSString *const kContentsName = @"..";
static NSString *const kPreferredName = @"__@PreferredName@__";
static NSString *const kUTF8PreferredName = @"__@UTF8PreferredName@__";

enum {
    kValueBlob = 1,
    kValueDirectory = 3,
    kListingFlags = 0x10,
    kKindFile = 0,
    kKindDirectory = 1,
    kKindLink = 4,
    kKindRoot = 2,
    kMaximumDepth = 64,
};

#pragma mark - Writing

static void appendWord(NSMutableData *data, uint32_t word) {
    unsigned char bytes[4] = { word & 0xff, (word >> 8) & 0xff, (word >> 16) & 0xff, (word >> 24) & 0xff };
    [data appendBytes: bytes length: 4];
}

static void appendName(NSMutableData *data, NSString *name) {
    NSData *utf8 = [name dataUsingEncoding: NSUTF8StringEncoding];
    appendWord(data, (uint32_t) [utf8 length]);
    [data appendData: utf8];
}

static NSData *blobValue(NSData *contents) {
    NSMutableData *value = [NSMutableData data];
    appendWord(value, kValueBlob);
    appendWord(value, (uint32_t) [contents length]);
    [value appendData: contents];
    return value;
}

static NSData *dictionaryData(NSArray *names, NSArray *values) {
    NSMutableData *data = [NSMutableData data];
    appendWord(data, (uint32_t) [names count]);
    for (NSString *name in names)
        appendName(data, name);
    for (NSData *value in values)
        appendWord(data, (uint32_t) [value length]);
    for (NSData *value in values)
        [data appendData: value];
    return data;
}

// The modification time of a file in the listing: the wrapper's, or the current time if it
// has none. A link has its own only if one was set; a directory never has one.
static uint32_t modificationTime(NSFileWrapper *wrapper, BOOL defaultsToNow) {
    NSDate *date = [[wrapper fileAttributes] objectForKey: NSFileModificationDate];
    if (date == nil && defaultsToNow)
        date = [NSDate date];
    NSTimeInterval seconds = [date timeIntervalSince1970];
    return date == nil || seconds < 0 ? 0 : (uint32_t) seconds;
}

static uint32_t permissions(NSFileWrapper *wrapper, uint32_t fallback) {
    NSNumber *number = [[wrapper fileAttributes] objectForKey: NSFilePosixPermissions];
    return number != nil ? (uint32_t) [number unsignedIntValue] & 07777 : fallback;
}

// The listing records of the children, in the order of names.
static NSData *listingValue(NSArray *names, NSArray *children, BOOL isRoot) {
    NSMutableData *listing = [NSMutableData data];
    NSUInteger count = [names count];

    appendWord(listing, (uint32_t) count);
    for (NSString *name in names)
        appendName(listing, name);
    for (NSUInteger i = 0; i < count; i++)
        appendWord(listing, kListingFlags);
    for (NSFileWrapper *child in children) {
        uint32_t kind, mtime = 0, mode;

        if ([child isDirectory]) {
            kind = kKindDirectory;
            mode = permissions(child, 0777);
        } else if ([child isSymbolicLink]) {
            kind = kKindLink;
            mtime = modificationTime(child, NO);
            mode = permissions(child, 0666);
        } else {
            kind = kKindFile;
            mtime = isRoot ? 0 : modificationTime(child, YES);
            mode = permissions(child, 0666);
        }
        if (isRoot) {
            kind |= kKindRoot;
            mtime = 0;
        }
        appendWord(listing, mtime);
        appendWord(listing, mode);
        appendWord(listing, kind);
        appendWord(listing, isRoot ? 1 : 0);
    }
    return blobValue(listing);
}

static NSData *contentsOfLeaf(NSFileWrapper *wrapper) {
    if ([wrapper isSymbolicLink])
        return [[[wrapper symbolicLinkDestinationURL] path] dataUsingEncoding: NSUTF8StringEncoding];
    NSData *contents = [wrapper regularFileContents];
    return contents != nil ? contents : [NSData data];
}

static void addPreferredName(NSFileWrapper *wrapper, NSMutableArray *names, NSMutableArray *values) {
    NSString *preferred = [wrapper preferredFilename];
    if ([preferred length] == 0)
        return;
    NSData *utf8 = [preferred dataUsingEncoding: NSUTF8StringEncoding];
    [names addObject: kPreferredName];
    [values addObject: blobValue(utf8)];
    [names addObject: kUTF8PreferredName];
    [values addObject: blobValue(utf8)];
}

static NSData *directoryDictionary(NSFileWrapper *directory, BOOL isRoot) {
    NSDictionary *children = [directory fileWrappers];
    NSArray *childNames = [[children allKeys] sortedArrayUsingSelector: @selector(compare:)];
    NSMutableArray *names = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];
    NSMutableArray *wrappers = [NSMutableArray array];

    for (NSString *name in childNames) {
        NSFileWrapper *child = [children objectForKey: name];
        NSData *value;

        if ([child isDirectory]) {
            NSMutableData *nested = [NSMutableData data];
            appendWord(nested, kValueDirectory);
            [nested appendData: directoryDictionary(child, NO)];
            value = nested;
        } else {
            value = blobValue(contentsOfLeaf(child));
        }
        [names addObject: name];
        [values addObject: value];
        [wrappers addObject: child];
    }
    if (isRoot)
        addPreferredName(directory, names, values);
    // A directory without children has no listing.
    if ([childNames count] > 0) {
        [names addObject: kListingName];
        [values addObject: listingValue(childNames, wrappers, NO)];
    }
    return dictionaryData(names, values);
}

@implementation NSFileWrapper (SerializedRepresentation)

- (NSData *) serializedRepresentation {
    NSMutableData *data = [NSMutableData data];
    NSData *dictionary;

    if ([self isDirectory]) {
        dictionary = directoryDictionary(self, YES);
    } else {
        NSMutableArray *names = [NSMutableArray arrayWithObject: kContentsName];
        NSMutableArray *values = [NSMutableArray arrayWithObject: blobValue(contentsOfLeaf(self))];

        addPreferredName(self, names, values);
        [names addObject: kListingName];
        [values addObject: listingValue([NSArray arrayWithObject: kContentsName],
                                        [NSArray arrayWithObject: self], YES)];
        dictionary = dictionaryData(names, values);
    }
    [data appendBytes: "rtfd" length: 4];
    appendWord(data, 0);
    appendWord(data, 3);
    [data appendData: dictionary];
    return data;
}

@end

#pragma mark - Reading

// A cursor over the data that never reads outside it; every read fails once
// the data is exhausted.
typedef struct {
    const unsigned char *bytes;
    NSUInteger length;
    NSUInteger offset;
    BOOL failed;
} Cursor;

static uint32_t readWord(Cursor *cursor) {
    if (cursor->failed || cursor->length - cursor->offset < 4) {
        cursor->failed = YES;
        return 0;
    }
    const unsigned char *p = cursor->bytes + cursor->offset;
    cursor->offset += 4;
    return (uint32_t) p[0] | ((uint32_t) p[1] << 8) | ((uint32_t) p[2] << 16) | ((uint32_t) p[3] << 24);
}

static BOOL readBytes(Cursor *cursor, uint32_t count, const unsigned char **bytes) {
    if (cursor->failed || cursor->length - cursor->offset < count) {
        cursor->failed = YES;
        return NO;
    }
    *bytes = cursor->bytes + cursor->offset;
    cursor->offset += count;
    return YES;
}

@interface NSFileWrapper (SerializedRepresentationReading)
+ (NSFileWrapper *) _wrapperFromDictionaryAt: (Cursor *) cursor depth: (int) depth isRoot: (BOOL) isRoot;
@end

typedef struct {
    NSString *name;
    uint32_t mtime, mode, kind;
} ListingRecord;

static NSString *stringFromBytes(const unsigned char *bytes, NSUInteger length) {
    return [[[NSString alloc] initWithBytes: bytes length: length encoding: NSUTF8StringEncoding] autorelease];
}

// Parses a "." listing; the names go to *names and the records are returned in a C array
// that the caller frees. Returns NULL on malformed data.
static ListingRecord *parseListing(NSData *listing, NSUInteger *outCount) {
    Cursor c = { [listing bytes], [listing length], 0, NO };
    uint32_t count = readWord(&c);

    // Each name takes at least four bytes, each record twenty.
    if (c.failed || count > [listing length] / 24)
        return NULL;
    ListingRecord *records = calloc(count ? count : 1, sizeof(ListingRecord));
    BOOL ok = records != NULL;
    for (uint32_t i = 0; ok && i < count; i++) {
        uint32_t length = readWord(&c);
        const unsigned char *bytes;
        ok = readBytes(&c, length, &bytes);
        records[i].name = ok ? [stringFromBytes(bytes, length) retain] : nil;
        ok = ok && records[i].name != nil;
    }
    for (uint32_t i = 0; ok && i < count; i++)
        readWord(&c);  // the flags word
    for (uint32_t i = 0; ok && i < count; i++) {
        records[i].mtime = readWord(&c);
        records[i].mode = readWord(&c);
        records[i].kind = readWord(&c);
        readWord(&c);
        ok = !c.failed;
    }
    if (!ok) {
        for (uint32_t i = 0; records && i < count; i++)
            [records[i].name release];
        free(records);
        return NULL;
    }
    *outCount = count;
    return records;
}

static void freeListing(ListingRecord *records, NSUInteger count) {
    for (NSUInteger i = 0; i < count; i++)
        [records[i].name release];
    free(records);
}

static void applyAttributes(NSFileWrapper *wrapper, NSString *type, uint32_t mtime, uint32_t mode) {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];

    [attributes setObject: type forKey: NSFileType];
    [attributes setObject: [NSNumber numberWithUnsignedInt: mode & 07777] forKey: NSFilePosixPermissions];
    if (mtime != 0)
        [attributes setObject: [NSDate dateWithTimeIntervalSince1970: mtime] forKey: NSFileModificationDate];
    [wrapper setFileAttributes: attributes];
}

@implementation NSFileWrapper (SerializedRepresentationReading)

// Reads a dictionary at the cursor and builds the wrapper it stands for. Returns nil
// for malformed data, which includes unbalanced sizes and nesting deeper than a sane limit.
+ (NSFileWrapper *) _wrapperFromDictionaryAt: (Cursor *) cursor depth: (int) depth isRoot: (BOOL) isRoot {
    if (depth > kMaximumDepth)
        return nil;

    uint32_t count = readWord(cursor);
    // Every entry takes at least a length and a size word.
    if (cursor->failed || count > (cursor->length - cursor->offset) / 8)
        return nil;

    NSMutableArray *names = [NSMutableArray arrayWithCapacity: count];
    for (uint32_t i = 0; i < count; i++) {
        uint32_t length = readWord(cursor);
        const unsigned char *bytes;
        if (!readBytes(cursor, length, &bytes))
            return nil;
        NSString *name = stringFromBytes(bytes, length);
        if (name == nil)
            return nil;
        [names addObject: name];
    }

    uint32_t *sizes = calloc(count ? count : 1, sizeof(uint32_t));
    if (sizes == NULL)
        return nil;
    for (uint32_t i = 0; i < count; i++)
        sizes[i] = readWord(cursor);

    NSMutableDictionary *blobs = [NSMutableDictionary dictionary];
    NSMutableDictionary *directories = [NSMutableDictionary dictionary];
    BOOL ok = !cursor->failed;

    for (uint32_t i = 0; ok && i < count; i++) {
        NSUInteger end;
        uint32_t kind;
        const unsigned char *bytes;

        if (sizes[i] > cursor->length - cursor->offset) {
            ok = NO;
            break;
        }
        end = cursor->offset + sizes[i];
        kind = readWord(cursor);
        if (kind == kValueBlob) {
            uint32_t length = readWord(cursor);
            if (!readBytes(cursor, length, &bytes) || cursor->offset != end) {
                ok = NO;
                break;
            }
            [blobs setObject: [NSData dataWithBytes: bytes length: length] forKey: [names objectAtIndex: i]];
        } else if (kind == kValueDirectory) {
            // The nested dictionary is read within its own size.
            Cursor inner = { cursor->bytes, end, cursor->offset, NO };
            NSFileWrapper *directory = [self _wrapperFromDictionaryAt: &inner depth: depth + 1 isRoot: NO];
            if (directory == nil || inner.offset != end) {
                ok = NO;
                break;
            }
            [directories setObject: directory forKey: [names objectAtIndex: i]];
            cursor->offset = end;
        } else {
            ok = NO;
        }
    }
    free(sizes);
    if (!ok || cursor->failed)
        return nil;

    NSUInteger recordCount = 0;
    NSData *listing = [blobs objectForKey: kListingName];
    ListingRecord *records = listing != nil ? parseListing(listing, &recordCount) : NULL;
    if (listing != nil && records == NULL)
        return nil;

    NSFileWrapper *result = nil;
    NSData *contents = [blobs objectForKey: kContentsName];

    if (contents != nil) {
        // A file or a symbolic link; the listing says which.
        uint32_t kind = 0, mtime = 0, mode = 0666;
        for (NSUInteger i = 0; i < recordCount; i++) {
            if ([records[i].name isEqualToString: kContentsName]) {
                kind = records[i].kind;
                mtime = records[i].mtime;
                mode = records[i].mode;
            }
        }
        if (kind & kKindLink) {
            NSString *destination = stringFromBytes([contents bytes], [contents length]);
            if (destination != nil)
                result = [[[NSFileWrapper alloc] initSymbolicLinkWithDestination: destination] autorelease];
            if (result != nil)
                applyAttributes(result, NSFileTypeSymbolicLink, mtime, mode);
        } else {
            result = [[[NSFileWrapper alloc] initRegularFileWithContents: contents] autorelease];
            applyAttributes(result, NSFileTypeRegular, mtime, mode);
        }
    } else {
        NSMutableDictionary *children = [NSMutableDictionary dictionary];

        for (NSString *name in blobs) {
            if ([name isEqualToString: kListingName] || [name isEqualToString: kPreferredName] ||
                [name isEqualToString: kUTF8PreferredName])
                continue;

            NSData *data = [blobs objectForKey: name];
            uint32_t kind = kKindFile, mtime = 0, mode = 0666;
            for (NSUInteger i = 0; i < recordCount; i++) {
                if ([records[i].name isEqualToString: name]) {
                    kind = records[i].kind;
                    mtime = records[i].mtime;
                    mode = records[i].mode;
                }
            }
            NSFileWrapper *child = nil;
            if ([name length] == 0) {
                freeListing(records, recordCount);
                return nil;
            }
            if (kind & kKindLink) {
                NSString *destination = stringFromBytes([data bytes], [data length]);
                if (destination != nil)
                    child = [[[NSFileWrapper alloc] initSymbolicLinkWithDestination: destination] autorelease];
                if (child != nil)
                    applyAttributes(child, NSFileTypeSymbolicLink, mtime, mode);
            } else {
                child = [[[NSFileWrapper alloc] initRegularFileWithContents: data] autorelease];
                applyAttributes(child, NSFileTypeRegular, mtime, mode);
            }
            if (child == nil) {
                freeListing(records, recordCount);
                return nil;
            }
            [child setPreferredFilename: name];
            [child setFilename: name];
            [children setObject: child forKey: name];
        }
        for (NSString *name in directories) {
            NSFileWrapper *child = [directories objectForKey: name];
            if ([name length] == 0) {
                freeListing(records, recordCount);
                return nil;
            }
            uint32_t mode = 0777;
            for (NSUInteger i = 0; i < recordCount; i++)
                if ([records[i].name isEqualToString: name])
                    mode = records[i].mode;
            applyAttributes(child, NSFileTypeDirectory, 0, mode);
            [child setPreferredFilename: name];
            [child setFilename: name];
            [children setObject: child forKey: name];
        }
        result = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers: children] autorelease];
        applyAttributes(result, NSFileTypeDirectory, 0, 0777);
    }
    freeListing(records, recordCount);

    // The root carries its preferred name explicitly.
    NSData *name = [blobs objectForKey: kUTF8PreferredName];
    if (name == nil)
        name = [blobs objectForKey: kPreferredName];
    if (result != nil && isRoot && [name length] > 0) {
        NSString *preferred = stringFromBytes([name bytes], [name length]);
        if ([preferred length] > 0) {
            [result setPreferredFilename: preferred];
            [result setFilename: preferred];
        }
    }
    return result;
}

- (id) initWithSerializedRepresentation: (NSData *) serialized {
    NSFileWrapper *wrapper = nil;

    if ([serialized length] >= 12 && memcmp([serialized bytes], "rtfd", 4) == 0) {
        Cursor cursor = { [serialized bytes], [serialized length], 4, NO };

        if (readWord(&cursor) == 0 && readWord(&cursor) == 3)
            wrapper = [NSFileWrapper _wrapperFromDictionaryAt: &cursor depth: 0 isRoot: YES];
        if (cursor.failed || cursor.offset != cursor.length)
            wrapper = nil;
    }
    // NSFileWrapper is a class cluster whose allocator hands out a shared placeholder,
    // which is not released here; the parsed wrapper is returned instead of self.
    return [wrapper retain];
}

@end
