/*
 This file is part of Darling.

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

#import <Foundation/NSAppleEventDescriptor.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSScanner.h>
#import <Foundation/NSCharacterSet.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

// The descriptor wraps an AEDesc from CoreServices' AE Descriptor Manager. AE links against Foundation,
// so Foundation can't link against AE; its functions are looked up when the first descriptor is made.
#define AE_PATH "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/AE.framework/Versions/A/AE"

static struct {
    __typeof__(AECreateDesc) *createDesc;
    __typeof__(AEDisposeDesc) *disposeDesc;
    __typeof__(AEDuplicateDesc) *duplicateDesc;
    __typeof__(AEGetDescDataSize) *getDescDataSize;
    __typeof__(AEGetDescData) *getDescData;
    __typeof__(AECreateList) *createList;
    __typeof__(AECountItems) *countItems;
    __typeof__(AEPutDesc) *putDesc;
    __typeof__(AEGetNthDesc) *getNthDesc;
    __typeof__(AEDeleteItem) *deleteItem;
    __typeof__(AEPutParamDesc) *putParamDesc;
    __typeof__(AEGetParamDesc) *getParamDesc;
    __typeof__(AEDeleteParam) *deleteParam;
    __typeof__(AECreateAppleEvent) *createAppleEvent;
    __typeof__(AEPutAttributeDesc) *putAttributeDesc;
    __typeof__(AEGetAttributeDesc) *getAttributeDesc;
} ae;

static void loadAE(void)
{
    static dispatch_once_t once;
    static BOOL loaded;
    dispatch_once(&once, ^{
        void *h = dlopen(AE_PATH, RTLD_LAZY | RTLD_GLOBAL);
        if (h == NULL)
            return;
        ae.createDesc = dlsym(h, "AECreateDesc");
        ae.disposeDesc = dlsym(h, "AEDisposeDesc");
        ae.duplicateDesc = dlsym(h, "AEDuplicateDesc");
        ae.getDescDataSize = dlsym(h, "AEGetDescDataSize");
        ae.getDescData = dlsym(h, "AEGetDescData");
        ae.createList = dlsym(h, "AECreateList");
        ae.countItems = dlsym(h, "AECountItems");
        ae.putDesc = dlsym(h, "AEPutDesc");
        ae.getNthDesc = dlsym(h, "AEGetNthDesc");
        ae.deleteItem = dlsym(h, "AEDeleteItem");
        ae.putParamDesc = dlsym(h, "AEPutParamDesc");
        ae.getParamDesc = dlsym(h, "AEGetParamDesc");
        ae.deleteParam = dlsym(h, "AEDeleteParam");
        ae.createAppleEvent = dlsym(h, "AECreateAppleEvent");
        ae.putAttributeDesc = dlsym(h, "AEPutAttributeDesc");
        ae.getAttributeDesc = dlsym(h, "AEGetAttributeDesc");
        loaded = ae.createDesc && ae.disposeDesc && ae.duplicateDesc && ae.getDescDataSize && ae.getDescData &&
            ae.createList && ae.countItems && ae.putDesc && ae.getNthDesc && ae.deleteItem && ae.putParamDesc &&
            ae.getParamDesc && ae.deleteParam && ae.createAppleEvent && ae.putAttributeDesc && ae.getAttributeDesc;
    });
    if (!loaded) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"NSAppleEventDescriptor: the AE Descriptor Manager (%s) is unavailable: %s", AE_PATH, dlerror()];
    }
}

@implementation NSAppleEventDescriptor {
    AEDesc _desc;
}

// Takes ownership of desc; returns nil and disposes it when err isn't noErr.
+ (NSAppleEventDescriptor *) _descriptorTakingDesc: (AEDesc *) desc error: (OSErr) err {
    if (err != noErr) {
        ae.disposeDesc(desc);
        return nil;
    }
    return [[[self alloc] initWithAEDescNoCopy: desc] autorelease];
}

+ (NSAppleEventDescriptor *) nullDescriptor {
    return [[[self alloc] initWithDescriptorType: typeNull bytes: NULL length: 0] autorelease];
}

+ (NSAppleEventDescriptor *) descriptorWithDescriptorType: (DescType) type bytes: (const void *) bytes length: (NSUInteger) length {
    return [[[self alloc] initWithDescriptorType: type bytes: bytes length: length] autorelease];
}

+ (NSAppleEventDescriptor *) descriptorWithDescriptorType: (DescType) type data: (NSData *) data {
    return [[[self alloc] initWithDescriptorType: type data: data] autorelease];
}

+ (NSAppleEventDescriptor *) descriptorWithBoolean: (Boolean) value {
    return [self descriptorWithDescriptorType: value ? typeTrue : typeFalse bytes: NULL length: 0];
}

+ (NSAppleEventDescriptor *) descriptorWithEnumCode: (OSType) value {
    return [self descriptorWithDescriptorType: typeEnumerated bytes: &value length: sizeof(value)];
}

+ (NSAppleEventDescriptor *) descriptorWithTypeCode: (OSType) value {
    return [self descriptorWithDescriptorType: typeType bytes: &value length: sizeof(value)];
}

+ (NSAppleEventDescriptor *) descriptorWithInt32: (SInt32) value {
    return [self descriptorWithDescriptorType: typeSInt32 bytes: &value length: sizeof(value)];
}

+ (NSAppleEventDescriptor *) descriptorWithString: (NSString *) string {
    if (string == nil)
        return nil;
    NSUInteger length = [string length];
    unichar *chars = malloc(length * sizeof(unichar) + 1);
    [string getCharacters: chars range: NSMakeRange(0, length)];
    NSAppleEventDescriptor *result = [self descriptorWithDescriptorType: typeUnicodeText bytes: chars length: length * sizeof(unichar)];
    free(chars);
    return result;
}

+ (NSAppleEventDescriptor *) listDescriptor {
    return [[[self alloc] initListDescriptor] autorelease];
}

+ (NSAppleEventDescriptor *) recordDescriptor {
    return [[[self alloc] initRecordDescriptor] autorelease];
}

+ (NSAppleEventDescriptor *) appleEventWithEventClass: (AEEventClass) eventClass
                                              eventID: (AEEventID) eventID
                                     targetDescriptor: (NSAppleEventDescriptor *) target
                                             returnID: (AEReturnID) returnID
                                        transactionID: (AETransactionID) transactionID
{
    return [[[self alloc] initWithEventClass: eventClass eventID: eventID targetDescriptor: target
                                    returnID: returnID transactionID: transactionID] autorelease];
}

- (id) initWithAEDescNoCopy: (const AEDesc *) desc {
    self = [super init];
    if (self) {
        loadAE();
        _desc = *desc;
    }
    return self;
}

- (id) initWithDescriptorType: (DescType) type bytes: (const void *) bytes length: (NSUInteger) length {
    loadAE();
    AEDesc desc;
    if (ae.createDesc(type, bytes, (Size) length, &desc) != noErr) {
        [self release];
        return nil;
    }
    return [self initWithAEDescNoCopy: &desc];
}

- (id) initWithDescriptorType: (DescType) type data: (NSData *) data {
    return [self initWithDescriptorType: type bytes: [data bytes] length: [data length]];
}

- (id) initListDescriptor {
    loadAE();
    AEDesc desc;
    if (ae.createList(NULL, 0, false, &desc) != noErr) {
        [self release];
        return nil;
    }
    return [self initWithAEDescNoCopy: &desc];
}

- (id) initRecordDescriptor {
    loadAE();
    AEDesc desc;
    if (ae.createList(NULL, 0, true, &desc) != noErr) {
        [self release];
        return nil;
    }
    return [self initWithAEDescNoCopy: &desc];
}

- (id) initWithEventClass: (AEEventClass) eventClass
                  eventID: (AEEventID) eventID
         targetDescriptor: (NSAppleEventDescriptor *) target
                 returnID: (AEReturnID) returnID
            transactionID: (AETransactionID) transactionID
{
    loadAE();
    AEDesc desc;
    if (ae.createAppleEvent(eventClass, eventID, target ? [target aeDesc] : NULL, returnID, transactionID, &desc) != noErr) {
        [self release];
        return nil;
    }
    return [self initWithAEDescNoCopy: &desc];
}

- (void) dealloc {
    ae.disposeDesc(&_desc);
    [super dealloc];
}

- (id) copyWithZone: (NSZone *) zone {
    AEDesc copy;
    if (ae.duplicateDesc(&_desc, &copy) != noErr)
        return nil;
    return [[[self class] allocWithZone: zone] initWithAEDescNoCopy: &copy];
}

- (const AEDesc *) aeDesc {
    return &_desc;
}

- (DescType) descriptorType {
    return _desc.descriptorType;
}

- (NSData *) data {
    Size size = ae.getDescDataSize(&_desc);
    NSMutableData *data = [NSMutableData dataWithLength: size];
    if (size > 0 && ae.getDescData(&_desc, [data mutableBytes], size) != noErr)
        return nil;
    return data;
}

static BOOL isTextType(DescType type)
{
    return type == typeUnicodeText || type == typeUTF8Text || type == typeChar;
}

- (NSString *) _stringFromTextData {
    NSData *data = [self data];
    switch (_desc.descriptorType) {
        case typeUnicodeText:
            return [NSString stringWithCharacters: [data bytes] length: [data length] / sizeof(unichar)];
        case typeUTF8Text:
            return [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
        case typeChar:
            return [[[NSString alloc] initWithData: data encoding: NSMacOSRomanStringEncoding] autorelease];
    }
    return nil;
}

// Coercions between the plain types scripts use most; the AE Descriptor Manager itself only duplicates.
- (NSAppleEventDescriptor *) coerceToDescriptorType: (DescType) type {
    DescType from = _desc.descriptorType;
    if (type == from || type == typeWildCard)
        return [[self copy] autorelease];

    NSData *data = [self data];
    SInt64 number = 0;
    BOOL haveNumber = YES;
    if (from == typeSInt32 && [data length] == sizeof(SInt32))
        number = *(SInt32 *) [data bytes];
    else if (from == typeSInt16 && [data length] == sizeof(SInt16))
        number = *(SInt16 *) [data bytes];
    else if (from == typeSInt64 && [data length] == sizeof(SInt64))
        number = *(SInt64 *) [data bytes];
    else if (from == typeTrue || from == typeFalse)
        number = from == typeTrue;
    else if (from == typeBoolean && [data length] == 1)
        number = *(UInt8 *) [data bytes] != 0;
    else if (isTextType(from)) {
        NSString *s = [[self _stringFromTextData] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
        if ([s caseInsensitiveCompare: @"true"] == NSOrderedSame)
            number = 1;
        else if ([s caseInsensitiveCompare: @"false"] == NSOrderedSame)
            number = 0;
        else {
            NSScanner *scanner = [NSScanner scannerWithString: s];
            long long value;
            haveNumber = [scanner scanLongLong: &value] && [scanner isAtEnd];
            number = value;
        }
    } else
        haveNumber = NO;

    switch (type) {
        case typeSInt32:
            if (!haveNumber || number < INT32_MIN || number > INT32_MAX)
                return nil;
            return [NSAppleEventDescriptor descriptorWithInt32: (SInt32) number];
        case typeSInt16: {
            if (!haveNumber || number < INT16_MIN || number > INT16_MAX)
                return nil;
            SInt16 value = (SInt16) number;
            return [NSAppleEventDescriptor descriptorWithDescriptorType: typeSInt16 bytes: &value length: sizeof(value)];
        }
        case typeBoolean: {
            if (!haveNumber || (number != 0 && number != 1))
                return nil;
            UInt8 value = (UInt8) number;
            return [NSAppleEventDescriptor descriptorWithDescriptorType: typeBoolean bytes: &value length: 1];
        }
        case typeTrue:
        case typeFalse:
            if (!haveNumber || number != (type == typeTrue))
                return nil;
            return [NSAppleEventDescriptor descriptorWithDescriptorType: type bytes: NULL length: 0];
        case typeUnicodeText:
        case typeUTF8Text:
        case typeChar: {
            NSString *s = isTextType(from) ? [self _stringFromTextData]
                        : (from == typeTrue || from == typeFalse || from == typeBoolean) ? (number ? @"true" : @"false")
                        : haveNumber ? [NSString stringWithFormat: @"%lld", number] : nil;
            if (s == nil)
                return nil;
            if (type == typeUnicodeText)
                return [NSAppleEventDescriptor descriptorWithString: s];
            NSData *bytes = [s dataUsingEncoding: type == typeUTF8Text ? NSUTF8StringEncoding : NSMacOSRomanStringEncoding];
            return bytes ? [NSAppleEventDescriptor descriptorWithDescriptorType: type data: bytes] : nil;
        }
    }
    return nil;
}

- (Boolean) booleanValue {
    NSAppleEventDescriptor *d = [self coerceToDescriptorType: typeBoolean];
    return d ? *(UInt8 *) [[d data] bytes] != 0 : false;
}

- (SInt32) int32Value {
    NSAppleEventDescriptor *d = [self coerceToDescriptorType: typeSInt32];
    return d ? *(SInt32 *) [[d data] bytes] : 0;
}

- (NSString *) stringValue {
    return [[self coerceToDescriptorType: typeUnicodeText] _stringFromTextData];
}

- (OSType) _fourCharCodeValue {
    NSData *data = [self data];
    return [data length] == sizeof(OSType) ? *(OSType *) [data bytes] : 0;
}

- (OSType) enumCodeValue {
    return [self _fourCharCodeValue];
}

- (OSType) typeCodeValue {
    return [self _fourCharCodeValue];
}

- (NSAppleEventDescriptor *) attributeDescriptorForKeyword: (AEKeyword) keyword {
    AEDesc desc;
    return [NSAppleEventDescriptor _descriptorTakingDesc: &desc error: ae.getAttributeDesc(&_desc, keyword, typeWildCard, &desc)];
}

- (void) setAttributeDescriptor: (NSAppleEventDescriptor *) descriptor forKeyword: (AEKeyword) keyword {
    ae.putAttributeDesc(&_desc, keyword, [descriptor aeDesc]);
}

- (OSType) _attributeCode: (AEKeyword) keyword {
    return [[self attributeDescriptorForKeyword: keyword] _fourCharCodeValue];
}

- (AEEventClass) eventClass {
    return [self _attributeCode: keyEventClassAttr];
}

- (AEEventID) eventID {
    return [self _attributeCode: keyEventIDAttr];
}

- (AEReturnID) returnID {
    return [[self attributeDescriptorForKeyword: keyReturnIDAttr] int32Value];
}

- (AETransactionID) transactionID {
    return [[self attributeDescriptorForKeyword: keyTransactionIDAttr] int32Value];
}

- (NSAppleEventDescriptor *) paramDescriptorForKeyword: (AEKeyword) keyword {
    AEDesc desc;
    return [NSAppleEventDescriptor _descriptorTakingDesc: &desc error: ae.getParamDesc(&_desc, keyword, typeWildCard, &desc)];
}

- (void) setParamDescriptor: (NSAppleEventDescriptor *) descriptor forKeyword: (AEKeyword) keyword {
    ae.putParamDesc(&_desc, keyword, [descriptor aeDesc]);
}

- (void) removeParamDescriptorWithKeyword: (AEKeyword) keyword {
    ae.deleteParam(&_desc, keyword);
}

- (NSAppleEventDescriptor *) descriptorForKeyword: (AEKeyword) keyword {
    return [self paramDescriptorForKeyword: keyword];
}

- (void) setDescriptor: (NSAppleEventDescriptor *) descriptor forKeyword: (AEKeyword) keyword {
    [self setParamDescriptor: descriptor forKeyword: keyword];
}

- (void) removeDescriptorWithKeyword: (AEKeyword) keyword {
    [self removeParamDescriptorWithKeyword: keyword];
}

- (NSInteger) numberOfItems {
    long count = 0;
    return ae.countItems(&_desc, &count) == noErr ? count : 0;
}

- (NSAppleEventDescriptor *) descriptorAtIndex: (NSInteger) index {
    AEDesc desc;
    return [NSAppleEventDescriptor _descriptorTakingDesc: &desc error: ae.getNthDesc(&_desc, index, typeWildCard, NULL, &desc)];
}

- (AEKeyword) keywordForDescriptorAtIndex: (NSInteger) index {
    AEDesc desc;
    AEKeyword keyword = 0;
    if (ae.getNthDesc(&_desc, index, typeWildCard, &keyword, &desc) != noErr)
        return 0;
    ae.disposeDesc(&desc);
    return keyword;
}

// One-based; replaces the descriptor at that index, and 0 (or one past the end) appends.
- (void) insertDescriptor: (NSAppleEventDescriptor *) descriptor atIndex: (NSInteger) index {
    ae.putDesc(&_desc, index, [descriptor aeDesc]);
}

- (void) removeDescriptorAtIndex: (NSInteger) index {
    ae.deleteItem(&_desc, index);
}

- (NSString *) description {
    OSType type = _desc.descriptorType;
    return [NSString stringWithFormat: @"<%@ %p '%c%c%c%c' items=%ld size=%ld>", [self class], self,
            (int) (type >> 24) & 0xff, (int) (type >> 16) & 0xff, (int) (type >> 8) & 0xff, (int) type & 0xff,
            (long) [self numberOfItems], (long) ae.getDescDataSize(&_desc)];
}

@end
