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

#import "NSKeyedPortCoder.h"
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSException.h>
#import <Foundation/NSConnection.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSPropertyList.h>
#import <Foundation/NSDistantObject.h>
#import <CoreFoundation/NSObjCRuntimeInternal.h>
#import <CoreFoundation/NSInvocationInternal.h>
#import "NSObjectInternal.h"
#import "NSPortCoderUtil.h"
#import <objc/runtime.h>


@interface NSObject (IsAncestorOfObject)
+ (BOOL) isAncestorOfObject: (id) object;
@end

@implementation NSKeyedPortCoder

- (instancetype) initWithReceivePort: (NSPort *) recvPort
                            sendPort: (NSPort *) sendPort
                          components: (NSArray *) components
{
    _recvPort = [recvPort retain];
    _sendPort = [sendPort retain];

    if (components == nil) {
        _components = [[NSMutableArray alloc] initWithCapacity: 1];
        [_components addObject: [NSData data]];
        _root = [[NSMutableDictionary alloc] initWithCapacity: 2];
    } else {
        _components = [components mutableCopy];
        NSError *error = nil;
        _root = [NSPropertyListSerialization
                    propertyListWithData: _components[0]
                                 options: 0
                                  format: NULL
                                   error: &error
                 ];

        if (error != nil) {
            [NSException raise: NSInvalidArgumentException
                        format: @"Failed to deserialize port coder data: %@", error];
        }

        [_root retain];
    }

    _containerStack = [[NSMutableArray alloc] initWithCapacity: 4];
    [_containerStack addObject: _root];

    return self;
}

- (void) dealloc {
    [_recvPort release];
    [_sendPort release];
    [_components release];
    [_containerStack release];
    [_root release];
    [super dealloc];
}

- (BOOL) allowsKeyedCoding {
    return YES;
}

- (BOOL) isBycopy {
    return _isBycopy;
}

- (BOOL) isByref {
    return _isByref;
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
    // Note: NSKeyedPortCoder, unlike NSUnkeyedPortCoder, doesn't
    // encode/decode class versions, and so doesn't/can't use
    // [[self connection] versionForClassNamed: className].
    Class class = NSClassFromString(className);
    if (class == Nil) {
        return NSIntegerMax;
    }
    return class_getVersion(class);
}

static NSString * const unkeyedObjectsKey = @"$g";
static NSString * const oolKey = @"ool";
static NSString * const classNameKey = @"$cn";
static NSString * const metaClassKey = @"$mc";
static NSString * const nilKey = @"$n";
static NSString * const targetKey = @"tg";
static NSString * const selectorKey = @"se";
static NSString * const typeStringKey = @"ty";
static NSString * const pointersAreNullKey = @"nl";
static NSString * const returnPointersAreNullKey = @"rtnl";

static void putValue(NSKeyedPortCoder *self, id object, NSString *key) {
    // Add the given object to the container that's currently top in the stack.
    ContainerType topContainer = [self->_containerStack lastObject];
    if (key != nil) {
        // Easy case: just put it there.
        topContainer[key] = object;
    } else {
        // All objects that lack a key are stored in a special array.
        NSMutableArray *unkeyedObjects = topContainer[unkeyedObjectsKey];
        if (unkeyedObjects == nil) {
            unkeyedObjects = [NSMutableArray arrayWithCapacity: 1];
            topContainer[unkeyedObjectsKey] = unkeyedObjects;
        }
        [unkeyedObjects addObject: object];
    }
}

static id readValue(NSKeyedPortCoder *self, NSString *key) {
    // Read the value by the given key from the container at the top of the stack.
    ContainerType topContainer = [self->_containerStack lastObject];
    if (key != nil) {
        // Easy case: just get it from there.
        return topContainer[key];
    } else {
        // All objects that lack a key are stored in a special array.
        NSMutableArray *unkeyedObjects = topContainer[unkeyedObjectsKey];
        return unkeyedObjects[self->_genericKey++];
    }
}

static void putOOLValue(NSKeyedPortCoder *self, id object, NSString *key) {
    // Add an out-of-line object.
    // We add the OOL object itself to components and remember its index.
    NSUInteger index = [self->_components count];
    [self->_components addObject: object];

    // We encode the key and the index of the OOL object in a special dictionary.
    ContainerType topContainer = [self->_containerStack lastObject];
    NSMutableDictionary *oolObjects = topContainer[oolKey];
    if (oolObjects == nil) {
        oolObjects = [NSMutableDictionary dictionaryWithCapacity: 1];
        topContainer[oolKey] = oolObjects;
    }

    // If the key is nil, we have to synthesize a key.
    if (key == nil) {
        // Note: unlike the regular generic key (used for unkeyed objects), the
        // generic OOL key is not scoped, i.e. it increases the whole time.
        key = [NSString stringWithFormat: @"%@%lu",
                        unkeyedObjectsKey,
                        (unsigned long) self->_genericOOLKey++];
    }

    oolObjects[key] = @(index);
}

static id readOOLValue(NSKeyedPortCoder *self, NSString *key) {
    ContainerType topContainer = [self->_containerStack lastObject];
    NSMutableDictionary *oolObjects = topContainer[oolKey];

    // If the key is nil, we have to synthesize a key.
    if (key == nil) {
        key = [NSString stringWithFormat: @"%@%lu",
                        unkeyedObjectsKey,
                        (unsigned long) self->_genericOOLKey++];
    }

    NSUInteger index = [oolObjects[key] integerValue];
    if (index == 0) {
        // You're not supposed to reference the first component (it contains the
        // main data, not OOL objects), and if we get here, oolObjects was
        // likely nil in the first place...
        return nil;
    }
    return self->_components[index];
}

static void beginEncodingObject(NSKeyedPortCoder *self, NSString *key) {
    // Make a fresh container for this object, and push it to the top of the stack.
    ContainerType container = [NSMutableDictionary dictionaryWithCapacity: 2];
    putValue(self, container, key);
    [self->_containerStack addObject: container];
}

static void endObject(NSKeyedPortCoder *self) {
    [self->_containerStack removeLastObject];
}

- (void) encodeBool: (BOOL) value forKey: (NSString *) key {
    putValue(self, @(value), key);
}

- (BOOL) decodeBoolForKey: (NSString *) key {
    return [readValue(self, key) boolValue];
}

- (void) encodeInt: (int) value forKey: (NSString *) key {
    putValue(self, @(value), key);
}

- (int) decodeIntForKey: (NSString *) key {
    return [readValue(self, key) intValue];
}

- (void) encodeInteger: (NSInteger) value forKey: (NSString *) key {
    putValue(self, @(value), key);
}

- (NSInteger) decodeIntegerForKey: (NSString *) key {
    return [readValue(self, key) integerValue];
}

- (void) encodeInt32: (int32_t) value forKey: (NSString *) key {
    putValue(self, @(value), key);
}

- (int32_t) decodeInt32ForKey: (NSString *) key {
    return [readValue(self, key) longValue];
}

- (void) encodeInt64: (int64_t) value forKey: (NSString *) key {
    putValue(self, @(value), key);
}

- (int64_t) decodeInt64ForKey: (NSString *) key {
    return [readValue(self, key) longValue];
}

- (void) encodeFloat: (float) value forKey: (NSString *) key {
    putValue(self, @(value), key);
}

- (float) decodeFloatForKey: (NSString *) key {
    return [readValue(self, key) floatValue];
}

- (void) encodeDouble: (double) value forKey: (NSString *) key {
    putValue(self, @(value), key);
}

- (double) decodeDoubleForKey: (NSString *) key {
    return [readValue(self, key) doubleValue];
}

- (void) encodeBytes: (const uint8_t *) bytes
              length: (NSUInteger) length
              forKey: (NSString *) key
{
    putValue(self, [NSData dataWithBytes: bytes length: length], key);
}

- (const uint8_t *) decodeBytesForKey: (NSString *) key
                       returnedLength: (NSUInteger *) length
{
    NSData *data = readValue(self, key);
    if (length != NULL) {
        *length = [data length];
    }
    return [data bytes];
}

- (void) encodePortObject: (NSPort *) port {
    putOOLValue(self, port, nil);
}

- (NSPort *) decodePortObject {
    return readOOLValue(self, nil);
}

- (void) encodePortObject: (NSPort *) port forKey: (NSString *) key {
    putOOLValue(self, port, key);
}

- (NSPort *) decodePortObjectForKey: (NSString *) key {
    return readOOLValue(self, key);
}

- (void) encodeDataObject: (NSData *) data {
    putOOLValue(self, data, nil);
}

- (NSData *) decodeDataObject {
    return readOOLValue(self, nil);
}

- (void) encodeDataObject: (NSData *) data forKey: (NSString *) key {
    putOOLValue(self, data, key);
}

- (NSData *) decodeDataObjectForKey: (NSString *) key {
    return readOOLValue(self, key);
}

- (void) encodeValueOfObjCType: (const char *) type at: (const void *) addr {
    id object;

    switch (type[0]) {
    case _C_ID:
        object = *(id *) addr;
        break;
    case _C_CHR:
        object = @(*(char *) addr);
        break;
    case _C_UCHR:
        object = @(*(unsigned char *) addr);
        break;
    case _C_SHT:
        object = @(*(short *) addr);
    case _C_USHT:
        object = @(*(unsigned short *) addr);
        break;
    case _C_BOOL:
        // Note: _C_BOOL actually represents a C _Bool, not a objc BOOL (which
        // is a _C_CHR), but a _C_BOOL gets encoded as a CFBoolean, so this is
        // what we do.
        object = @(*(BOOL *) addr);
        break;
    case _C_INT:
        object = @(*(int *) addr);
        break;
    case _C_UINT:
        object = @(*(unsigned int *) addr);
        break;
    case _C_LNG:
        object = @(*(long *) addr);
        break;
    case _C_ULNG:
        object = @(*(unsigned long *) addr);
        break;
    case _C_LNG_LNG:
        object = @(*(long long *) addr);
        break;
    case _C_ULNG_LNG:
        object = @(*(unsigned long long *) addr);
        break;
    case _C_FLT:
        object = @(*(float *) addr);
        break;
    case _C_DBL:
        object = @(*(double *) addr);
        break;
    case _C_CHARPTR:
        {
            const char *str = *(const char **) addr;
            object = [NSData dataWithBytes: str length: strlen(str)];
            break;
        }
    case _C_SEL:
        {
            SEL selector = *(SEL *) addr;
            if (selector) {
                object = @(sel_getName(selector));
            } else {
                object = nil;
            }
            break;
        }

    case _C_PTR:
        {
            void *ptr = *(void **) addr;
            BOOL isNull = ptr == NULL;
            [self encodeBool: !isNull forKey: nil];
            if (!isNull) {
                [self encodeValueOfObjCType: type + 1 at: ptr];
            }
            return;
        }

    case _C_ARY_B:
        {
            const char *itemType;
            NSUInteger count = strtol(type + 1, (char **) &itemType, 10);
            [self encodeArrayOfObjCType: itemType
                                  count: count
                                     at: addr];
            return;
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
            return;
        }

    case _C_CLASS:
        {
            // Normally, this could be handled by the generic code path for
            // object. However, encodeObject:forKey: does not actually support
            // classes, even though it believes it does. So simulate what it
            // would encode explicitly.
            Class class = *(Class *) addr;
            beginEncodingObject(self, nil);
            putValue(self, @(class_getName(class)), classNameKey);
            putValue(self, @YES, metaClassKey);
            endObject(self);
            return;
        }

    default:
        NSLog(@"Unimplemented type: %s", type);
        return;
    }

    [self encodeObject: object forKey: nil];
}

- (void) encodeArrayOfObjCType: (const char *) itemType
                         count: (NSUInteger) count
                            at: (const void *) array
{
    NSUInteger itemSize;
    NSGetSizeAndAlignment(itemType, &itemSize, NULL);

    const char *item = (const char *) array;
    for (NSUInteger i = 0; i < count; i++) {
        [self encodeValueOfObjCType: itemType at: item];
        item += itemSize;
    }
}

- (void) decodeValueOfObjCType: (const char *) type at: (void *) addr {
    switch (type[0]) {
    case _C_PTR:
        {
            BOOL isNull = ![self decodeBoolForKey: nil];
            if (isNull) {
                *(void **) addr = NULL;
            } else {
                [self decodeValueOfObjCType: type + 1 at: *(void **) addr];
            }
            return;
        }
    case _C_ARY_B:
        {
            const char *itemType;
            NSUInteger count = strtol(type + 1, (char **) &itemType, 10);
            [self decodeArrayOfObjCType: itemType
                                  count: count
                                     at: addr];
            return;
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
            return;
        }
    default:
        break;
    }

    id object = [self decodeObjectForKey: nil];

    switch (type[0]) {
    case _C_ID:
    case _C_CLASS:
        *(id *) addr = [object retain];
        break;
    case _C_CHR:
        *(char *) addr = [object charValue];
        break;
    case _C_UCHR:
        *(unsigned char *) addr = [object unsignedCharValue];
        break;
    case _C_SHT:
        *(short *) addr = [object shortValue];
    case _C_USHT:
        *(unsigned short *) addr = [object unsignedShortValue];
        break;
    case _C_BOOL:
        // Note: _C_BOOL actually represents a C _Bool, not a objc BOOL (which
        // is a _C_CHR), but a _C_BOOL gets encoded as a CFBoolean, so this is
        // what we do.
        *(BOOL *) addr = [object boolValue];
        break;
    case _C_INT:
        *(int *) addr = [object intValue];
        break;
    case _C_UINT:
        *(unsigned int *) addr = [object unsignedIntValue];
        break;
    case _C_LNG:
        *(long *) addr = [object longValue];
        break;
    case _C_ULNG:
        *(unsigned long *) addr = [object unsignedLongValue];
        break;
    case _C_LNG_LNG:
        *(long long *) addr = [object longLongValue];
        break;
    case _C_ULNG_LNG:
        *(unsigned long long *) addr = [object unsignedLongLongValue];
        break;
    case _C_FLT:
        *(float *) addr = [object floatValue];
        break;
    case _C_DBL:
        *(double *) addr = [object doubleValue];
        break;
    case _C_CHARPTR:
        *(const char **) addr = strdup([object bytes]);
        break;
    case _C_SEL:
        *(SEL *) addr = NSSelectorFromString(object);
        break;
    }
}

- (void) decodeArrayOfObjCType: (const char *) itemType
                         count: (NSUInteger) count
                            at: (void *) array
{
    NSUInteger itemSize;
    NSGetSizeAndAlignment(itemType, &itemSize, NULL);

    char *item = (char *) array;
    for (NSUInteger i = 0; i < count; i++) {
        [self decodeValueOfObjCType: itemType at: item];
        item += itemSize;
    }
}

static void encodeObject(NSKeyedPortCoder *self, id object, BOOL isBycopy, BOOL isByref) {
    BOOL wasBycopy = self->_isBycopy;
    BOOL wasByref = self->_isByref;
    self->_isBycopy = isBycopy;
    self->_isByref = isByref;
    [self encodeObject: object forKey: nil];
    self->_isBycopy = wasBycopy;
    self->_isByref = wasByref;
}

- (void) encodeBycopyObject: (id) object {
    encodeObject(self, object, YES, NO);
}

- (void) encodeByrefObject: (id) object {
    encodeObject(self, object, NO, YES);
}

- (void) encodeObject: (id) object forKey: (NSString *) key {
    // Ask the object to replace itself. This will return an instance
    // of NSDistantObject for most types, but some, such as NSString,
    // will return themselves.
    // Note: we never try to replace NSDistantObject's and NSInvocation's.
    BOOL special = [NSInvocation isAncestorOfObject: object] || [NSDistantObject isAncestorOfObject: object];
    if (!special) {
        object = [object replacementObjectForPortCoder: self];
    }

    // We encode some common property list types (but notably, not NSDictionary)
    // as themselves. It's important that we do this check after running the
    // replacement above.
    if (
        !special && (
            [object isKindOfClass: [NSData class]] ||
            [object isKindOfClass: [NSString class]] ||
            [object isKindOfClass: [NSNumber class]]
        )
    ) {
        putValue(self, object, key);
        return;
    }

    beginEncodingObject(self, key);

    if (object == nil) {
        putValue(self, @YES, nilKey);
        goto out;
    }

    // Note: the following processes classes incorrectly, because [aClass class]
    // will return the class back, instead of its metaclass. But this is what
    // Apple's version appears to do.
    Class class = [object class];
    if (class_isMetaClass(class)) {
        putValue(self, @(class_getName(object)), classNameKey);
        putValue(self, @YES, metaClassKey);
        goto out;
    }

    // OK, so it's a regular object.
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
    putValue(self, @(class_getName(class)), classNameKey);

    // Now, ask the object to encode itself.
    // Treat NSInvocation specially, because it doesn't support NSCoding;
    // instead we explicitly support encoding it.
    if ([NSInvocation isAncestorOfObject: object]) {
        [self encodeInvocation: object];
    } else {
        [object encodeWithCoder: self];
    }

out:
    endObject(self);
}

- (id) decodeObjectForKey: (NSString *) key {
    id value = readValue(self, key);
    // We encode some common property list types (but notably, not NSDictionary)
    // as themselves.
    if (
        [value isKindOfClass: [NSData class]] ||
        [value isKindOfClass: [NSString class]] ||
        [value isKindOfClass: [NSNumber class]]
    ) {
        return value;
    }

    [_containerStack addObject: (ContainerType) value];
    NSUInteger savedGenericKey = _genericKey;
    _genericKey = 0;
    id object;

    BOOL isNil = [readValue(self, nilKey) boolValue];
    if (isNil) {
        object = nil;
        goto out;
    }

    NSString *className = readValue(self, classNameKey);
    Class class = NSClassFromString(className);
    BOOL isMetaClass = [readValue(self, metaClassKey) boolValue];
    if (isMetaClass) {
        object = class;
        goto out;
    }

    BOOL special;
    if (class == [NSDistantObject class]) {
        object = [[NSDistantObject newDistantObjectWithCoder: self] autorelease];
        special = YES;
    } else if (class == [NSInvocation class]) {
        object = [self decodeInvocation];
        special = YES;
    } else if ([self _classAllowed: class]) {
        object = [[[class allocWithZone: [self zone]] initWithCoder: self] autorelease];
        special = NO;
    } else {
        [NSException raise: NSInvalidArgumentException
                    format: @"A disallowed class was decoded (%s)", class_getName(class)];
    }

    if (!special && [object respondsToSelector: @selector(awakeAfterUsingCoder:)]) {
        object = [object awakeAfterUsingCoder: self];
    }

out:
    _genericKey = savedGenericKey;
    [_containerStack removeLastObject];
    return object;
}

- (void) encodeInvocation: (NSInvocation *) invocation {
    [self encodeObject: [invocation target] forKey: targetKey];

    NSMethodSignature *signature = [invocation methodSignature];
    NSUInteger numberOfArguments = [signature numberOfArguments];

    SEL selector = [invocation selector];
    if (selector) {
        const char *selectorName = sel_getName(selector);
        putValue(self, [NSData dataWithBytes: selectorName length: strlen(selectorName) + 1], selectorKey);
    } else {
        putValue(self, [NSData data], selectorKey);
    }
    [self encodeObject: [signature _typeString] forKey: typeStringKey];

    NSMutableArray<NSNumber *> *pointersAreNull = [NSMutableArray arrayWithCapacity: numberOfArguments - 2];

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
            // Record whether the pointer is NULL or not.
            BOOL isNull = ptr == NULL;
            [pointersAreNull addObject: @(isNull)];
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
            encodeObject(self, object, isBycopy, isByref);
        } else {
            [self encodeValueOfObjCType: type at: [invocation _idxToArg: index + 1]];
        }
    }

    [self encodeObject: pointersAreNull forKey: pointersAreNullKey];
}

- (NSInvocation *) decodeInvocation {
    id target = [self decodeObjectForKey: targetKey];
    NSUInteger selectorLength;
    const char *rawSelector = (const char *) [self decodeBytesForKey: selectorKey
                                                      returnedLength: &selectorLength];
    SEL selector;
    if (selectorLength > 0) {
        selector = sel_registerName(rawSelector);
    } else {
        selector = NULL;
    }

    const char *types = [[self decodeObjectForKey: typeStringKey] UTF8String];
    NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes: types];
    NSUInteger numberOfArguments = [signature numberOfArguments];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature: signature];
    [invocation retainArguments];

    [invocation setTarget: target];
    [invocation setSelector: selector];

    NSArray<NSNumber *> *pointersAreNull = [self decodeObjectForKey: pointersAreNullKey];

    for (NSUInteger index = 2; index < numberOfArguments; index++) {
        NSMethodType *arg = [signature _argInfo: index + 1];
        const char *type = stripQualifiersAndComments(arg->type);
        if (type[0] == _C_PTR) {
            if (isUnknownPointer(type)) {
                // There's nothing for us to decode.
                continue;
            }
            BOOL isNull = [pointersAreNull[index - 2] boolValue];
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

- (void) encodeReturnValueOfInvocation: (NSInvocation *) invocation
                                forKey: (NSString *) key
{
    beginEncodingObject(self, key);

    // Start by actually encoding the return value.
    NSMethodSignature *signature = [invocation methodSignature];
    NSMethodType *returnValue = [signature _argInfo: 0];
    const char *returnValueType = stripQualifiersAndComments(returnValue->type);
    if (returnValueType[0] != _C_VOID) {
        [self encodeValueOfObjCType: returnValueType at: [invocation _idxToArg: 0]];
    }

    // Additionally, encode pointer arguments pointees.
    NSUInteger numberOfArguments = [signature numberOfArguments];
    NSMutableArray<NSNumber *> *pointersAreNull = [NSMutableArray arrayWithCapacity: numberOfArguments - 2];

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
        // Record whether the pointer is NULL or not.
        BOOL isNull = ptr == NULL;
        [pointersAreNull addObject: @(isNull)];
        // Only encode the pointee if the pointer was not NULL and
        // is not in-only.
        if (ptr != NULL && !hasQualifier(arg->type, type, 'n')) {
            [self encodeValueOfObjCType: type + 1 at: ptr];
        }
    }

    [self encodeObject: pointersAreNull forKey: returnPointersAreNullKey];

    endObject(self);
}

- (void) decodeReturnValueOfInvocation: (NSInvocation *) invocation
                                forKey: (NSString *) key
{
    ContainerType container = readValue(self, key);
    [_containerStack addObject: container];
    NSUInteger savedGenericKey = _genericKey;
    _genericKey = 0;

    // This will only work if the invocation retains its
    // arguments, so...
    [invocation retainArguments];
    NSMethodSignature *signature = [invocation methodSignature];

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
    NSArray<NSNumber *> *pointersAreNull = [self decodeObjectForKey: returnPointersAreNullKey];
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
        BOOL isNull = [pointersAreNull[index - 2] boolValue];
        NSAssert(isNull == (ptr == NULL), @"nullness mismatch");
        if (!isNull && !hasQualifier(arg->type, type, 'n')) {
            [self decodeValueOfObjCType: type + 1 at: ptr];
        }
    }

    _genericKey = savedGenericKey;
    [_containerStack removeLastObject];
}

- (NSArray *) finishedComponents {
    if (!_finished) {
        NSError *error = nil;
        NSData *data = [NSPropertyListSerialization
                           dataWithPropertyList: _root
                                         format: NSPropertyListBinaryFormat_v1_0
                                        options: 0
                                          error: &error];
        if (error != nil) {
            [NSException raise: NSInvalidArgumentException
                        format: @"Failed to serialize port coder data: %@", error];
        }

        _components[0] = data;
        _finished = YES;
    }

    return _components;
}

@end
