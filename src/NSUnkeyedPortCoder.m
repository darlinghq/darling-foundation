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

#import "NSUnkeyedPortCoder.h"
#import <Foundation/NSMutableData.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSConnection.h>
#import <Foundation/NSDistantObject.h>
#import <CoreFoundation/NSObjCRuntimeInternal.h>
#import <CoreFoundation/NSInvocationInternal.h>
#import "NSObjectInternal.h"
#import "NSConnectionInternal.h"
#import "NSPortCoderUtil.h"
#import <objc/runtime.h>


@interface NSObject (IsAncestorOfObject)
+ (BOOL) isAncestorOfObject: (id) object;
@end


@implementation NSUnkeyedPortCoder

- (instancetype) initWithReceivePort: (NSPort *) recvPort
                            sendPort: (NSPort *) sendPort
                          components: (NSArray *) components
{
    _recvPort = [recvPort retain];
    _sendPort = [sendPort retain];
    _components = [components mutableCopy];
    if (_components == nil) {
        _components = [[NSMutableArray alloc] initWithCapacity: 1];
    }
    return self;
}

- (void) dealloc {
    [_recvPort release];
    [_sendPort release];
    [_components release];
    [super dealloc];
}

- (BOOL) isBycopy {
    return _isBycopy;
}

- (BOOL) isByref {
    return _isByref;
}

- (NSArray *) components {
    return _components;
}

- (NSArray *) finishedComponents {
    return _components;
}

- (void) invalidate {
    [_recvPort release];
    _recvPort = nil;
    [_sendPort release];
    _sendPort = nil;
    [_components removeAllObjects];
}

- (NSConnection *) connection {
    return [NSConnection connectionWithReceivePort: _recvPort
                                          sendPort: _sendPort];
}

- (NSInteger) versionForClassName: (NSString *) className {
    return [[self connection] versionForClassNamed: className];
}

- (void) encodePortObject: (NSPort *) port {
    if (port == nil) {
        [NSException raise:NSInvalidArgumentException format:@"port cannot be nil"];
    }
    [_components addObject: port];
}

- (NSPort *) decodePortObject {
    return _components[_componentIndex++];
}

- (BOOL) _hasMoreData {
    // Handle the case where we haven't even started reading the data specially.
    if (_componentIndex == 0) {
        if ([_components count] == 0 || [_components[0] length] == 0) {
            return NO;
        }
    }
    // Otherwise, we always make sure to advance the component index when we
    // reach the end of the previous component, so a simple component index
    // check should do.
    return _componentIndex < [_components count];
}

static void appendBytes(NSUnkeyedPortCoder *self, const void *bytes, NSUInteger length) {
    NSMutableArray *components = self->_components;
    if (![[components lastObject] isKindOfClass: [NSMutableData class]]) {
        [components addObject: [NSMutableData dataWithCapacity: 64]];
    }
    [[components lastObject] appendBytes: bytes length: length];
}

static void appendByte(NSUnkeyedPortCoder *self, char byte) {
    appendBytes(self, &byte, 1);
}

static void advanceComponentIfNeeded(NSUnkeyedPortCoder *self) {
    NSData *data = self->_components[self->_componentIndex];
    if (self->_readingOffset == [data length]) {
        self->_componentIndex++;
        self->_readingOffset = 0;
    }
}

static void readBytes(NSUnkeyedPortCoder *self, void *buffer, size_t count) {
    if (count == 0) {
        // Make sure not to try to access the components at all in this case.
        return;
    }
    NSData *data = self->_components[self->_componentIndex];
    [data getBytes: buffer range: NSMakeRange(self->_readingOffset, count)];
    self->_readingOffset += count;
    advanceComponentIfNeeded(self);
}

static char readByte(NSUnkeyedPortCoder *self) {
    char buffer;
    readBytes(self, &buffer, 1);
    return buffer;
}

static void encodeInteger(NSUnkeyedPortCoder *self, const void *data, unsigned char size) {
    // TODO: Support big endian.
    // Trim trailing zeroes (or 0xff-s).
    const signed char *sdata = (const signed char *) data;
    BOOL isNegative = sdata[size - 1] < 0;
    signed char emptyByte = isNegative ? -1 : 0;
    unsigned char minSize = isNegative ? 1 : 0;
    while (size > minSize && sdata[size - 1] == emptyByte) {
        size--;
    }
    signed char size2 = isNegative ? -size : size;
    appendBytes(self, &size2, 1);
    appendBytes(self, data, size);
}

static void decodeInteger(NSUnkeyedPortCoder *self, void *data, unsigned char size) {
    signed char firstByte = readByte(self);
    BOOL isNegative = firstByte < 0;
    signed char emptyByte = isNegative ? -1 : 0;
    unsigned char decodedSize = isNegative ? -firstByte : firstByte;
    readBytes(self, data, decodedSize);
    memset(data + decodedSize, emptyByte, size - decodedSize);
}

static void encodeString(NSUnkeyedPortCoder *self, const char *str) {
    appendByte(self, str != NULL);
    if (str == NULL) {
        return;
    }
    // The length includes the null byte.
    NSUInteger length = strlen(str) + 1;
    encodeInteger(self, &length, sizeof(length));
    appendBytes(self, str, length);
}

static void encodeSelector(NSUnkeyedPortCoder *self, SEL sel) {
    // This is really the same as encodeString(),
    // but let's do it explicitly.
    if (sel) {
        encodeString(self, sel_getName(sel));
    } else {
        encodeString(self, NULL);
    }
}

static NSData *decodeString(NSUnkeyedPortCoder *self) {
    BOOL isNull = readByte(self) == 0;
    if (isNull) {
        return nil;
    }
    NSRange range;
    decodeInteger(self, &range.length, sizeof(range.length));
    range.location = self->_readingOffset;
    NSData *data = [self->_components[self->_componentIndex] subdataWithRange: range];
    self->_readingOffset += range.length;
    advanceComponentIfNeeded(self);
    return data;
}

static SEL decodeSelector(NSUnkeyedPortCoder *self) {
    NSData *data = decodeString(self);
    if (data == nil) {
        return (SEL) 0;
    }
    return sel_registerName([data bytes]);
}

static void encodeClass(NSUnkeyedPortCoder *self, Class class) {
    appendByte(self, 1);
    const char *name = class ? class_getName(class) : "nil";
    encodeString(self, name);
}

static Class decodeClass(NSUnkeyedPortCoder *self) {
    readByte(self);
    const char *name = [decodeString(self) bytes];
    if (name == NULL || strcmp(name, "nil") == 0) {
        return Nil;
    }
    return objc_getClass(name);
}

- (void) encodeValueOfObjCType: (const char *) type at: (const void *) addr {
    switch (type[0]) {
    case _C_ID:
        [self encodeObject: *(id *) addr isBycopy: _isBycopy isByref: _isByref];
        break;

    case _C_CLASS:
        encodeClass(self, *(Class *) addr);
        break;

    case _C_CHR:
    case _C_UCHR:
        appendBytes(self, addr, 1);
        break;
    case _C_SHT:
    case _C_USHT:
        appendBytes(self, addr, sizeof(short));
        break;

    case _C_BOOL:
        encodeInteger(self, addr, sizeof(_Bool));
        break;
    case _C_INT:
    case _C_UINT:
        encodeInteger(self, addr, sizeof(int));
        break;
    case _C_LNG:
    case _C_ULNG:
        encodeInteger(self, addr, sizeof(long));
        break;
    case _C_LNG_LNG:
    case _C_ULNG_LNG:
        encodeInteger(self, addr, sizeof(long long));
        break;
    // We just encode floating-point numbers simply by
    // interpreting their memory layout as integers.
    case _C_FLT:
        encodeInteger(self, addr, sizeof(float));
        break;
    case _C_DBL:
        encodeInteger(self, addr, sizeof(double));
        break;

    case _C_CHARPTR:
        encodeString(self, *(const char **) addr);
        break;
    case _C_SEL:
        encodeSelector(self, *(SEL *) addr);
        break;

    case _C_PTR:
        {
            void *ptr = *(void **) addr;
            appendByte(self, ptr != NULL);
            if (ptr != NULL) {
                [self encodeValueOfObjCType: type + 1 at: ptr];
            }
            break;
        }

    case _C_ARY_B:
        {
            const char *itemType;
            NSUInteger count = strtol(type + 1, (char **) &itemType, 10);
            [self encodeArrayOfObjCType: itemType
                                  count: count
                                     at: addr];
            break;
        }
    case _C_STRUCT_B:
        {
            uintptr_t item = (uintptr_t) addr;
            for (
                const char *itemType = strchr(type, '=') + 1, *nextItemType;
                itemType[0] != _C_STRUCT_E;
                itemType = nextItemType
            ) {
                NSUInteger size, alignment;
                nextItemType = NSGetSizeAndAlignment(itemType, &size, &alignment);
                item = (item + alignment - 1) / alignment * alignment;
                [self encodeValueOfObjCType: itemType at: (void *) item];
                item += size;
            }
            break;
        }

    case _C_VOID:
        [NSException raise: NSGenericException
                    format: @"unencodable type: %s", type];
        break;

    default:
        NSLog(@"Unimplemented type: %s", type);
        break;
    }
}

- (void) encodeArrayOfObjCType: (const char *) itemType
                         count: (NSUInteger) count
                            at: (const void *) array
{
    NSUInteger itemSize;
    NSGetSizeAndAlignment(itemType, &itemSize, NULL);

    uintptr_t item = (uintptr_t) array;
    for (NSUInteger i = 0; i < count; i++) {
        [self encodeValueOfObjCType: itemType at: (void *) item];
        item += itemSize;
    }
}

- (void) decodeValueOfObjCType: (const char *) type
                            at: (void *) addr
{
    switch (type[0]) {
    case _C_ID:
        // Note: this does *not* autorelease the object.
        // But decodeObject, which wraps this method, does.
        *(id *) addr = [self decodeRetainedObject];
        break;

    case _C_CLASS:
        *(Class *) addr = decodeClass(self);
        break;

    case _C_CHR:
    case _C_UCHR:
        *(char *) addr = readByte(self);
        break;
    case _C_SHT:
    case _C_USHT:
        readBytes(self, addr, sizeof(short));
        break;

    case _C_BOOL:
        decodeInteger(self, addr, sizeof(_Bool));
        break;
    case _C_INT:
    case _C_UINT:
        decodeInteger(self, addr, sizeof(int));
        break;
    case _C_LNG:
    case _C_ULNG:
        decodeInteger(self, addr, sizeof(long));
        break;
    case _C_LNG_LNG:
    case _C_ULNG_LNG:
        decodeInteger(self, addr, sizeof(long long));
        break;
    case _C_FLT:
        decodeInteger(self, addr, sizeof(float));
        break;
    case _C_DBL:
        decodeInteger(self, addr, sizeof(double));
        break;

    case _C_CHARPTR:
        *(const char **) addr = strdup([decodeString(self) bytes]);
        break;
    case _C_SEL:
        *(SEL *) addr = decodeSelector(self);
        break;

    case _C_PTR:
        {
            BOOL isNull = readByte(self) == 0;
            if (isNull) {
                *(void **) addr = NULL;
            } else {
                [self decodeValueOfObjCType: type + 1 at: *(void **) addr];
            }
            break;
        }

    case _C_ARY_B:
        {
            const char *itemType;
            NSUInteger count = strtol(type + 1, (char **) &itemType, 10);
            [self decodeArrayOfObjCType: itemType
                                  count: count
                                     at: addr];
            break;
        }
    case _C_STRUCT_B:
        {
            uintptr_t item = (uintptr_t) addr;
            for (
                const char *itemType = strchr(type, '=') + 1, *nextItemType;
                itemType[0] != _C_STRUCT_E;
                itemType = nextItemType
            ) {
                NSUInteger size, alignment;
                nextItemType = NSGetSizeAndAlignment(itemType, &size, &alignment);
                item = (item + alignment - 1) / alignment * alignment;
                [self decodeValueOfObjCType: itemType at: (void *) item];
                item += size;
            }
            break;
        }

    case _C_VOID:
        [NSException raise: NSGenericException
                    format: @"undecodable type: %s", type];
        break;

    default:
        NSLog(@"Unimplemented type: %s", type);
        break;
    }
}

- (void) decodeArrayOfObjCType: (const char *) itemType
                         count: (NSUInteger) count
                            at: (void *) array
{
    NSUInteger itemSize;
    NSGetSizeAndAlignment(itemType, &itemSize, NULL);

    uintptr_t item = (uintptr_t) array;
    for (NSUInteger i = 0; i < count; i++) {
        [self decodeValueOfObjCType: itemType at: (void *) item];
        item += itemSize;
    }
}

- (void) encodeBytes: (const void *) data length: (NSUInteger) length {
    encodeInteger(self, &length, sizeof(length));
    if (length > 0) {
        appendBytes(self, data, length);
    }
}

- (void *) decodeBytesWithReturnedLength: (NSUInteger *) length {
    NSUInteger count;
    decodeInteger(self, &count, sizeof(count));
    NSMutableData *data = [NSMutableData dataWithLength: count];
    void *bytes = [data mutableBytes];
    readBytes(self, bytes, count);
    if (length != NULL) {
        *length = count;
    }
    return bytes;
}

- (void) encodeBycopyObject: (id) object {
    [self encodeObject: object isBycopy: YES isByref: NO];
}

- (void) encodeByrefObject: (id) object {
    [self encodeObject: object isBycopy: NO isByref: YES];
}

- (void) encodeObject: (id) object
             isBycopy: (BOOL) isBycopy
              isByref: (BOOL) isByref
{
    // Save isBycopy/isByref, and set them to the given values.
    // We'll restore the originl values in the end.
    BOOL wasBycopy = _isBycopy;
    BOOL wasByref = _isByref;
    _isBycopy = isBycopy;
    _isByref = isByref;

    // Ask the object to replace itself. This will return an instance
    // of NSDistantObject for most types, but some, such as NSString,
    // will return themselves.
    // Note: we never try to replace NSDistantObject's and NSInvocation's.
    BOOL special = [NSInvocation isAncestorOfObject: object] || [NSDistantObject isAncestorOfObject: object];
    if (!special) {
        object = [object replacementObjectForPortCoder: self];
    }

    // First byte is:
    // * 0 for nil,
    // * 1 for a normal object,
    // * 3 for a class.
    if (object == nil) {
        appendByte(self, 0);
        goto out;
    }

    // Note: the following processes classes incorrectly, because [aClass class]
    // will return the class back, instead of its metaclass. But this is what
    // Apple's version appears to do.
    Class class = [object class];
    if (class_isMetaClass(class)) {
        appendByte(self, 3);
        encodeString(self, class_getName(object));
        goto out;
    }

    // OK, so it's a regular object.
    appendByte(self, 1);

    // Re-evaluate whether this class is special. Most likely, yes, because it
    // was almost certainly replaced with an NSDistantObject by this point. In
    // that case, we don't want to attempt to invoke classPortForCoder on it.
    special = [NSInvocation isAncestorOfObject: object] || [NSDistantObject isAncestorOfObject: object];
    if (!special) {
        class = [object classForPortCoder];
    }
    if (!class) {
        [NSException raise: NSInvalidArgumentException format: @"no class to code"];
    }

    // Save the class name...
    encodeString(self, class_getName(class));

    // After the class name, we encode its version, but only if either:
    // * it's not zero,
    // * or there is an ancestor class with a non-zero version.
    // The byte here is:
    // * 1 for a version (original class) or name then version (ancestor),
    // * 0 for the end of ancestors and versions.
    int version = class_getVersion(class);
    BOOL hasEncodedVersion = NO;
    if (version != 0) {
        appendByte(self, 1);
        // Note: no name for the original class here, it goes before this.
        encodeInteger(self, &version, sizeof(version));
        hasEncodedVersion = YES;
    }
    // Now, encode info about ancestors that have non-zero versions.
    for (Class ancestor = class_getSuperclass(class); ancestor; ancestor = class_getSuperclass(ancestor)) {
        int ancestorVersion = class_getVersion(ancestor);
        if (ancestorVersion == 0) {
            continue;
        }
        // We found an ancestor with a non-zero version.
        // Make sure to encode the version of the original class if we
        // haven't already; then encode info about this ancestor.
        if (!hasEncodedVersion) {
            appendByte(self, 1);
            // Ditto.
            encodeInteger(self, &version, sizeof(version));
            hasEncodedVersion = YES;
        }
        appendByte(self, 1);
        encodeString(self, class_getName(ancestor));
        encodeInteger(self, &ancestorVersion, sizeof(ancestorVersion));
    }
    // End of versions and ancestors.
    appendByte(self, 0);

    // Now, ask the object to encode itself.
    // Treat NSInvocation specially, because it doesn't support NSCoding;
    // instead we explicitly support encoding it.
    if ([NSInvocation isAncestorOfObject: object]) {
        [self encodeInvocation: object];
    } else {
        [object encodeWithCoder: self];
    }

    // No idea what this byte is supposed to mean...
    appendByte(self, 1);

out:
    _isBycopy = wasBycopy;
    _isByref = wasByref;
}

- (id) decodeRetainedObject NS_RETURNS_RETAINED {
    char firstByte = readByte(self);
    if (firstByte == 0) {
        return nil;
    } else if (firstByte == 3) {
        // We're not going to get here, but let's still handle it.
        const char *name = [decodeString(self) bytes];
        return objc_getClass(name);
    }

    const char *className = [decodeString(self) bytes];
    Class class = objc_lookUpClass(className);
    if (class == Nil) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"decodeRetainedObject: class \"%s\" not loaded", className];
    }

    BOOL hasEncodedVersion = readByte(self);
    if (hasEncodedVersion) {
        int version;
        decodeInteger(self, &version, sizeof(version));
        NSConnection *connection = [self connection];
        [connection addClassNamed: className version: version];
        while (readByte(self)) {
            const char *ancestorName = [decodeString(self) bytes];
            int ancestorVersion;
            decodeInteger(self, &ancestorVersion, sizeof(ancestorVersion));
            [connection addClassNamed: ancestorName version: ancestorVersion];
        }
    }

    BOOL special;
    id object;
    if (class == [NSDistantObject class]) {
        object = [NSDistantObject newDistantObjectWithCoder: self];
        special = YES;
    } else if (class == [NSInvocation class]) {
        object = [[self decodeInvocation] retain];
        special = YES;
    } else if (class == [NSData class]) {
        object = [[self decodeDataObject] retain];
        special = NO;
    } else if ([self _classAllowed: class]) {
        object = [[class allocWithZone: [self zone]] initWithCoder: self];
        special = NO;
    } else {
        [NSException raise: NSInvalidArgumentException
                    format: @"A disallowed class was decoded (%s)", class_getName(class)];
    }

    if (!special && [object respondsToSelector: @selector(awakeAfterUsingCoder:)]) {
        object = [object awakeAfterUsingCoder: self];
    }

    if (readByte(self) != 1) {
        [NSException raise: NSInternalInconsistencyException
                    format: @"decodeRetainedObject: expected 0x1 after object data"];
    }

    return object;
}

static unsigned int encodeReturnValueType(const char *type) {
    if (isUnknownPointer(type)) {
        return _C_LNG_LNG;
    }

    switch (type[0]) {
    case _C_INT:
        return _C_LNG;
    case _C_UCHR:
        return _C_CHR;
    case _C_UINT:
        return _C_LNG;
    case _C_USHT:
       return _C_SHT;
    case _C_ULNG:
        return _C_LNG;
    case _C_ULNG_LNG:
        return _C_LNG_LNG;
    case _C_CLASS:
        return _C_ID;
    default:
        return type[0];
    }
}

- (void) encodeInvocation: (NSInvocation *) invocation {
    [self encodeObject: [invocation target] isBycopy: NO isByref: NO];

    NSMethodSignature *signature = [invocation methodSignature];
    NSUInteger numberOfArguments = [signature numberOfArguments];
    encodeInteger(self, &numberOfArguments, sizeof(numberOfArguments));

    encodeSelector(self, [invocation selector]);
    encodeString(self, [[signature _typeString] UTF8String]);

    NSMethodType *returnValue = [signature _argInfo: 0];
    // Note: this is obviously lossy, for example it will encode
    // _C_STRUCT_B, but not the item types, for a struct. And why
    // even bother considering we have encoded the full type above
    // as a part of signature?
    const char *returnValueType = stripQualifiersAndComments(returnValue->type);
    unsigned int encodedReturnValueType = encodeReturnValueType(returnValueType);
    encodeInteger(self, &encodedReturnValueType, sizeof(encodedReturnValueType));

    for (NSUInteger index = 2; index < numberOfArguments; index++) {
        NSMethodType *arg = [signature _argInfo: index + 1];
        const char *type = stripQualifiersAndComments(arg->type);
        if (type[0] == _C_PTR) {
            if (isUnknownPointer(type)) {
                // We completely ignore (void *) and similar unknown pointer
                // types. We don't even encode whether the pointer is NULL or
                // non-NULL.
                continue;
            }
            void *ptr;
            [invocation getArgument: &ptr atIndex: index];
            // Note: we encode 1 for NULL and 0 for non-NULL, unlike
            // how we do it in other places.
            appendByte(self, ptr == NULL);
            // Only encode the pointee if the pointer is not NULL and
            // is not out-only.
            if (ptr != NULL && !hasQualifier(arg->type, type, 'o')) {
                [self encodeValueOfObjCType: type + 1 at: ptr];
            }
        } else if (type[0] == _C_ID) {
            BOOL isBycopy = hasQualifier(arg->type, type, 'O');
            BOOL isByref = hasQualifier(arg->type, type, 'R');
            id object;
            [invocation getArgument: &object atIndex: index];
            [self encodeObject: object isBycopy: isBycopy isByref: isByref];
        } else {
            [self encodeValueOfObjCType: type at: [invocation _idxToArg: index + 1]];
        }
    }
}

- (NSInvocation *) decodeInvocation {
    id target = [self decodeRetainedObject];

    NSUInteger numberOfArguments;
    decodeInteger(self, &numberOfArguments, sizeof(numberOfArguments));

    SEL selector = decodeSelector(self);
    const char *types = [decodeString(self) bytes];
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes: types];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature: signature];
    [invocation retainArguments];

    [invocation setTarget: target];
    [invocation setSelector: selector];
    [target release];

    unsigned int encodedReturnValueType;
    decodeInteger(self, &encodedReturnValueType, sizeof(encodedReturnValueType));
    // TODO: is this used in any way...?

    for (NSUInteger index = 2; index < numberOfArguments; index++) {
        NSMethodType *arg = [signature _argInfo: index + 1];
        const char *type = stripQualifiersAndComments(arg->type);
        if (type[0] == _C_PTR) {
            if (isUnknownPointer(type)) {
                // There's nothing for us to decode.
                continue;
            }
            // Note: this has reverse meaning to how it's usually encoded.
            BOOL isNull = readByte(self) == 1;
            void *ptr = NULL;
            // Only decode the pointee value is the pointer was not NULL
            // and was not out-only.
            if (!isNull && !hasQualifier(arg->type, type, 'o')) {
                // We need somewhere to decode the pointee to. We'll place it in
                // a NSMutableData that's attached to the invocation.
                NSUInteger size;
                NSGetSizeAndAlignment(arg->type, &size, NULL);
                NSMutableData *data = [NSMutableData dataWithLength: size];
                ptr = [data mutableBytes];
                [self decodeValueOfObjCType: type + 1 at: ptr];
                [invocation _addAttachedObject: data];
            }
            [invocation setArgument: &ptr atIndex: index];
        } else if (type[0] == _C_ID) {
            id object = [self decodeObject];
            [invocation setArgument: &object atIndex: index];
        } else if (type[0] == _C_CHARPTR) {
            char *str;
            [self decodeValueOfObjCType: type at: &str];
            [invocation setArgument: &str atIndex: index];
            free(str);
        } else {
            [self decodeValueOfObjCType: type at: [invocation _idxToArg: index + 1]];
        }
    }

    return invocation;
}

- (void) encodeReturnValue: (NSInvocation *) invocation {
    // Start by actually encoding the return value.
    NSMethodSignature *signature = [invocation methodSignature];
    NSMethodType *returnValue = [signature _argInfo: 0];
    const char *returnValueType = stripQualifiersAndComments(returnValue->type);
    if (returnValueType[0] != _C_VOID) {
        [self encodeValueOfObjCType: returnValueType at: [invocation _idxToArg: 0]];
    }

    // Additionally, encode pointer arguments pointees.
    NSUInteger numberOfArguments = [signature numberOfArguments];
    for (NSUInteger index = 2; index < numberOfArguments; index++) {
        NSMethodType *arg = [signature _argInfo: index + 1];
        const char *type = stripQualifiersAndComments(arg->type);
        // We're only interested in pointer types.
        if (type[0] != _C_PTR || isUnknownPointer(type)) {
            continue;
        }
        // Get the actual pointer.
        void *ptr;
        [invocation getArgument: &ptr atIndex: index];
        // Only encode the pointee if the pointer was not NULL and
        // is not in-only.
        if (ptr != NULL && !hasQualifier(arg->type, type, 'n')) {
            [self encodeValueOfObjCType: type + 1 at: ptr];
        }
    }
}

- (void) decodeReturnValue: (NSInvocation *) invocation {
    // This will only work if the invocation retains its arguments, so...
    [invocation retainArguments];
    NSMethodSignature *signature = [invocation methodSignature];

    // Decode the return value.
    NSMethodType *returnValue = [signature _argInfo: 0];
    const char *returnValueType = stripQualifiersAndComments(returnValue->type);
    switch (returnValueType[0]) {
    case _C_VOID:
        // Do nothing.
        break;
    case _C_ID:
        {
            id object = [self decodeObject];
            [invocation setReturnValue: &object];
            break;
        }
    case _C_CHARPTR:
        {
            char *str;
            [self decodeValueOfObjCType: returnValueType at: &str];
            [invocation setReturnValue: &str];
            free(str);
            break;
        }
    case _C_PTR:
        {
            // We need somewhere to decode the pointee to. We'll place it in
            // a NSMutableData that's attached to the invocation.
            NSUInteger size;
            NSGetSizeAndAlignment(returnValueType + 1, &size, NULL);
            NSMutableData *data = [NSMutableData dataWithLength: size];
            void *ptr = [data mutableBytes];
            [self decodeValueOfObjCType: returnValueType at: &ptr];
            if (ptr != NULL) {
                [invocation _addAttachedObject: data];
            }
            [invocation setReturnValue: &ptr];
            break;
        }
    default:
        [self decodeValueOfObjCType: returnValueType at: [invocation _idxToArg: 0]];
        break;
    }

    // Additionally, decode pointer arguments pointees.
    NSUInteger numberOfArguments = [signature numberOfArguments];

    for (NSUInteger index = 2; index < numberOfArguments; index++) {
        NSMethodType *arg = [signature _argInfo: index + 1];
        const char *type = stripQualifiersAndComments(arg->type);
        // We're only interested in pointer types.
        if (type[0] != _C_PTR || isUnknownPointer(type)) {
            continue;
        }
        // Get the actual pointer.
        void *ptr;
        [invocation getArgument: &ptr atIndex: index];
        // Only decode the pointee if the pointer was not NULL and
        // is not in-only.
        if (ptr != NULL && !hasQualifier(arg->type, type, 'n')) {
            [self decodeValueOfObjCType: type + 1 at: ptr];
        }
    }
}

- (void) encodeDataObject: (NSData *) data {
    NSUInteger length = [data length];
    BOOL isLarge = length >= PAGE_SIZE;
    appendByte(self, isLarge);
    if (isLarge) {
        [_components addObject: data];
    } else {
        encodeInteger(self, &length, sizeof(length));
        appendBytes(self, [data bytes], length);
    }
}

- (NSData *) decodeDataObject {
    BOOL isLarge = readByte(self);
    if (isLarge) {
        return _components[_componentIndex++];
    } else {
        NSRange range;
        decodeInteger(self, &range.length, sizeof(range.length));
        range.location = _readingOffset;
        NSData *data = [_components[_componentIndex] subdataWithRange: range];
        advanceComponentIfNeeded(self);
        return data;
    }
}

@end
