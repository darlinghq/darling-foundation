// Build: compile this file with the Foundation build flags and link CoreFoundation, libobjc, libxpc and libSystem.
// NSXPC data written by current macOS has the header "bplist17", where Darling writes "bplist16"; the object layout is the
// same. The deserializer must read both, and the writer must be able to write either. The bytes below are the data of
// a one-way invocation of -revokeAccessClaimForID: as observed on the wire from Apple's NSFileCoordinator (the claim ID
// replaced by zeros).
#define CF_PRIVATE
#define YES 1
#define NO 0
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <CoreFoundation/CoreFoundation.h>

#include "../src/NSXPCSerialization.c"

static const unsigned char apple_root[] = {
    0x62, 0x70, 0x6c, 0x69, 0x73, 0x74, 0x31, 0x37, 0xa0, 0x8c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x7f, 0x11, 0x18, 'r', 'e', 'v', 'o', 'k', 'e', 'A', 'c', 'c', 'e', 's', 's', 'C', 'l', 'a', 'i', 'm', 'F', 'o', 'r', 'I', 'D', ':',
    0x00, 0x7c, 'V', 'v', '2', '4', '@', '0', ':', '8', '@', '1', '6',
    0x00, 0xa0, 0x8c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x6f, 0x11, 0x24,
    '0', 0, '0', 0, '0', 0, '0', 0, '0', 0, '0', 0, '0', 0, '0', 0, '-', 0, '0', 0, '0', 0, '0', 0, '0', 0, '-', 0, '0', 0, '0', 0, '0', 0, '0', 0, '-', 0,
    '0', 0, '0', 0, '0', 0, '0', 0, '-', 0, '0', 0, '0', 0, '0', 0, '0', 0, '0', 0, '0', 0, '0', 0, '0', 0, '0', 0, '0', 0, '0', 0,
};

static void expect(int condition, const char* what)
{
    if (!condition) {
        printf("FAIL: %s\n", what);
        exit(1);
    }
}

static void checkRead(unsigned char* data, size_t length, unsigned char version, const char* name)
{
    struct NSXPCDeserializer deserializer;
    struct NSXPCObject root;
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_data(message, "root", data, length);
    expect(_NSXPCSerializationStartRead(message, &deserializer, &root), name);
    expect(deserializer.version == version, "the version digit is reported");
    __block int index = 0;
    __block int selector = 0;
    _NSXPCSerializationIterateArrayObject(&deserializer, &root, ^Boolean(struct NSXPCObject* item) {
        if (index == 0) {
            const char* text = _NSXPCSerializationASCIIStringForObject(&deserializer, item);
            selector = text != NULL && strcmp(text, "revokeAccessClaimForID:") == 0;
        }
        index++;
        return true;
    });
    expect(index == 3, "the invocation is an array of selector, signature and arguments");
    expect(selector, "the selector reads back");
    xpc_release(message);
}

int main(void)
{
    unsigned char data[sizeof apple_root];
    memcpy(data, apple_root, sizeof data);
    checkRead(data, sizeof data, '7', "Apple's bplist17 data is accepted");
    data[7] = '6';
    checkRead(data, sizeof data, '6', "the same data as bplist16 is accepted");

    // what is neither is refused
    struct NSXPCDeserializer deserializer;
    struct NSXPCObject root;
    for (unsigned char bad = '0'; bad <= '9'; bad++) {
        if (bad == '6' || bad == '7')
            continue;
        data[7] = bad;
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_data(message, "root", data, sizeof data);
        expect(!_NSXPCSerializationStartRead(message, &deserializer, &root), "an unknown version is refused");
        xpc_release(message);
    }

    // the writer writes bplist16 unless told otherwise
    struct NSXPCSerializer serializer;
    unsigned char buffer[64];
    _NSXPCSerializationStartWrite(&serializer, buffer, sizeof buffer);
    expect(memcmp(buffer, "bplist16", 8) == 0, "the default header is bplist16");
    _NSXPCSerializationSetWriteVersion(&serializer, '7');
    _NSXPCSerializationAddNull(&serializer);
    expect(memcmp(serializer.buffer, "bplist17", 8) == 0, "the header can be bplist17");
    expect(serializer.buffer[8] == NSXPC_NULL, "the object follows the header");

    printf("PASS: NSXPC data is read as bplist16 or bplist17 and written as the version asked for\n");
    return 0;
}
