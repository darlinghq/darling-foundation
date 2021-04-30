#include <xpc/xpc.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFData.h>
#include <CoreFoundation/CFNumber.h>

#define NSXPC_SERIALIZER_MAX_CONTAINER_DEPTH 1024

struct NSXPCSerializer {
    unsigned char *buffer;
    CFIndex bufferSize;
    unsigned char *ptr;
    Boolean bufferIsMalloced;

    CFIndex containerNestingLevel;
    CFIndex containerOffsets[NSXPC_SERIALIZER_MAX_CONTAINER_DEPTH];
};

struct NSXPCDeserializer {
    unsigned char *buffer;
    CFIndex bufferSize;
};

struct NSXPCObject {
    CFIndex offset;
    // Apple also have a type here, but we'll do without it.
};

enum {
    NSXPC_INTEGER = 0x10,

    NSXPC_FLOAT32 = 0x22,
    NSXPC_FLOAT64 = 0x23,

    NSXPC_DATA = 0x40,
    NSXPC_STRING = 0x60,
    NSXPC_ASCII = 0x70,

    NSXPC_ARRAY = 0xa0,
    NSXPC_TRUE = 0xb0,
    NSXPC_FALSE = 0xc0,
    NSXPC_NULL = 0xe0,
    NSXPC_DICT = 0xd0,

    NSXPC_UINT64 = 0xf8,
};

// Encoding.

CF_PRIVATE
void _NSXPCSerializationStartWrite(
    struct NSXPCSerializer *serializer,
    unsigned char *buffer,
    CFIndex bufferSize
);

CF_PRIVATE
void _NSXPCSerializationAddNull(struct NSXPCSerializer *serializer);

CF_PRIVATE
void _NSXPCSerializationAddBool(
    struct NSXPCSerializer *serializer,
    Boolean value
);

CF_PRIVATE
void _NSXPCSerializationAddFloat(
    struct NSXPCSerializer *serializer,
    float value
);

CF_PRIVATE
void _NSXPCSerializationAddDouble(
    struct NSXPCSerializer *serializer,
    double value
);

CF_PRIVATE
void _NSXPCSerializationAddUnsignedInteger(
    struct NSXPCSerializer *serializer,
    uint64_t value
);

CF_PRIVATE
void _NSXPCSerializationAddInteger(
    struct NSXPCSerializer *serializer,
    uint64_t value
);

CF_PRIVATE
void _NSXPCSerializationAddNumber(
    struct NSXPCSerializer *serializer,
    CFNumberRef number
);

CF_PRIVATE
void _NSXPCSerializationAddASCIIString(
    struct NSXPCSerializer *serializer,
    const char *string,
    CFIndex length
);

CF_PRIVATE
void _NSXPCSerializationAddString(
    struct NSXPCSerializer *serializer,
    CFStringRef string,
    Boolean attemptASCIIEncoding
);

CF_PRIVATE
void _NSXPCSerializationAddRawData(
    struct NSXPCSerializer *serializer,
    const void *data,
    CFIndex length
);

CF_PRIVATE
void _NSXPCSerializationAddData(
    struct NSXPCSerializer *serializer,
    CFDataRef data
);

CF_PRIVATE
void _NSXPCSerializationStartArrayWrite(
    struct NSXPCSerializer *serializer
);

CF_PRIVATE
void _NSXPCSerializationEndArrayWrite(
    struct NSXPCSerializer *serializer
);

CF_PRIVATE
void _NSXPCSerializationStartDictionaryWrite(
    struct NSXPCSerializer *serializer
);

CF_PRIVATE
void _NSXPCSerializationEndDictionaryWrite(
    struct NSXPCSerializer *serializer
);

CF_PRIVATE
xpc_object_t _NSXPCSerializationCreateWriteData(
    struct NSXPCSerializer *serializer
);

// Decoding.

CF_PRIVATE
Boolean _NSXPCSerializationStartRead(
    xpc_object_t dictionary,
    struct NSXPCDeserializer *deserializer,
    struct NSXPCObject *rootObject
);

// Apple do not have this one:
CF_PRIVATE
CFIndex _NSXPCSerializationEndOffsetForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
);

// Nor this one:
CF_PRIVATE
Boolean _NSXPCSerializationNullForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
);

CF_PRIVATE
Boolean _NSXPCSerializationBoolForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
);

CF_PRIVATE
float _NSXPCSerializationFloatForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
);

CF_PRIVATE
double _NSXPCSerializationDoubleForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
);

CF_PRIVATE
int64_t _NSXPCSerializationIntegerForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
);

CF_PRIVATE
CFNumberRef _NSXPCSerializationNumberForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
);

CF_PRIVATE
const char *_NSXPCSerializationASCIIStringForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
);

CF_PRIVATE
CFDataRef _NSXPCSerializationDataForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
);

CF_PRIVATE
CFStringRef _NSXPCSerializationStringForObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object
);

CF_PRIVATE
void _NSXPCSerializationIterateArrayObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    Boolean (^block)(struct NSXPCObject *item)
);

// Apple's version does not seem to have this one:
CF_PRIVATE
void _NSXPCSerializationIterateDictionaryObject(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    Boolean (^block)(
        const struct NSXPCObject *key,
        const struct NSXPCObject *value
    )
);

CF_PRIVATE
Boolean _NSXPCSerializationCreateObjectInDictionaryForKey(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    CFStringRef key,
    struct NSXPCObject *value
);

CF_PRIVATE
Boolean _NSXPCSerializationCreateObjectInDictionaryForASCIIKey(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    const char* key,
    struct NSXPCObject *value
);

CF_PRIVATE
Boolean _NSXPCSerializationCreateObjectInDictionaryForGenericKey(
    struct NSXPCDeserializer *deserializer,
    const struct NSXPCObject *object,
    size_t key,
    struct NSXPCObject *value
);

// Apple's version of this has a different signature because they store the type within the object structure
CF_PRIVATE
Boolean _NSXPCSerializationTypeOfObject(struct NSXPCDeserializer* deserializer, struct NSXPCObject* object, unsigned char* outType);
