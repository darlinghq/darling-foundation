#import "NSXPCSerializationObjC.h"
#import "NSXPCEncoder.h"
#import "NSXPCDecoder.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSException.h>
#import <Foundation/NSMethodSignature.h>
#import <CoreFoundation/NSObjCRuntimeInternal.h>
#import <CoreFoundation/NSInvocationInternal.h>

void _NSXPCSerializationAddTypedObjCValuesToArray(
    NSXPCEncoder *encoder,
    struct NSXPCSerializer *serializer,
    const char *type,
    const void *addr
) {
    type = stripQualifiersAndComments(type);

    switch (type[0]) {
    case _C_ID:
        [encoder _encodeUnkeyedObject: *(id *) addr];
        break;

    case _C_CLASS:
        {
            Class class = *(Class *) addr;
            const char *className = class_getName(class);
            _NSXPCSerializationAddASCIIString(
                serializer,
                className,
                strlen(className)
            );
            break;
        }

    case _C_SEL:
        {
            SEL selector = *(SEL *) addr;
            const char *selectorName = sel_getName(selector);
            _NSXPCSerializationAddASCIIString(
                serializer,
                selectorName,
                strlen(selectorName)
            );
            break;
        }

    case _C_CHARPTR:
        {
            const char *str = *(const char **) addr;
            // Interestingly, we don't actually use
            // _NSXPCSerializationAddASCIIString()
            // for strings, instead we add them as
            // binary data.
            _NSXPCSerializationAddBool(serializer, str == NULL);
            _NSXPCSerializationAddRawData(serializer, str, strlen(str) + 1);
            break;
        }

    case _C_BOOL:
        _NSXPCSerializationAddBool(serializer, *(_Bool *) addr);
        break;

    case _C_FLT:
        _NSXPCSerializationAddFloat(serializer, *(float *) addr);
        break;

    case _C_DBL:
        _NSXPCSerializationAddBool(serializer, *(double *) addr);
        break;

#define HANDLE_INTEGER(_c_type, type) \
    case _c_type: \
        { \
            type value = *(type *) addr; \
            _NSXPCSerializationAddInteger(serializer, value); \
            break; \
        }

    HANDLE_INTEGER(_C_CHR, char);
    HANDLE_INTEGER(_C_UCHR, unsigned char);
    HANDLE_INTEGER(_C_SHT, short);
    HANDLE_INTEGER(_C_USHT, unsigned short);
    HANDLE_INTEGER(_C_INT, int);
    HANDLE_INTEGER(_C_UINT, unsigned int);
    HANDLE_INTEGER(_C_LNG, long);
    HANDLE_INTEGER(_C_ULNG, unsigned long);
    HANDLE_INTEGER(_C_LNG_LNG, long long);
    HANDLE_INTEGER(_C_ULNG_LNG, unsigned long long);

#undef HANDLE_INTEGER

    case _C_PTR:
        {
            void *ptr = *(void **) addr;
            // We simply record whether the pointer was NULL or not
            // (no serializing the pointee). But even that we do in
            // a weird way: instead of just storing a boolean, we
            // store either NULL or 0. Go figure.
            if (ptr == NULL) {
                _NSXPCSerializationAddNull(serializer);
            } else {
                _NSXPCSerializationAddInteger(serializer, 0);
            }
            break;
        }

    case _C_ARY_B:
        {
            const char *itemType;
            NSUInteger count = strtol(type + 1, (char **) &itemType, 10);
            NSUInteger itemSize;
            NSGetSizeAndAlignment(itemType, &itemSize, NULL);

            uintptr_t item = (uintptr_t) addr;
            for (NSUInteger i = 0; i < count; i++) {
                _NSXPCSerializationAddTypedObjCValuesToArray(
                    encoder,
                    serializer,
                    itemType,
                    (void *) item
                );
                item += itemSize;
            }

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
                nextItemType = NSGetSizeAndAlignment(
                    itemType,
                    &size,
                    &alignment
                );
                item = (item + alignment - 1) / alignment * alignment;
                _NSXPCSerializationAddTypedObjCValuesToArray(
                    encoder,
                    serializer,
                    itemType,
                    (void *) item
                );
                item += size;
            }
            break;
        }

    case _C_VOID:
        [NSException raise: NSGenericException
                    format: @"unencodable type: %s", type];
        break;

    case _C_UNDEF:
        _NSXPCSerializationAddNull(serializer);
        break;

    default:
        NSLog(@"Unimplemented type: %s", type);
        break;
    }
}

void _NSXPCSerializationDecodeTypedObjCValuesFromArray(
    NSXPCDecoder *decoder,
    struct NSXPCDeserializer *deserializer,
    const char *type,
    void *addr,
    BOOL unknown1,
    const struct NSXPCObject *containerObject,
    struct NSXPCObject *object,
    NSInvocation *invocation,
    NSSet *classes
) {
    type = stripQualifiersAndComments(type);

    switch (type[0]) {
    case _C_ID:
        {
            id obj = [decoder _decodeObjectOfClasses: classes
                                            atObject: object];
            *(id *) addr = obj;
            if (invocation) {
                [invocation _addAttachedObject: obj];
            } else {
                [obj retain];
            }
            break;
        }

    case _C_CLASS:
        {
            const char *className = _NSXPCSerializationASCIIStringForObject(
                deserializer,
                object
            );
            Class class = Nil;
            if (className != NULL) {
                class = objc_getClass(className);
            }
            *(Class *) addr = class;
            break;
        }

    case _C_SEL:
        {
            const char *selectorName = _NSXPCSerializationASCIIStringForObject(
                deserializer,
                object
            );
            SEL selector = (SEL) NULL;
            if (selectorName != NULL) {
                selector = sel_registerName(selectorName);
            }
            *(SEL *) addr = selector;
            break;
        }

    case _C_CHARPTR:
        {
            BOOL isNull = _NSXPCSerializationBoolForObject(
                 deserializer,
                 object
            );
            const char *str = NULL;
            if (!isNull) {
                object->offset = _NSXPCSerializationEndOffsetForObject(
                    deserializer,
                    object
                ) + 1;
                NSData *data = (NSData *) _NSXPCSerializationDataForObject(
                    deserializer,
                    object
                );
                // FIXME: Might need to attach this too.
                str = [data bytes];
            }
            *(const char **) addr = str;
            break;
        }

    case _C_BOOL:
        *(_Bool *) addr = _NSXPCSerializationBoolForObject(
            deserializer,
            object
        );
        break;

    case _C_FLT:
        *(float *) addr = _NSXPCSerializationFloatForObject(
            deserializer,
            object
        );
        break;

    case _C_DBL:
        *(double *) addr = _NSXPCSerializationDoubleForObject(
            deserializer,
            object
        );
        break;

#define HANDLE_INTEGER(_c_type, type) \
    case _c_type: \
        *(type *) addr = _NSXPCSerializationIntegerForObject( \
            deserializer, \
            object \
        ); \
        break;

    HANDLE_INTEGER(_C_CHR, char);
    HANDLE_INTEGER(_C_UCHR, unsigned char);
    HANDLE_INTEGER(_C_SHT, short);
    HANDLE_INTEGER(_C_USHT, unsigned short);
    HANDLE_INTEGER(_C_INT, int);
    HANDLE_INTEGER(_C_UINT, unsigned int);
    HANDLE_INTEGER(_C_LNG, long);
    HANDLE_INTEGER(_C_ULNG, unsigned long);
    HANDLE_INTEGER(_C_LNG_LNG, long long);
    HANDLE_INTEGER(_C_ULNG_LNG, unsigned long long);

#undef HANDLE_INTEGER

    case _C_PTR:
        {
            BOOL isNull = _NSXPCSerializationNullForObject(
                deserializer,
                object
            );
            if (isNull) {
                *(void **) addr = NULL;
            } else {
                // We haven't saved any information about the
                // pointee, so just fill it with a bunch of zero
                // bytes and hope for the better.
                NSUInteger pointeeSize;
                NSGetSizeAndAlignment(type + 1, &pointeeSize, NULL);
                NSMutableData *data =
                    [NSMutableData dataWithLength: pointeeSize];
                // FIXME: attach
                *(void **) addr = [data mutableBytes];
            }
            break;
        }

    case _C_ARY_B:
        {
            const char *itemType;
            NSUInteger count = strtol(type + 1, (char **) &itemType, 10);
            NSUInteger itemSize;
            NSGetSizeAndAlignment(itemType, &itemSize, NULL);

            uintptr_t item = (uintptr_t) addr;
            for (NSUInteger i = 0; i < count; i++) {
                _NSXPCSerializationDecodeTypedObjCValuesFromArray(
                    decoder,
                    deserializer,
                    itemType,
                    (void *) item,
                    unknown1,
                    containerObject,
                    object,
                    invocation,
                    classes
                );
                item += itemSize;
                // We want to leave object pointing to the start offset
                // of the last value we consume. Thus, we advance it to
                // point immediately after the consumed item, except when
                // processing the very last item.
                if (i < count - 1) {
                    object->offset = _NSXPCSerializationEndOffsetForObject(
                        deserializer,
                        object
                    ) + 1;
                }
            }

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
                nextItemType = NSGetSizeAndAlignment(
                    itemType,
                    &size,
                    &alignment
                );
                item = (item + alignment - 1) / alignment * alignment;
                _NSXPCSerializationDecodeTypedObjCValuesFromArray(
                    decoder,
                    deserializer,
                    itemType,
                    (void *) item,
                    NO,
                    containerObject,
                    object,
                    invocation,
                    classes
                );
                item += size;
                // Same as above.
                if (nextItemType[0] != _C_STRUCT_E) {
                    object->offset = _NSXPCSerializationEndOffsetForObject(
                        deserializer,
                        object
                    ) + 1;
                }
            }
            break;
        }

    case _C_VOID:
        [NSException raise: NSGenericException
                    format: @"undecodable type: %s", type];
        break;

    case _C_UNDEF:
        break;

    default:
        NSLog(@"Unimplemented type: %s", type);
        break;
    }
}

void _NSXPCSerializationAddInvocationArgumentsArray(
    NSInvocation *invocation,
    NSMethodSignature *signature,
    NSXPCEncoder *encoder,
    struct NSXPCSerializer *serializer,
    bool isReply
) {
    _NSXPCSerializationStartArrayWrite(serializer);

    for (CFIndex index = isReply ? 1 : 2; index < [signature numberOfArguments]; index++) {
        NSMethodType *arg = [signature _argInfo: index + 1];
        _NSXPCSerializationAddTypedObjCValuesToArray(
            encoder,
            serializer,
            arg->type,
             [invocation _idxToArg: index + 1]
        );
    }

    _NSXPCSerializationEndArrayWrite(serializer);
}

void _NSXPCSerializationDecodeInvocationArgumentArray(
    NSInvocation *invocation,
    NSMethodSignature *signature,
    NSXPCDecoder *decoder,
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    NSArray<NSSet *> *classesForArguments,
    bool isReply
) {
    NSUInteger numberOfArguments = [signature numberOfArguments];
    __block CFIndex index = isReply ? 1 : 2;

    _NSXPCSerializationIterateArrayObject(
        deserializer,
        object,
        ^Boolean(struct NSXPCObject *item) {
            if (index >= numberOfArguments) {
                [NSException raise: NSInvalidArgumentException
                            format: @"Too many arguments: "
                                     "expected %lu",
                                     (unsigned long) numberOfArguments];
            }
            NSMethodType *arg = [signature _argInfo: index + 1];
            NSSet *classes = nil;
            if (index - (isReply ? 1 : 2) < [classesForArguments count]) {
                classes = classesForArguments[index - (isReply ? 1 : 2)];
            }
            _NSXPCSerializationDecodeTypedObjCValuesFromArray(
                decoder,
                deserializer,
                arg->type,
                [invocation _idxToArg: index + 1],
                NO,
                object,
                item,
                invocation,
                classes
            );
            index++;
            return YES;
        }
    );
    if (index < numberOfArguments) {
        [NSException raise: NSInvalidArgumentException
                    format: @"Not enough arguments"];
    }
}
