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

/**
 * About NSXPC's Objective-C object serialization
 * ----------------------------------------------
 *
 * With the exception of NSNumber, NSString, and NSData, all Objective-C objects encoded by NSXPC follow the same format and are encoded similarly to keyed archives.
 * Objects sent as proxies follow this same format as well. Only objects that conform to and support NSSecureCoding are allowed to be coded by NSXPC;
 * the only exceptions to this are XPC objects (they don't conform, but they are allowed).
 *
 * When the data is serialized into the final XPC message dictionary, "root" contains the bplist16 data with all the encoded objects and "ool" contains the array of out-of-line
 * XPC objects encoded along with the message (if any).
 *
 * All keys are encoded as flexible strings (either UTF-16 or ASCII, as permitted by the contents of the string).
 *
 * `encodeValueOfObjCType:at:` first writes null for the key (to indicate a generic key) and then creates an array in which the value is serialized.
 * The actual value serialization is performed by `_NSXPCSerializationAddTypedObjCValuesToArray`. If the value is an Objective-C object, that function calls back to the encoder
 * and tells it to encode the object as an unkeyed object (using `_encodeUnkeyedObject`).
 *
 * All keyed objects are encoded simply by encoding the key followed by the object as an unkeyed object.
 *
 * Unkeyed objects are encoded in one of three ways. If they're `nil`, they're encoded as null. If they're one of the three special Objective-C classes (NSNumber, NSString, or NSData),
 * they're encoded as the respective bplist16 objects. Otherwise, a dictionary is created for them. Then, its class is queried with `classForCoder` and the name of that class
 * is written as an ASCII string for the "$class" key. Next, if the object is an XPC object, it is added to the out-of-line XPC object array and its position in this array is encoded
 * as an integer for the "$xpc" key. Otherwise, if it's not an XPC object, `encodeWithCoder` is called on the object with the current NSXPCEncoder as the coder argument.
 *
 * When objects serialize themselves, they are allowed to use both keyed and unkeyed coding. When values are encoded without keys, they are assigned generic keys.
 * Generic keys are those for which the key value is null. They are identified by the their position in the dictionary relative to other generically keyed values.
 * Thus, for these kinds of values, the dictionary acts like an array.
 *
 * Invocations are serialized as an array with 3 items: a selector, a signature, and an array of arguments.
 * For reply invocations, the selector is null. Otherwise, it's encoded as an ASCII string.
 * The signature is encoded as a flexible string (either UTF-16 or ASCII, as permitted by the contents of the string).
 * Finally, the arguments are encoded as an array by `_NSXPCSerializationAddInvocationArgumentsArray`.
 * This function merely creates an array and calls `_NSXPCSerializationAddTypedObjCValuesToArray` on each argument.
 */

static dispatch_once_t _XPCObjectClass_once;
static Class _XPCObjectClass = nil;

@implementation NSXPCEncoder

- (instancetype) init {
    return [self initWithStackSpace: NULL size: 0];
}

- (instancetype) initWithStackSpace: (unsigned char *) buffer
                               size: (size_t) bufferSize
{
    dispatch_once(&_XPCObjectClass_once, ^{
        // fetch the base XPC object class.
        // any object will do; null works nicely
        xpc_object_t xpc_null = xpc_null_create();
        _XPCObjectClass = [xpc_null superclass];
        [xpc_null release];
    });
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
    if (_askForReplacement) {
        object = [object replacementObjectForCoder: self];
        // TODO: ask the connection/delegate (not sure which one) for a replacement as well;
        //       the objects replaced by the delegate (and their replacements) are cached
    }
    return object;
}

- (void) _checkObject: (id) object {
    // the object is allowed to be one of three things:
    //   * an invocation,
    //   * an XPC object, or
    //   * any other class that conforms to NSSecureCoding
    // if it doesn't satisfy any of those conditions, it's not allowed
    if (object && !([object isKindOfClass: [NSInvocation class]] || [object isKindOfClass: [_XPCObjectClass class]] || [object conformsToProtocol: @protocol(NSSecureCoding)])) {
        [NSException raise: NSInvalidArgumentException format: @"NSXPCCoder only accepts objects that conform to NSSecureCoding or are XPC objects"];
    }
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
    if ([object isKindOfClass: _XPCObjectClass]) {
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
    _askForReplacement = YES;
    _NSXPCSerializationAddInvocationArgumentsArray(
        invocation,
        signature,
        self,
        &_serializer,
        isReply
    );
    _askForReplacement = NO;

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

- (void)encodeXPCObject: (xpc_object_t) object forKey: (NSString *) key
{
    _NSXPCSerializationAddString(&_serializer, (CFStringRef) key, YES);
    _NSXPCSerializationAddInteger(&_serializer, [self _encodeOOLXPCObject: object]);
}

- (void)encodeObject: (id)object
{
    return [self encodeObject: object forKey: nil];
}

- (void)encodeValueOfObjCType: (const char*)type at: (const void*)address
{
    _NSXPCSerializationAddNull(&_serializer);
    _NSXPCSerializationStartArrayWrite(&_serializer);
    _NSXPCSerializationAddTypedObjCValuesToArray(self, &_serializer, type, address);
    _NSXPCSerializationEndArrayWrite(&_serializer);
}

- (void)encodeDataObject: (id)object
{
    return [self encodeObject: object];
}

- (void)_encodeArrayOfObjects: (NSArray*)array forKey: (NSString*)key
{
    _NSXPCSerializationAddString(&_serializer, (CFStringRef)key, YES);
    _NSXPCSerializationStartArrayWrite(&_serializer);
    for (id object in array) {
        [self _encodeUnkeyedObject: object];
    }
    _NSXPCSerializationEndArrayWrite(&_serializer);
}

@end
