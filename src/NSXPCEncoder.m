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

#import "NSXPCEncoder.h"
#import "NSXPCSerialization.h"
#import "NSXPCSerializationObjC.h"
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSException.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#import <CoreFoundation/NSInvocationInternal.h>
#import <objc/runtime.h>


@implementation NSXPCEncoder

- (instancetype) init {
    return [self initWithStackSpace: NULL size: 0];
}

- (instancetype) initWithStackSpace: (unsigned char *) buffer
                               size: (size_t) bufferSize
{
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _NSXPCSerializationStartWrite(&_serializer, buffer, bufferSize);
    return self;
}

- (BOOL) allowsKeyedCoding {
    return YES;
}

- (void) encodeBool: (BOOL) value forKey: (NSString *) key {
    _NSXPCSerializationAddString(&_serializer, (CFStringRef) key, YES);
    _NSXPCSerializationAddBool(&_serializer, value);
}

- (void) encodeFloat: (float) value forKey: (NSString *) key {
    _NSXPCSerializationAddString(&_serializer, (CFStringRef) key, YES);
    _NSXPCSerializationAddFloat(&_serializer, value);
}

- (void) encodeDouble: (double) value forKey: (NSString *) key {
    _NSXPCSerializationAddString(&_serializer, (CFStringRef) key, YES);
    _NSXPCSerializationAddDouble(&_serializer, value);
}

- (void) encodeInt: (int) value forKey: (NSString *) key {
    _NSXPCSerializationAddString(&_serializer, (CFStringRef) key, YES);
    _NSXPCSerializationAddInteger(&_serializer, value);
}

- (void) encodeInt32: (int32_t) value forKey: (NSString *) key {
    _NSXPCSerializationAddString(&_serializer, (CFStringRef) key, YES);
    _NSXPCSerializationAddInteger(&_serializer, value);
}

- (void) encodeInt64: (int64_t) value forKey: (NSString *) key {
    _NSXPCSerializationAddString(&_serializer, (CFStringRef) key, YES);
    _NSXPCSerializationAddInteger(&_serializer, value);
}

- (void) encodeInteger: (NSInteger) value forKey: (NSString *) key {
    _NSXPCSerializationAddString(&_serializer, (CFStringRef) key, YES);
    _NSXPCSerializationAddInteger(&_serializer, value);
}

- (void) encodeBytes: (const unsigned char *) addr
              length: (NSUInteger) length
              forKey: (NSString *) key
{
    _NSXPCSerializationAddString(&_serializer, (CFStringRef) key, YES);
    _NSXPCSerializationAddRawData(&_serializer, addr, length);
}

- (id) _replaceObject: (id) object {
    // TODO
    return object;
}

- (void) _checkObject: (id) object {
    // TODO
}

- (size_t) _encodeOOLXPCObject: (xpc_object_t) object {
    if (_oolObjects == NULL) {
        _oolObjects = xpc_array_create(NULL, 0);
    }
    size_t index = xpc_array_get_count(_oolObjects);
    xpc_array_append_value(_oolObjects, object);
    return index;
}

- (void) _encodeObject: (id) object {
    if (object == nil) {
        _NSXPCSerializationAddNull(&_serializer);
        return;
    }

    // We encode some common property list types as themsevles.
    if ([object isKindOfClass: [NSData class]]) {
        _NSXPCSerializationAddData(&_serializer, (CFDataRef) object);
        return;
    } else if ([object isKindOfClass: [NSString class]]) {
        // TODO: why NO here?
        _NSXPCSerializationAddString(&_serializer, (CFStringRef) object, NO);
        return;
    } else if ([object isKindOfClass: [NSNumber class]]) {
        _NSXPCSerializationAddNumber(&_serializer, (CFNumberRef) object);
        return;
    }

    NSUInteger savedGenericKey = _genericKey;
    _genericKey = 0;

    _NSXPCSerializationStartDictionaryWrite(&_serializer);

    // Note: unlike NSPortCoder, the following
    // at least detects classes correctly.
    Class class = object_getClass(object);
    if (class_isMetaClass(class)) {
        [NSException raise: NSInvalidArgumentException
                    format: @"Encoding classes is not supported"];
    }

    class = [object classForCoder];
    if (!class) {
        [NSException raise: NSInvalidArgumentException
                    format: @"No class to encode"];
    }

    static const char classNameKey[] = "$class";
    const char *className = class_getName(class);
    _NSXPCSerializationAddASCIIString(
        &_serializer,
        classNameKey,
        strlen(classNameKey)
    );
    _NSXPCSerializationAddASCIIString(
        &_serializer,
        className,
        strlen(className)
    );

    // See if it's an XPC object that we need to encode out-of-line.
    if (NO) {
        // It's an XPC object; we encode those out-of-line.
        static const char oolXpcKey[] = "$xpc";
        _NSXPCSerializationAddASCIIString(
            &_serializer,
            oolXpcKey,
            strlen(oolXpcKey)
        );
        // Add it to the OOL array and encode its index.
        size_t index = [self _encodeOOLXPCObject: (xpc_object_t) object];
        _NSXPCSerializationAddInteger(&_serializer, index);
    } else {
        // Just as the object to encode itself.
        [object encodeWithCoder: self];
    }

    _NSXPCSerializationEndDictionaryWrite(&_serializer);
    _genericKey = savedGenericKey;
}

- (void) encodeObject: (id) object forKey: (NSString *) key {
    // Check the object before we attempt to encode the key.
    // This is so that if we end up rejecting the object and
    // throwing and exception, we don't corrupt the encoded data.
    object = [self _replaceObject: object];
    [self _checkObject: object];

    // This method, unlike other methods, supports nil keys.
    if (key == nil) {
        _NSXPCSerializationAddNull(&_serializer);
    } else {
        _NSXPCSerializationAddString(&_serializer, (CFStringRef) key, YES);
    }

    [self _encodeObject: object];
}

- (void) _encodeUnkeyedObject: (id) object {
    // Same as above.
    object = [self _replaceObject: object];
    [self _checkObject: object];

    [self _encodeObject: object];
}

- (void) _encodeInvocation: (NSInvocation *) invocation
                   isReply: (BOOL) isReply
                      into: (xpc_object_t) destinationDictionary
{
    NSUInteger savedGenericKey = _genericKey;
    _genericKey = 0;

    // Invocation are serialized as arrays of three items:
    // 1. The selector;
    // 2. The signature;
    // 3. A nested array of arguments.
    //
    // Unlike elsewhere, the target and the selector themselves
    // are not considered to be arguments.
    _NSXPCSerializationStartArrayWrite(&_serializer);

    // First item: the selector.
    if (!isReply) {
        const char *selectorName = sel_getName([invocation selector]);
        _NSXPCSerializationAddASCIIString(
            &_serializer,
            selectorName,
            strlen(selectorName)
        );
    } else {
        // Or, for reply, just a null.
        _NSXPCSerializationAddNull(&_serializer);
    }

    // Second item: the signature.
    NSMethodSignature *signature = [invocation methodSignature];
    _NSXPCSerializationAddString(
        &_serializer,
        (CFStringRef) [signature _typeString],
        YES
    );

    // Third item: the arguments.
    _NSXPCSerializationAddInvocationArgumentsArray(
        invocation,
        signature,
        /* ??? */ 0,
        &_serializer
    );

    _NSXPCSerializationEndArrayWrite(&_serializer);
    _genericKey = savedGenericKey;

    // Now, retrieve the encoded data.
    xpc_object_t data = _NSXPCSerializationCreateWriteData(&_serializer);
    // And save it to the destination dictionary.
    xpc_dictionary_set_value(destinationDictionary, "root", data);
    xpc_release(data);

    if (_oolObjects != NULL) {
        xpc_dictionary_set_value(destinationDictionary, "ool", _oolObjects);
    }
}

@end
