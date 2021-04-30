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

#import "NSXPCDecoder.h"
#import "NSXPCSerialization.h"
#import "NSXPCSerializationObjC.h"
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSException.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#import <CoreFoundation/NSInvocationInternal.h>
#import <Foundation/NSKeyedArchiver.h>
#import <objc/runtime.h>

#import "NSXPCConnectionInternal.h"

@implementation NSXPCDecoder

- (void) _startReadingFromXPCObject: (xpc_object_t) object {
    BOOL success = _NSXPCSerializationStartRead(
        object,
        &_deserializer,
        &_rootObject
    );

    _oolObjects = xpc_dictionary_get_value(object, "ool");
    if (_oolObjects != NULL) {
        xpc_retain(_oolObjects);
        success &= xpc_get_type(_oolObjects) == XPC_TYPE_ARRAY;
    }

    if (!success) {
        [NSException raise: NSInvalidArgumentException
                    format: @"Malformed encoded data"];
    }

    // We start reading from the top-level collection.
    _collection = &_rootObject;
}

- (BOOL) allowsKeyedCoding {
    return YES;
}

static BOOL findObject(
    NSXPCDecoder *decoder,
    NSString *key,
    struct NSXPCObject *object
) {
    if (key) {
        return _NSXPCSerializationCreateObjectInDictionaryForKey(
            &decoder->_deserializer,
            decoder->_collection,
            (CFStringRef) key,
            object
        );
    } else {
        if (_NSXPCSerializationCreateObjectInDictionaryForGenericKey(&decoder->_deserializer, decoder->_collection, decoder->_genericKey, object)) {
            ++decoder->_genericKey;
            return YES;
        }
        return NO;
    }
}

- (BOOL) containsValueForKey: (NSString *) key {
    struct NSXPCObject object;
    return findObject(self, key, &object);
}

- (BOOL) decodeBoolForKey: (NSString *) key {
    struct NSXPCObject object;
    if (!findObject(self, key, &object)) {
        return NO;
    }
    return _NSXPCSerializationBoolForObject(&_deserializer, &object);
}

- (float) decodeFloatForKey: (NSString *) key {
    struct NSXPCObject object;
    if (!findObject(self, key, &object)) {
        return 0.0;
    }
    return _NSXPCSerializationFloatForObject(&_deserializer, &object);
}

- (double) decodeDoubleForKey: (NSString *) key {
    struct NSXPCObject object;
    if (!findObject(self, key, &object)) {
        return 0.0;
    }
    return _NSXPCSerializationDoubleForObject(&_deserializer, &object);
}

- (int) decodeIntForKey: (NSString *) key {
    struct NSXPCObject object;
    if (!findObject(self, key, &object)) {
        return 0;
    }
    return _NSXPCSerializationIntegerForObject(&_deserializer, &object);
}

- (int32_t) decodeInt32ForKey: (NSString *) key {
    struct NSXPCObject object;
    if (!findObject(self, key, &object)) {
        return 0;
    }
    return _NSXPCSerializationIntegerForObject(&_deserializer, &object);
}

- (int64_t) decodeInt64ForKey: (NSString *) key {
    struct NSXPCObject object;
    if (!findObject(self, key, &object)) {
        return 0;
    }
    return _NSXPCSerializationIntegerForObject(&_deserializer, &object);
}

- (NSInteger) decodeIntegerForKey: (NSString *) key {
    struct NSXPCObject object;
    if (!findObject(self, key, &object)) {
        return 0;
    }
    return _NSXPCSerializationIntegerForObject(&_deserializer, &object);
}

- (const unsigned char *) decodeBytesForKey: (NSString *) key
                             returnedLength: (NSUInteger *) length
{
    struct NSXPCObject object;
    if (!findObject(self, key, &object)) {
        return NULL;
    }
    NSData *data = (NSData *) _NSXPCSerializationDataForObject(
        &_deserializer,
        &object
    );
    if (length != NULL) {
        *length = [data length];
    }
    return [data bytes];
}

- (xpc_object_t)_xpcObjectForIndex: (NSUInteger)index
{
    if (!_oolObjects) {
        return NULL;
    }
    if (xpc_array_get_count(_oolObjects) <= index) {
        return NULL;
    }
    return xpc_array_get_value(_oolObjects, index);
}

- (id) _decodeObjectOfClasses: (NSSet *) classes
                     atObject: (const struct NSXPCObject *) object
{
    unsigned char marker = 0;
    id result = nil;

    if (!_NSXPCSerializationTypeOfObject(&_deserializer, object, &marker)) {
        return nil;
    }

    // these ones that have their own "if" conditions require the whole marker to be checked because they're differentiated based on length
    if (marker == NSXPC_FLOAT32 || marker == NSXPC_FLOAT64 || marker == NSXPC_UINT64) {
        result = _NSXPCSerializationNumberForObject(&_deserializer, object);
    } else {
        // for everything else, the type is the only thing that differentiates them
        switch (marker & 0xf0) {
            case NSXPC_TRUE: // fallthrough
            case NSXPC_FALSE: // fallthrough
            case NSXPC_INTEGER: {
                result = _NSXPCSerializationNumberForObject(&_deserializer, object);
            } break;

            case NSXPC_NULL: {
                result = nil;
            } break;

            case NSXPC_DATA: {
                result = _NSXPCSerializationDataForObject(&_deserializer, object);
            } break;

            case NSXPC_STRING: {
                result = _NSXPCSerializationStringForObject(&_deserializer, object);
            } break;

            case NSXPC_DICT: {
                struct NSXPCObject xpcOOLIndexObject;
                struct NSXPCObject classNameObject;
                NSUInteger savedGenericKey = _genericKey;
                struct NSXPCObject* savedCollection = _collection;

                _genericKey = 0;
                _collection = object;

                if (_NSXPCSerializationCreateObjectInDictionaryForASCIIKey(&_deserializer, object, "$xpc", &xpcOOLIndexObject)) {
                    // it's an OOL XPC object
                    NSUInteger index = _NSXPCSerializationIntegerForObject(&_deserializer, &xpcOOLIndexObject);
                    result = [self _xpcObjectForIndex: index];
                } else {
                    const char* className = NULL;
                    Class class = nil;

                    if (!_NSXPCSerializationCreateObjectInDictionaryForASCIIKey(&_deserializer, object, "$class", &classNameObject)) {
                        // no class name? invalid object.
                        [NSException raise: NSInvalidUnarchiveOperationException format: @"No class name found while deserializing Objective-C object"];
                    }

                    className = _NSXPCSerializationASCIIStringForObject(&_deserializer, &classNameObject);
                    if (!className) {
                        [NSException raise: NSInvalidUnarchiveOperationException format: @"Failed to read class name while deserializing Objective-C object"];
                    }

                    class = objc_lookUpClass(className);
                    if (!class) {
                        [NSException raise: NSInvalidUnarchiveOperationException format: @"Failed to load class while deserializing Objective-C object"];
                    }

                    result = [class allocWithZone: self.zone];
                    if (!result) {
                        [NSException raise: NSInvalidUnarchiveOperationException format: @"allocWithZone: for %s returned nil while deserializing Objective-C object", className];
                    }

                    result = [result initWithCoder: self];
                    if (!result) {
                        [NSException raise: NSInvalidUnarchiveOperationException format: @"initWithCoder: for %s returned nil while deserializing Objective-C object", className];
                    }

                    result = [result awakeAfterUsingCoder: self];
                    if (!result) {
                        [NSException raise: NSInvalidUnarchiveOperationException format: @"initWithCoder: for %s returned nil while deserializing Objective-C object", className];
                    }

                    result = [result autorelease];
                }

                _collection = savedCollection;
                _genericKey = savedGenericKey;
            } break;

            default: {
                os_log_fault(nsxpc_get_log(), "Unexpected marker %u while trying to deserialize Objective-C object", marker);
                result = nil;
            };
        }
    }

    return result;
}

- (void) __decodeXPCObject: (xpc_object_t) object
 allowingSimpleMessageSend: (BOOL) allowSimpleMessageSend
             outInvocation: (NSInvocation **) outInvocation
              outArguments: (NSArray **) arguments
      outArgumentsMaxCount: (NSUInteger) argumentsMaxCount
        outMethodSignature: (NSMethodSignature **) outSignature
               outSelector: (SEL *) outSelector
                   isReply: (BOOL) isReply
             replySelector: (SEL) replySelector
                 interface: (NSXPCInterface *) interface
{
    [self _startReadingFromXPCObject: object];

    __block NSUInteger index = 0;
    __block SEL selector = (SEL) NULL;
    __block NSMethodSignature *signature = nil;
    __block NSInvocation *invocation = nil;

    Boolean (^block)(struct NSXPCObject *item) =
        ^Boolean(struct NSXPCObject *item)
    {
        if (index == 0) {
            // First item: the selector.
            const char *selectorName = _NSXPCSerializationASCIIStringForObject(
                &_deserializer,
                item
            );
            if (selectorName != NULL) {
                selector = sel_registerName(selectorName);
            }
        } else if (index == 1) {
            // Second item: the signature.
            NSString *types = (NSString *) _NSXPCSerializationStringForObject(
                &_deserializer,
                item
            );
            if (types == nil) {
                [NSException raise: NSInvalidArgumentException
                            format: @"Missing method signature"];
            }
            signature = [NSMethodSignature signatureWithObjCTypes:
                [types UTF8String]
            ];
            invocation = [NSInvocation invocationWithMethodSignature:
                signature
            ];
            [invocation setSelector: isReply ? replySelector : selector];
        } else if (index == 2) {
            struct NSXPCObject* savedCollection = _collection;
            _collection = item;
            // Third item: the arguments.
            _NSXPCSerializationDecodeInvocationArgumentArray(
                invocation,
                signature,
                self,
                &_deserializer,
                item,
                /* TODO */ nil,
                isReply
            );
            _collection = savedCollection;
        } else {
            [NSException raise: NSInvalidArgumentException
                        format: @"Too many arguments"];
        }

        index++;
        return YES;
    };

    _NSXPCSerializationIterateArrayObject(
        &_deserializer,
        _collection,
        block
    );

    if (outInvocation) {
        *outInvocation = invocation;
    }
    if (outSignature) {
        *outSignature = signature;
    }
    if (!isReply && outSelector) {
        *outSelector = invocation.selector;
    }
}


- (void) _decodeMessageFromXPCObject: (xpc_object_t) object
           allowingSimpleMessageSend: (BOOL) allowSimpleMessageSend
                       outInvocation: (NSInvocation **) invocation
                        outArguments: (NSArray **) arguments
                outArgumentsMaxCount: (NSUInteger) argumentsMaxCount
                  outMethodSignature: (NSMethodSignature **) signature
                         outSelector: (SEL *) selector
                           interface: (NSXPCInterface *) interface
{
    [self __decodeXPCObject: object
  allowingSimpleMessageSend: allowSimpleMessageSend
              outInvocation: invocation
               outArguments: arguments
       outArgumentsMaxCount: argumentsMaxCount
         outMethodSignature: signature
                outSelector: selector
                    isReply: NO
              replySelector: (SEL) NULL
                  interface: interface];
}

- (NSInvocation*) _decodeReplyFromXPCObject: (xpc_object_t) object
                                forSelector: (SEL) selector
                                  interface: (NSXPCInterface*) interface
{
    NSInvocation* invocation = nil;
    [self __decodeXPCObject: object
  allowingSimpleMessageSend: NO
              outInvocation: &invocation
               outArguments: NULL
       outArgumentsMaxCount: 0
         outMethodSignature: NULL
                outSelector: NULL
                    isReply: YES
              replySelector: selector
                  interface: interface];
    return invocation;
}

- (xpc_object_t) decodeXPCObjectForKey: (NSString *)key
{
    struct NSXPCObject object;
    if (!findObject(self, key, &object)) {
        return NULL;
    }
    return [self _xpcObjectForIndex: _NSXPCSerializationIntegerForObject(&_deserializer, &object)];
}

- (xpc_object_t) decodeXPCObjectOfType: (xpc_type_t) type
                                forKey: (NSString *) key
{
    xpc_object_t object = [self decodeXPCObjectForKey: key];
    if (object && xpc_get_type(object) != type) {
        [NSException raise: NSInvalidUnarchiveOperationException format: @"Type of resulting xpc_object (%@) does not match expected type for key %@", object, key];
    }
    return object;
}

- (id)decodeObject
{
    return [self decodeObjectForKey: nil];
}

- (id)decodeObjectForKey: (NSString*)key
{
    return [self decodeObjectOfClasses: nil forKey: key];
}

- (id)decodeObjectOfClasses: (NSSet<Class>*)classes forKey: (NSString*)key
{
    struct NSXPCObject object;
    if (!findObject(self, key, &object)) {
        return nil;
    }
    return [self _decodeObjectOfClasses: classes atObject: &object];
}

- (void)decodeValueOfObjCType: (const char*)type at: (void*)address
{
    struct NSXPCObject* savedCollection = _collection;
    struct NSXPCObject object;
    __block BOOL found = NO;

    if (!findObject(self, nil, &object)) {
        return;
    }

    _collection = &object;

    _NSXPCSerializationIterateArrayObject(&_deserializer, &object, ^Boolean(struct NSXPCObject* item) {
        found = YES;
        _NSXPCSerializationDecodeTypedObjCValuesFromArray(self, &_deserializer, type, address, YES, &object, item, nil, nil);
        return false; // stop iterating on the first object
    });

    _collection = savedCollection;

    if (!found) {
        [NSException raise: NSInvalidUnarchiveOperationException format: @"Expected to find an array of Objective-C typed arguments, but there was nothing there."];
    }
}

- (NSArray*)_decodeArrayOfObjectsForKey: (NSString*)key
{
    struct NSXPCObject* savedCollection = _collection;
    struct NSXPCObject object;
    NSMutableArray* result = nil;

    if (!findObject(self, key, &object)) {
        return nil;
    }

    _collection = &object;

    result = [NSMutableArray array];

    _NSXPCSerializationIterateArrayObject(&_deserializer, &object, ^Boolean(struct NSXPCObject* item) {
        id object = [self _decodeObjectOfClasses: nil atObject: item];
        if (!object) {
            [NSException raise: NSInvalidUnarchiveOperationException format: @"Value in array for key %@ was nil", key];
        }
        [result addObject: object];
        return true;
    });

    _collection = savedCollection;

    return result;
}

@end
