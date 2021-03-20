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
#import <objc/runtime.h>


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
    _collection = _rootObject;
}

- (BOOL) allowsKeyedCoding {
    return YES;
}

static BOOL findObject(
    NSXPCDecoder *decoder,
    NSString *key,
    struct NSXPCObject *object
) {
    return _NSXPCSerializationCreateObjectInDictionaryForKey(
        &decoder->_deserializer,
        &decoder->_collection,
        (CFStringRef) key,
        object
    );
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

- (id) _decodeObjectOfClasses: (NSSet *) classes
                     atObject: (const struct NSXPCObject *) object
{
    // TODO
    return nil;
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
            // Third item: the arguments.
            _NSXPCSerializationDecodeInvocationArgumentArray(
                invocation,
                signature,
                self,
                &_deserializer,
                item,
                /* TODO */ nil
            );
        } else {
            [NSException raise: NSInvalidArgumentException
                        format: @"Too many arguments"];
        }

        index++;
        return YES;
    };

    _NSXPCSerializationIterateArrayObject(
        &_deserializer,
        &_collection,
        block
    );

    *outInvocation = invocation;
    *outSignature = signature;
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

@end
