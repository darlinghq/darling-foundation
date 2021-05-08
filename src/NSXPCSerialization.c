#include "NSXPCSerialization.h"
#include <assert.h>

/**
 * An overview of NSXPC's serialization format
 * -------------------------------------------
 *
 * NSXPC uses bplist16 for its serialization. This format is similar to bplist00, but differs primarily in that objects are serialized sequentially rather than using an offset table.
 * Messages consist of the bytes "bplist16" followed directly by the root object. The root object is simply an object like any other.
 *
 * > Note: when I say "object" here, I mean bplist objects, not Objective-C objects. Those are encoded using this format, and their encoding format is described in `NSXPCEncoder.h`.
 * >       Some Objective-C objects (like NSNumber, NSString, and NSData) are exceptions and are described later on in this file.
 *
 * The first byte of each object contains a marker in the upper 4 bits followed by a length indicator in the lower 4 bits.
 * The format of the length follows the format for bplist00: if the length is less than 15 (i.e. 0xf), it is encoded directly into the tag byte.
 * Otherwise, if it is 15 or greater, the lower 4 bits of the tag are set to 0x0f and the length is encoded after the tag byte as an integer, just like any other integer is encoded.
 * Data for the object, if any, immediately follows the tag byte (and extended length, if necessary).
 *
 * Integers have a marker of 0x1 with a variable length of 1, 2, 4, or 8 bytes. They are serialized in the host's endianness, which is little endian on all of Apple's platforms.
 *
 * Unsigned integers have a marker of 0xf with a fixed length of 8. They are serialized in the host's endianness, which is little endian on all of Apple's platforms.
 *
 * Floating point numbers have a marker of 0x2. If they have a length value of 2, they are 32-bit floats (i.e. the `float` type).
 * If they have a length value of 3, they are 64-bit floats (i.e. the `double` type). Both `float` and `double` are encoded in the host's native floating-point format,
 * which is IEEE 754 floating point on all of Apple's platforms.
 *
 * Generic data has a marker of 0x4 with a variable length specifying the length of all the data.
 *
 * Strings come in two variaties: UTF-16 strings and ASCII strings. UTF-16 strings have a marker of 0x6 with a variable length specifying the length of the string in bytes.
 * This length is always two times the number of UTF-16 codepoints in the string. ASCII strings have a marker f 0x7 with a variable length specifying the length of the string in bytes.
 *
 * Booleans consist solely of their markers: 0xb for `true` and 0xc for `false`. No length is required (since they carry no additional data).
 * Likewise, null consists solely of its marker: 0xe.
 *
 * Arrays and dictionaries are containers and share a common format. The tag byte contains only the marker (0xa for arrays, 0xd for dictionaries), no length.
 * The tag byte is immediately followed by a fixed width offset of 8 bytes, pointing to the last byte in the container, counting from the start of the entire message.
 * The only difference between arrays and dictionaries is that each entry in an array consists of a single object, while each entry in a dictionary consists of two objects (a key and a value).
 * There is no technical restriction on the kinds of objects allowed to be keys in a dictionary (even null is allowed), although NSXPC generally uses only UTF-16 strings, ASCII strings, or null (treated as a "generic" key).
 */

/**
 * A note on certain special Objective-C objects
 * ---------------------------------------------
 *
 * NSNumber, NSString, and NSData are considered special objects for the purpose of NSXPC serialization.
 *
 * NSNumbers are the most complex of the three. If they're booleans, they're encoded as such. If they're floats, they're encoded as such (either 32-bit or 64-bit, depending on the size).
 * If they're 64-bit unsigned integers, they're encoded as such. Anything else is just an integer and is encoded as such. "Encoded as such" here means in the respective bplist16 format.
 *
 * NSStrings are usually encoded as UTF-16 strings, but can optionally be encoded as ASCII strings if they contain no Unicode codepoints.
 * Note that when serializing NSStrings from user input/arguments, NSXPC does NOT enable the ASCII optimization; NSStrings being encoded from invocation are ALWAYS encoded as UTF-16 strings.
 *
 * NSData is simply encoded as a data object.
 */

enum {
    kCFNumberSInt128Type = 17
};

CF_EXPORT CFNumberType _CFNumberGetType2(CFNumberRef number);

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

    // unsigned 64-bit integers
    if (_CFNumberGetType2(number) == kCFNumberSInt128Type) {
        uint64_t value[2];
        CFNumberGetValue(number, kCFNumberSInt128Type, &value[0]);
        _NSXPCSerializationAddUnsignedInteger(serializer, value[0]);
        return;
    }

    // Integers.
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
