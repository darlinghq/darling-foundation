#include "NSXPCSerialization.h"
#include <assert.h>

static CFIndex currentOffset(struct NSXPCSerializer *serializer) {
    return serializer->ptr - serializer->buffer;
}

static void ensureSpace(
    struct NSXPCSerializer *serializer,
    size_t additionalSize
) {
    size_t usedSize = currentOffset(serializer);
    size_t requiredSize = usedSize + additionalSize;
    if (requiredSize <= serializer->bufferSize) {
        return;
    }

    size_t newSize = serializer->bufferSize * 2;
    if (newSize < requiredSize) {
        newSize = requiredSize * 2;
    }

    if (serializer->bufferIsMalloced) {
        serializer->buffer = realloc(serializer->buffer, newSize);
        assert(serializer->buffer);
    } else {
        unsigned char *newBuffer = malloc(newSize);
        assert(newBuffer);
        if (usedSize > 0) {
            memcpy(newBuffer, serializer->buffer, usedSize);
        }
        serializer->buffer = newBuffer;
    }

    serializer->bufferSize = newSize;
    serializer->ptr = serializer->buffer + usedSize;
    serializer->bufferIsMalloced = true;
}

static const char header[] = "bplist16";
#define HEADER_LENGTH 8

#define MARKER(b) ((b) & 0xf0)
#define LENGTH(b) ((b) & 0x0f)

void _NSXPCSerializationStartWrite(
    struct NSXPCSerializer *serializer,
    unsigned char *buffer,
    CFIndex bufferSize
) {
    serializer->buffer = buffer;
    serializer->bufferSize = bufferSize;
    serializer->ptr = buffer;
    serializer->bufferIsMalloced = false;
    serializer->containerNestingLevel = 0;

    ensureSpace(serializer, HEADER_LENGTH);
    memcpy(serializer->ptr, header, HEADER_LENGTH);
    serializer->ptr += HEADER_LENGTH;
}

void _NSXPCSerializationAddNull(struct NSXPCSerializer *serializer) {
    ensureSpace(serializer, 1);
    *serializer->ptr++ = NSXPC_NULL;
}

void _NSXPCSerializationAddBool(
    struct NSXPCSerializer *serializer,
    Boolean value
) {
    ensureSpace(serializer, 1);
    *serializer->ptr++ = value ? NSXPC_TRUE : NSXPC_FALSE;
}

void _NSXPCSerializationAddFloat(
    struct NSXPCSerializer *serializer,
    float value
) {
    ensureSpace(serializer, 1 + sizeof(value));
    *serializer->ptr++ = NSXPC_FLOAT32;
    memcpy(serializer->ptr, &value, sizeof(value));
    serializer->ptr += sizeof(value);
}

void _NSXPCSerializationAddDouble(
    struct NSXPCSerializer *serializer,
    double value
) {
    ensureSpace(serializer, 1 + sizeof(value));
    *serializer->ptr++ = NSXPC_FLOAT64;
    memcpy(serializer->ptr, &value, sizeof(value));
    serializer->ptr += sizeof(value);
}

void _NSXPCSerializationAddUnsignedInteger(
    struct NSXPCSerializer *serializer,
    uint64_t value
) {
    ensureSpace(serializer, 1 + sizeof(value));
    *serializer->ptr++ = NSXPC_UINT64;
    memcpy(serializer->ptr, &value, sizeof(value));
    serializer->ptr += sizeof(value);
}

void _NSXPCSerializationAddInteger(
    struct NSXPCSerializer *serializer,
    uint64_t value
) {
    size_t length;
    if (value < (1ull << 8)) {
        length = 1;
    } else if (value < (1ull << 16)) {
        length = 2;
    } else if (value < (1ull << 32)) {
        length = 4;
    } else {
        length = 8;
    }

    ensureSpace(serializer, 1 + length);
    *serializer->ptr++ = NSXPC_INTEGER | (unsigned char) length;
    memcpy(serializer->ptr, &value, length);
    serializer->ptr += length;
}

void _NSXPCSerializationAddNumber(
    struct NSXPCSerializer *serializer,
    CFNumberRef number
) {
    // Booleans.
    if (number == (CFNumberRef) kCFBooleanTrue) {
        _NSXPCSerializationAddBool(serializer, YES);
        return;
    } else if (number == (CFNumberRef) kCFBooleanFalse) {
        _NSXPCSerializationAddBool(serializer, NO);
        return;
    }

    // Floats.
    if (CFNumberIsFloatType(number)) {
        if (CFNumberGetByteSize(number) <= sizeof(float)) {
            float value;
            CFNumberGetValue(number, kCFNumberFloat32Type, &value);
            _NSXPCSerializationAddFloat(serializer, value);
        } else {
            double value;
            CFNumberGetValue(number, kCFNumberFloat64Type, &value);
            _NSXPCSerializationAddDouble(serializer, value);
        }
        return;
    }

    // Integers.
    // TODO: This doesn't quite handle positive 64-bit integers
    // that don't fit into (signed) int64_t, even though CFNumber
    // can represent them internally with kCFNumberSInt128Type.
    int64_t value;
    CFNumberGetValue(number, kCFNumberSInt64Type, &value);
    _NSXPCSerializationAddInteger(serializer, (uint64_t) value);
}

static void encodeLength(
    struct NSXPCSerializer *serializer,
    CFIndex length,
    unsigned char marker,
    size_t reserveLength
) {
    ensureSpace(serializer, 1 + reserveLength);

    // The most significant 4 bits of a byte encode the marker,
    // the least significant bits encode either the length, if
    // it's less than 0x0f, or 0x0f, which means that the actual
    // length is encoded later as an integer.
    Boolean isShort = length < 0x0f;
    unsigned char encodedLength = isShort ? length : 0x0f;
    *serializer->ptr++ = marker | encodedLength;

    if (!isShort) {
        _NSXPCSerializationAddInteger(serializer, length);
        ensureSpace(serializer, reserveLength);
    }
}

void _NSXPCSerializationAddASCIIString(
    struct NSXPCSerializer *serializer,
    const char *string,
    CFIndex length
) {
    // Account for the null terminator.
    length++;

    encodeLength(serializer, length, NSXPC_ASCII, length);
    memcpy(serializer->ptr, string, length);
    serializer->ptr += length;
}

void _NSXPCSerializationAddString(
    struct NSXPCSerializer *serializer,
    CFStringRef string,
    Boolean attemptASCIIEncoding
) {
    CFIndex length = CFStringGetLength(string);

    if (attemptASCIIEncoding) {
        const char *ascii = CFStringGetCStringPtr(
            string,
            kCFStringEncodingASCII
        );
        if (ascii != NULL) {
            _NSXPCSerializationAddASCIIString(serializer, ascii, length);
            return;
        }
    }

    // Otherwise, use 2-byte encoding.
    encodeLength(serializer, length, NSXPC_STRING, 2 * length);
    CFStringGetCharacters(
        string,
        CFRangeMake(0, length),
        (UniChar *) serializer->ptr
    );
    serializer->ptr += 2 * length;
}

void _NSXPCSerializationAddRawData(
    struct NSXPCSerializer *serializer,
    const void *data,
    CFIndex length
) {
    encodeLength(serializer, length, NSXPC_DATA, length);
    memcpy(serializer->ptr, data, length);
    serializer->ptr += length;
}

void _NSXPCSerializationAddData(
    struct NSXPCSerializer *serializer,
    CFDataRef data
) {
    _NSXPCSerializationAddRawData(
        serializer,
        CFDataGetBytePtr(data),
        CFDataGetLength(data)
    );
}

static void startContainer(
    struct NSXPCSerializer *serializer,
    unsigned char marker
) {
    ensureSpace(serializer, 1 + sizeof(uint64_t));
    // TODO comment here
    *serializer->ptr++ = marker;

    CFIndex level = serializer->containerNestingLevel++;
    assert(level < NSXPC_SERIALIZER_MAX_CONTAINER_DEPTH);
    serializer->containerOffsets[level] = currentOffset(serializer);

    serializer->ptr += 8;
}

static void endContainer(struct NSXPCSerializer *serializer) {
    assert(serializer->containerNestingLevel > 0);
    CFIndex level = --serializer->containerNestingLevel;
    CFIndex startOffset = serializer->containerOffsets[level];

    CFIndex endOffset = currentOffset(serializer) - 1;
    memcpy(&serializer->buffer[startOffset], &endOffset, sizeof(endOffset));
}

void _NSXPCSerializationStartArrayWrite(
    struct NSXPCSerializer *serializer
) {
    startContainer(serializer, NSXPC_ARRAY);
}

void _NSXPCSerializationEndArrayWrite(
    struct NSXPCSerializer *serializer
) {
    endContainer(serializer);
}

void _NSXPCSerializationStartDictionaryWrite(
    struct NSXPCSerializer *serializer
) {
    startContainer(serializer, NSXPC_DICT);
}

void _NSXPCSerializationEndDictionaryWrite(
    struct NSXPCSerializer *serializer
) {
    endContainer(serializer);
}

xpc_object_t _NSXPCSerializationCreateWriteData(
    struct NSXPCSerializer *serializer
) {
    // xpc_data doesn't provide a constructor that does not
    // copy the data, like [NSData initWithBytesNoCopy: ...].
    // But we can still try and convince it not to copy
    // the data by going through the dispatch_data_t,
    // which does have such a constrctor. It will still copy
    // the data when we pass DISPATCH_DATA_DESTRUCTOR_DEFAULT,
    // though.
    dispatch_data_t dispatch_data = dispatch_data_create(
        serializer->buffer,
        currentOffset(serializer),
        NULL, /* not used with any of the two destrctors we pass */
        serializer->bufferIsMalloced
            ? DISPATCH_DATA_DESTRUCTOR_FREE
            : DISPATCH_DATA_DESTRUCTOR_DEFAULT
    );
    xpc_object_t xpc_data = xpc_data_create_with_dispatch_data(dispatch_data);
    dispatch_release(dispatch_data);

    // Clear out the serializer, just in case.
    memset(serializer, 0, sizeof(*serializer));

    return xpc_data;
}


static Boolean validateRead(
    struct NSXPCDeserializer *deserializer,
    CFIndex offset,
    CFIndex size
) {
    return HEADER_LENGTH <= offset
        && offset + size <= deserializer->bufferSize;
}

static Boolean validateAndRead(
    struct NSXPCDeserializer *deserializer,
    CFIndex offset,
    CFIndex size,
    void *dest
) {
    if (!validateRead(deserializer, offset, size)) {
        return false;
    }
    memcpy(dest, &deserializer->buffer[offset], size);
    return true;
}

Boolean _NSXPCSerializationStartRead(
    xpc_object_t dictionary,
    struct NSXPCDeserializer *deserializer,
    struct NSXPCObject *rootObject
) {
    size_t length;
    const unsigned char *data = xpc_dictionary_get_data(
        dictionary,
        "root",
        &length
    );
    if (data == NULL) {
        return false;
    }
    // Do not use validateRead(), since it forbids reading
    // the header.
    if (length < HEADER_LENGTH) {
        return false;
    }
    if (memcmp(data, header, HEADER_LENGTH) != 0) {
        return false;
    }

    deserializer->buffer = (unsigned char *) data;
    deserializer->bufferSize = length;

    rootObject->offset = HEADER_LENGTH;

    return true;
}

Boolean _NSXPCSerializationNullForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
) {
    unsigned char marker;
    if (!validateAndRead(deserializer, object->offset, 1, &marker)) {
        return false;
    }

    return marker == NSXPC_NULL;
}

Boolean _NSXPCSerializationBoolForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
) {
    unsigned char marker;
    if (!validateAndRead(deserializer, object->offset, 1, &marker)) {
        return false;
    }

    return marker == NSXPC_TRUE;
}

float _NSXPCSerializationFloatForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
) {
    unsigned char marker;
    if (!validateAndRead(deserializer, object->offset, 1, &marker)) {
        return 0.0;
    }
    if (marker != NSXPC_FLOAT32) {
        return 0.0;
    }

    CFIndex valueOffset = object->offset + 1;
    float value;
    if (!validateAndRead(deserializer, valueOffset, sizeof(value), &value)) {
        return 0.0;
    }
    return value;
}

double _NSXPCSerializationDoubleForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
) {
    unsigned char marker;
    if (!validateAndRead(deserializer, object->offset, 1, &marker)) {
        return 0.0;
    }
    if (marker != NSXPC_FLOAT64) {
        return 0.0;
    }

    CFIndex valueOffset = object->offset + 1;
    double value;
    if (!validateAndRead(deserializer, valueOffset, sizeof(value), &value)) {
        return 0.0;
    }
    return value;
}

int64_t _NSXPCSerializationIntegerForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
) {
    unsigned char b;
    if (!validateAndRead(deserializer, object->offset, 1, &b)) {
        return 0;
    }

    if (MARKER(b) != NSXPC_INTEGER) {
        return 0;
    }

    size_t length = LENGTH(b);
    int64_t value = 0;

    if (length > sizeof(value)) {
        return 0;
    }
    if (!validateAndRead(deserializer, object->offset + 1, length, &value)) {
        return 0;
    }
    return value;
}

CFNumberRef _NSXPCSerializationNumberForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
) {
    unsigned char b;
    if (!validateAndRead(deserializer, object->offset, 1, &b)) {
        return NULL;
    }

    CFNumberRef number;

    switch (b) {
    case NSXPC_TRUE:
        return (CFNumberRef) kCFBooleanTrue;

    case NSXPC_FALSE:
        return (CFNumberRef) kCFBooleanFalse;

    case NSXPC_FLOAT32:
        {
            float value = _NSXPCSerializationFloatForObject(
                deserializer,
                object
            );
            number = CFNumberCreate(NULL, kCFNumberFloat32Type, &value);
        }

    case NSXPC_FLOAT64:
        {
            double value = _NSXPCSerializationDoubleForObject(
                deserializer,
                object
            );
            number = CFNumberCreate(NULL, kCFNumberFloat64Type, &value);
        }

    default:  // NSXPC_INTEGER | length
        {
            int64_t value = _NSXPCSerializationIntegerForObject(
                deserializer,
                object
            );
            number = CFNumberCreate(NULL, kCFNumberSInt64Type, &value);
        }
    }

    return CFAutorelease(number);
}

static CFIndex decodeLength(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    unsigned char *marker,
    CFIndex *dataOffset
) {
    unsigned char b;
    if (!validateAndRead(deserializer, object->offset, 1, &b)) {
        return -1;
    }

    *marker = MARKER(b);
    CFIndex length = LENGTH(b);

    Boolean isShort = length < 0x0f;
    if (isShort) {
        *dataOffset = object->offset + 1;
    } else {
        // The code below mirrors _NSXPCSerializationIntegerForObject(),
        // but we inline it as we want to know the length of the length.
        if (!validateAndRead(deserializer, object->offset + 1, 1, &b)) {
            return -1;
        }
        if (MARKER(b) != NSXPC_INTEGER) {
            return -1;
        }
        size_t lengthLength = LENGTH(b);
        CFIndex lengthOffset = object->offset + 2;
        // Make sure to reinitialize length to zero, because the call
        // below doesn't fill all of its bytes.
        length = 0;
        if (!validateAndRead(
            deserializer,
            lengthOffset,
            lengthLength,
            &length
        )) {
            return -1;
        }
        *dataOffset = lengthOffset + lengthLength;
    }

    if (!validateRead(deserializer, *dataOffset, length)) {
        return -1;
    }
    return length;
}

const char *_NSXPCSerializationASCIIStringForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
) {
    unsigned char marker;
    CFIndex dataOffset;
    CFIndex length = decodeLength(deserializer, object, &marker, &dataOffset);

    if (length < 0 || marker != NSXPC_ASCII) {
        return NULL;
    }

    // Make sure there's indeed a null terminator at this position.
    // (Note that the null terminator itself is included in the
    // length, so we have to subtract one).
    if (deserializer->buffer[dataOffset + length - 1] != 0) {
        return NULL;
    }
    return (const char *) &deserializer->buffer[dataOffset];
}

CFDataRef _NSXPCSerializationDataForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
) {
    unsigned char marker;
    CFIndex dataOffset;
    CFIndex length = decodeLength(deserializer, object, &marker, &dataOffset);

    if (length < 0 || marker != NSXPC_DATA) {
        return NULL;
    }

    CFDataRef data = CFDataCreate(
        NULL,
        &deserializer->buffer[dataOffset],
        length
    );
    return CFAutorelease(data);
}

CFStringRef _NSXPCSerializationStringForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
) {
    unsigned char marker;
    CFIndex dataOffset;
    CFIndex length = decodeLength(deserializer, object, &marker, &dataOffset);

    if (length < 0) {
        return NULL;
    }

    CFStringRef string = NULL;

    switch (marker) {
    case NSXPC_ASCII:
        // Ensure the string is indeed null-terminated, as
        // CFStringCreateWithCString() expects it to be.
        if (deserializer->buffer[dataOffset + length - 1] != 0) {
            return NULL;
        }
        string = CFStringCreateWithCString(
            NULL,
            (const char *) &deserializer->buffer[dataOffset],
            kCFStringEncodingASCII
        );
        break;

    case NSXPC_STRING:
        if (!validateRead(deserializer, dataOffset, 2 * length)) {
            return NULL;
        }
        string = CFStringCreateWithCharacters(
            NULL,
            (const UniChar *) &deserializer->buffer[dataOffset],
            length
        );
        break;

    default:
        return NULL;
    }

    return CFAutorelease(string);
}

static CFIndex startContainerRead(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    struct NSXPCObject *firstItem,
    unsigned char expectedMarker
) {
    unsigned char actualMarker;
    if (!validateAndRead(deserializer, object->offset, 1, &actualMarker)) {
        return -1;
    }
    if (actualMarker != expectedMarker) {
        return -1;
    }

    uint64_t endOffset;
    if (!validateAndRead(
        deserializer,
        object->offset + 1,
        sizeof(endOffset),
        &endOffset
    )) {
        return -1;
    }

    firstItem->offset = object->offset + 1 + sizeof(endOffset);

    return endOffset;
}

CFIndex _NSXPCSerializationEndOffsetForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
) {
    unsigned char b;
    if (!validateAndRead(deserializer, object->offset, 1, &b)) {
        return -1;
    }

    switch (b) {
    case NSXPC_FLOAT32:
        return object->offset + sizeof(float);
    case NSXPC_FLOAT64:
        return object->offset + sizeof(double);
    case NSXPC_UINT64:
        return object->offset + sizeof(uint64_t);

    case NSXPC_TRUE:
    case NSXPC_FALSE:
    case NSXPC_NULL:
        return object->offset;

    case NSXPC_ARRAY:
    case NSXPC_DICT:
        {
            CFIndex endOffsetOffset = object->offset + 1;
            uint64_t endOffset = 0;
            if (!validateAndRead(
                deserializer,
                endOffsetOffset,
                sizeof(endOffset),
                &endOffset
            )) {
                return -1;
            }
            return endOffset;
        }
    }

    unsigned char marker;
    CFIndex dataOffset;
    CFIndex length = decodeLength(deserializer, object, &marker, &dataOffset);
    if (length < 0) {
        return -1;
    }
    if (marker == NSXPC_STRING) {
        // Strings require twice as much space.
        return dataOffset + 2 * length - 1;
    } else {
        return dataOffset + length - 1;
    }
}

void _NSXPCSerializationIterateArrayObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    Boolean (^block)(struct NSXPCObject *item)
) {
    struct NSXPCObject item;
    CFIndex endOffset = startContainerRead(
        deserializer,
        object,
        &item,
        NSXPC_ARRAY
    );
    if (endOffset < 0) {
        return;
    }

    while (item.offset <= endOffset) {
        if (!block(&item)) {
            break;
        }
        item.offset = _NSXPCSerializationEndOffsetForObject(
            deserializer,
            &item
        ) + 1;
    }
}

void _NSXPCSerializationIterateDictionaryObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    Boolean (^block)(
        const struct NSXPCObject *key,
        const struct NSXPCObject *value
    )
) {
    struct NSXPCObject key, value;
    CFIndex endOffset = startContainerRead(
        deserializer,
        object,
        &key,
        NSXPC_DICT
    );
    if (endOffset < 0) {
        return;
    }

    while (key.offset <= endOffset) {
        value.offset = _NSXPCSerializationEndOffsetForObject(
            deserializer,
            &key
        ) + 1;
        if (!block(&key, &value)) {
            break;
        }
        key.offset = _NSXPCSerializationEndOffsetForObject(
            deserializer,
            &value
        ) + 1;
    }
}

Boolean _NSXPCSerializationCreateObjectInDictionaryForKey(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    CFStringRef key,
    struct NSXPCObject *value
) {
    __block Boolean found = false;

    _NSXPCSerializationIterateDictionaryObject(deserializer, object, ^Boolean(
        const struct NSXPCObject *aKey,
        const struct NSXPCObject *aValue
    ) {
        CFStringRef thisKey = _NSXPCSerializationStringForObject(
            deserializer,
            aKey
        );
        if (thisKey != NULL && CFEqual(thisKey, key)) {
            *value = *aValue;
            found = true;
            // Found, stop iteration.
            return false;
        } else {
            // Not found, continue iteration.
            return true;
        }
    });

    return found;
}

// essentially the same as above, but with an ASCII string
Boolean _NSXPCSerializationCreateObjectInDictionaryForASCIIKey(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    const char* key,
    struct NSXPCObject *value
) {
    __block Boolean found = false;

    _NSXPCSerializationIterateDictionaryObject(deserializer, object, ^Boolean(
        const struct NSXPCObject *aKey,
        const struct NSXPCObject *aValue
    ) {
        const char* thisKey = _NSXPCSerializationASCIIStringForObject(
            deserializer,
            aKey
        );
        if (thisKey != NULL && strcmp(thisKey, key) == 0) {
            *value = *aValue;
            found = true;
            // Found, stop iteration.
            return false;
        } else {
            // Not found, continue iteration.
            return true;
        }
    });

    return found;
}

Boolean _NSXPCSerializationCreateObjectInDictionaryForGenericKey(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    size_t key,
    struct NSXPCObject *value
) {
    __block Boolean found = false;
    __block size_t currentIndex = 0;

    _NSXPCSerializationIterateDictionaryObject(deserializer, object, ^Boolean(
        const struct NSXPCObject *aKey,
        const struct NSXPCObject *aValue
    ) {
        if (_NSXPCSerializationNullForObject(deserializer, aValue)) {
            if (currentIndex == key) {
                *value = *aValue;
                found = true;
                // Found, stop iteration.
                return false;
            } else {
                ++currentIndex;
            }
        }
        return true;
    });

    return found;
}

Boolean _NSXPCSerializationTypeOfObject(struct NSXPCDeserializer* deserializer, struct NSXPCObject* object, unsigned char* outType) {
    return validateAndRead(deserializer, object->offset, 1, outType);
};
