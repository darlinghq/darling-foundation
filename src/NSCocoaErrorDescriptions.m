/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// Localized description, failure reason and recovery suggestion of the NSCocoaErrorDomain codes.
//
// An NSError (or CFError) that does not carry NSLocalizedDescriptionKey, NSLocalizedFailureReasonErrorKey or
// NSLocalizedRecoverySuggestionErrorKey asks the callback registered for its domain (CFErrorSetCallBackForDomain).
// Foundation registers one for NSCocoaErrorDomain. It answers for the codes of the file, validation, formatting,
// coding, XPC, handoff and ubiquity ranges of NSCocoaErrorDomain (FoundationErrors.h); a code that is not in the
// table gets no answer, and the caller falls back to its generic "operation couldn't be completed" text.
//
// The English strings are the ones observed from the original through the public API, for NSFilePathErrorKey and
// NSURLErrorKey (the file name, the folder or volume it is in, the URL scheme) and NSStringEncodingErrorKey (the
// name of the text encoding); see mac-probes/cocoa-error-descriptions in the research notes. The table below
// was produced from those observations, one row per code. Text that names the file, folder, volume, URL scheme or
// encoding holds {NAME}, {FOLDER}, {VOLUME}, {SCHEME} and {ENC} placeholders.
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFError_Private.h>
#include <stdlib.h>

typedef struct {
    NSInteger code;
    const char *desc, *reason, *suggestion;          // no information about the file
    const char *descName, *reasonName;               // with the name of the file
    const char *descFolder, *reasonFolder;           // with its name and the folder it is in
    const char *descVolume, *reasonVolume;           // with its name and the volume of an existing folder
    const char *descScheme, *reasonScheme;           // with its name and the URL scheme
    const char *descEncoding, *reasonEncoding;       // with a text encoding
} CocoaErrorEntry;

static const CocoaErrorEntry cocoaErrorTable[] = {
    { 4,
      "The file doesn\u2019t exist.", "The file doesn\u2019t exist.",
      NULL,
      "The file {NAME} doesn\u2019t exist.", "The file doesn\u2019t exist.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 255,
      "The file couldn\u2019t be locked.", "The file couldn\u2019t be locked.",
      "The file might already be locked, or you may not have permission to lock it.",
      "The file {NAME} couldn\u2019t be locked.", "The file couldn\u2019t be locked.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 256,
      "The file couldn\u2019t be opened.", NULL,
      NULL,
      "The file {NAME} couldn\u2019t be opened.", NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 257,
      "The file couldn\u2019t be opened because you don\u2019t have permission to view it.", "You don\u2019t have permission.",
      "To view or change permissions, select the item in the Finder and choose File > Get Info.",
      "The file {NAME} couldn\u2019t be opened because you don\u2019t have permission to view it.", "You don\u2019t have permission.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 258,
      "The file name is invalid.", "The file name is invalid.",
      NULL,
      "The item couldn\u2019t be opened because the file name {NAME} is invalid.", "The file name is invalid.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 259,
      "The file couldn\u2019t be opened because it isn\u2019t in the correct format.", "The file isn\u2019t in the correct format.",
      "The file might be corrupted, truncated, or in an unexpected format.",
      "The file {NAME} couldn\u2019t be opened because it isn\u2019t in the correct format.", "The file isn\u2019t in the correct format.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 260,
      "The file couldn\u2019t be opened because it doesn\u2019t exist.", "The file doesn\u2019t exist.",
      NULL,
      "The file {NAME} couldn\u2019t be opened because there is no such file.", "The file doesn\u2019t exist.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 261,
      "The file couldn\u2019t be opened using the specified text encoding.", "The specified text encoding isn\u2019t applicable.",
      "The file may have been saved using a different text encoding, or it may not be a text file.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      "The file couldn\u2019t be opened using text encoding {ENC}.", "Text encoding {ENC} isn\u2019t applicable." },
    { 262,
      "The file couldn\u2019t be opened because the specified URL type isn\u2019t supported.", "The specified URL type isn\u2019t supported.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      "The file {NAME} couldn\u2019t be opened because URL type {SCHEME} isn\u2019t supported.", "The specified URL type isn\u2019t supported.",
      NULL, NULL },
    { 263,
      "The item couldn\u2019t be opened because it is too large.", "The item is too large.",
      NULL,
      "The item {NAME} couldn\u2019t be opened because it is too large.", "The item is too large.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 264,
      "The file couldn\u2019t be opened because the text encoding of the contents couldn\u2019t be determined.", "The text encoding of the contents couldn\u2019t be determined.",
      "You may be able to open the file by specifying a text encoding.",
      "The file {NAME} couldn\u2019t be opened because the text encoding of its contents can\u2019t be determined.", "The text encoding of the contents couldn\u2019t be determined.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 512,
      "The file couldn\u2019t be saved.", NULL,
      NULL,
      "The file {NAME} couldn\u2019t be saved.", NULL,
      "The file {NAME} couldn\u2019t be saved in the folder {FOLDER}.", NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 513,
      "The file couldn\u2019t be saved because you don\u2019t have permission.", "You don\u2019t have permission.",
      "To view or change permissions, select the item in the Finder and choose File > Get Info.",
      "You don\u2019t have permission to save the file {NAME}.", "You don\u2019t have permission.",
      "You don\u2019t have permission to save the file {NAME} in the folder {FOLDER}.", "You don\u2019t have permission.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 514,
      "The item couldn\u2019t be saved because the file name is invalid.", "The file name is invalid.",
      NULL,
      "The item couldn\u2019t be saved because the file name {NAME} is invalid.", "The file name is invalid.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 516,
      "The file couldn\u2019t be saved because a file with the same name already exists.", "A file with the same name already exists.",
      "To save the file, either provide a different name, or move aside or delete the existing file, and try again.",
      "The file {NAME} couldn\u2019t be saved because a file with the same name already exists.", "A file with the name {NAME} already exists.",
      "The file {NAME} couldn\u2019t be saved in the folder {FOLDER} because a file with the same name already exists.", "A file with the name {NAME} already exists.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 517,
      "The file couldn\u2019t be saved using the specified text encoding.", "The specified text encoding isn\u2019t applicable.",
      "If possible, select a different text encoding.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      "The file couldn\u2019t be saved using text encoding {ENC}.", "Text encoding {ENC} isn\u2019t applicable." },
    { 518,
      "The file couldn\u2019t be saved because the specified URL type isn\u2019t supported.", "The specified URL type isn\u2019t supported.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      "The file {NAME} couldn\u2019t be saved because URL type {SCHEME} isn\u2019t supported.", "The specified URL type isn\u2019t supported.",
      NULL, NULL },
    { 640,
      "The file couldn\u2019t be saved because there isn\u2019t enough space.", "There isn\u2019t enough space.",
      "Remove some files from the volume, and then try again.",
      "You can\u2019t save the file {NAME} because there isn\u2019t enough space.", "There isn\u2019t enough space.",
      NULL, NULL,
      "You can\u2019t save the file {NAME} because the volume {VOLUME} is out of space.", "The volume {VOLUME} is out of space.",
      NULL, NULL,
      NULL, NULL },
    { 642,
      "The file couldn\u2019t be saved because the volume is read only.", "The volume is read only.",
      "Try saving the file to another volume.",
      "You can\u2019t save the file {NAME} because the volume is read only.", "The volume is read only.",
      NULL, NULL,
      "You can\u2019t save the file {NAME} because the volume {VOLUME} is read only.", "The volume {VOLUME} is read only.",
      NULL, NULL,
      NULL, NULL },
    { 768,
      "The disk could not be ejected because it is in use.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      "The disk {VOLUME} could not be ejected because it is in use.", NULL,
      NULL, NULL,
      NULL, NULL },
    { 769,
      "The disk could not be ejected.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      "The disk {VOLUME} could not be ejected.", NULL,
      NULL, NULL,
      NULL, NULL },
    { 1024,
      "The value is invalid.", "The value is invalid.",
      "Please provide a valid value.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1550,
      "%{PROPERTY}@ is not valid.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1551,
      "One or more constraints were violated.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1560,
      "Multiple validation errors occurred.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1570,
      "%{PROPERTY}@ is a required value.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1580,
      "Too few items in %{PROPERTY}@.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1590,
      "Too many items in %{PROPERTY}@.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1600,
      "Items cannot be deleted from %{PROPERTY}@.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1610,
      "%{PROPERTY}@ is too large.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1620,
      "%{PROPERTY}@ is too small.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1630,
      "%{PROPERTY}@ is too late.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1640,
      "%{PROPERTY}@ is too soon.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1650,
      "%{PROPERTY}@ is invalid.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1660,
      "%{PROPERTY}@ is too long.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1670,
      "%{PROPERTY}@ is too short.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 1680,
      "%{PROPERTY}@ is invalid.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 2048,
      "The value is invalid.", "The value is invalid.",
      "Please provide a valid value.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 3072,
      "The operation was cancelled.", "The operation was cancelled.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 3328,
      "The requested operation couldn\u2019t be completed because the feature is not supported.", "The requested operation is not supported.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 3840,
      "The data couldn\u2019t be read because it isn\u2019t in the correct format.", "The data is not in the correct format.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 3841,
      "The data couldn\u2019t be read because it is in a format that this application doesn\u2019t understand.", "The data is in a format that this application doesn\u2019t understand.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 3842,
      "The data couldn\u2019t be read because of an error in the source of the data.", "An error occurred in the source of the data.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 3851,
      "The data couldn\u2019t be written because of an error in the destination for the data.", "An error occurred in the destination for the data.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 3852,
      "The data couldn\u2019t be written because of an error in the content of the data.", "An error occurred in the content of the data.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4097,
      "Couldn\u2019t communicate with a helper application.", NULL,
      "Try your operation again. If that fails, quit and relaunch the application and try again.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4099,
      "Couldn\u2019t communicate with a helper application.", NULL,
      "Try your operation again. If that fails, quit and relaunch the application and try again.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4101,
      "Couldn\u2019t communicate with a helper application.", NULL,
      "Try your operation again. If that fails, quit and relaunch the application and try again.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4353,
      "Couldn\u2019t retrieve the contents of the file because it is not available on iCloud yet.", "The file is not available on iCloud yet.",
      "Please wait for the device which created this document to upload it to iCloud.",
      "Couldn\u2019t retrieve the contents of {NAME} because it is not available on iCloud yet.", "The file is not available on iCloud yet.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4354,
      "Couldn\u2019t upload the file to iCloud because there isn\u2019t enough space in your account.", "There isn\u2019t enough space in your account.",
      "Please visit iCloud Settings to make more space available on your account.",
      "Couldn\u2019t upload {NAME} to iCloud because there isn\u2019t enough space in your account.", "There isn\u2019t enough space in your account.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4355,
      "Couldn\u2019t access your iCloud account. The iCloud servers might be unreachable or your settings might be incorrect.", "The iCloud servers might be unreachable or your settings might be incorrect.",
      "Please check your network and your iCloud settings.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4608,
      "Handoff couldn\u2019t be completed.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4609,
      "Handoff couldn\u2019t be completed because the network is not available.", NULL,
      "Please enable network connectivity and try again.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4610,
      "Handoff couldn\u2019t be completed because the application on your other device did not respond in time.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4611,
      "Handoff couldn\u2019t be completed because the application on your other device sent too much information.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4864,
      "The data couldn\u2019t be read because it isn\u2019t in the correct format.", "The data isn\u2019t in the correct format.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4865,
      "The data couldn\u2019t be read because it is missing.", "The data is missing.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4866,
      "The data couldn\u2019t be written because it isn\u2019t in the correct format.", "The data isn\u2019t in the correct format.",
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4992,
      "The requested application data could not be downloaded because there is not enough storage on the device.", "There isn\u2019t enough storage on the device.",
      "Remove some data or applications from your device and try again.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4993,
      "The requested application data will exceed the size limit allowed for this application.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4994,
      "The requested application data doesn\u2019t exist.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 4995,
      "The App Store is temporarily unavailable.", NULL,
      "Try again later.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 5120,
      "Your invitation couldn\u2019t be sent.", NULL,
      "There may be a problem with the server. Please try again later.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 5121,
      "Your invitation couldn\u2019t be sent.", NULL,
      "You don\u2019t have enough iCloud storage to share this. Upgrade your storage plan, or delete other items from iCloud.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 5122,
      "You\u2019ve reached the maximum number of invites.", NULL,
      "New invitations can\u2019t be sent. Reduce the number of people you\u2019re inviting or have previously invited, then try again.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 5123,
      "Your invitation couldn\u2019t be sent.", NULL,
      "Changes were made on another device. Please try again.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 5124,
      "Your invitation couldn\u2019t be sent.", NULL,
      "You don\u2019t have permission to share this.",
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
    { 5375,
      "Sorry, your invitation couldn\u2019t be sent.", NULL,
      NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL,
      NULL, NULL },
};

static const CocoaErrorEntry *entryForCode(NSInteger code) {
    size_t lo = 0, hi = sizeof cocoaErrorTable / sizeof cocoaErrorTable[0];
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        if (cocoaErrorTable[mid].code == code)
            return &cocoaErrorTable[mid];
        if (cocoaErrorTable[mid].code < code)
            lo = mid + 1;
        else
            hi = mid;
    }
    return NULL;
}

// The name of the volume that holds an existing directory, or nil.
static NSString *volumeNameOfDirectory(NSString *directory) {
    if ([directory length] == 0 || ![directory isAbsolutePath])
        return nil;
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath: directory isDirectory: &isDirectory] || !isDirectory)
        return nil;
    id name = nil;
    if (![[NSURL fileURLWithPath: directory isDirectory: YES] getResourceValue: &name
                                                                        forKey: NSURLVolumeNameKey
                                                                         error: NULL] ||
        ![name isKindOfClass: [NSString class]])
        return nil;
    return name;
}

static NSString *quoted(NSString *s) {
    return [NSString stringWithFormat: @"“%@”", s];
}

static NSString *fill(const char *text, NSDictionary<NSString *, NSString *> *values) {
    if (text == NULL)
        return nil;
    NSMutableString *result = [NSMutableString stringWithUTF8String: text];
    for (NSString *key in values)
        [result replaceOccurrencesOfString: key
                                withString: values[key]
                                   options: 0
                                     range: NSMakeRange(0, [result length])];
    return result;
}

// The wording a variant in the userInfo's NSUserStringVariant (a string, or an array of strings) gives some codes:
// "Folder" for the errors of listing or reading a directory, "Remove" for the errors of removing an item. desc is the
// description without a file name (NULL: unchanged), descName the one with it (NULL: unchanged), reason the failure
// reason (NULL: unchanged). Observed like the rest of the table.
typedef struct {
    NSInteger code;
    const char *variant;
    const char *desc, *descName, *reason;
} CocoaErrorVariant;

static const CocoaErrorVariant cocoaErrorVariants[] = {
    { 4, "Folder", "The folder doesn\u2019t exist.", "The folder {NAME} doesn\u2019t exist.", "The folder doesn\u2019t exist." },
    { 260, "Folder", NULL, "The folder {NAME} doesn\u2019t exist.", "The folder doesn\u2019t exist." },
    { 4, "Remove", NULL, "{NAME} couldn\u2019t be removed.", NULL },
    { 512, "Remove", NULL, "{NAME} couldn\u2019t be removed.", NULL },
    { 513, "Remove", NULL, "{NAME} couldn\u2019t be removed because you don\u2019t have permission to access it.", NULL },
    { 514, "Remove", NULL, "The item couldn\u2019t be removed because the file name {NAME} is invalid.", NULL },
};

static BOOL hasVariant(NSDictionary *userInfo, const char *variant) {
    id value = userInfo[@"NSUserStringVariant"];
    NSString *wanted = [NSString stringWithUTF8String: variant];
    if ([value isKindOfClass: [NSString class]])
        return [value isEqualToString: wanted];
    if ([value isKindOfClass: [NSArray class]])
        return [value containsObject: wanted];
    return NO;
}

// The text that applies to the information the userInfo gives about the file, falling back through the forms
// from the most to the least specific one.
static NSString *textFor(NSInteger which, const CocoaErrorEntry *e, NSDictionary *userInfo) {
    // which: 0 description, 1 failure reason, 2 recovery suggestion
    const char *plain = which == 0 ? e->desc : which == 1 ? e->reason : e->suggestion;
    if (which == 2)
        return plain ? [NSString stringWithUTF8String: plain] : nil;
#define FORM(field) (which == 0 ? e->desc##field : e->reason##field)
    id pathValue = userInfo[NSFilePathErrorKey];
    id urlValue = userInfo[NSURLErrorKey];
    id encodingValue = userInfo[NSStringEncodingErrorKey];
    NSString *path = [pathValue isKindOfClass: [NSString class]] ? pathValue : nil;
    NSURL *url = [urlValue isKindOfClass: [NSURL class]] ? urlValue : nil;
    if (path == nil && url != nil)
        path = [url path];
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    const char *chosen = plain;

    if ([encodingValue isKindOfClass: [NSNumber class]] && FORM(Encoding) != NULL) {
        values[@"{ENC}"] = [NSString localizedNameOfStringEncoding: [encodingValue unsignedIntegerValue]];
        chosen = FORM(Encoding);
    } else if (path != nil) {
        NSString *name = [path lastPathComponent];
        NSString *directory = [path stringByDeletingLastPathComponent];
        NSString *folder = nil, *volume = nil;
        if ([directory isEqualToString: @"/"])
            folder = volumeNameOfDirectory(directory);
        else if ([directory length] > 0)
            folder = [directory lastPathComponent];
        volume = volumeNameOfDirectory(directory);
        values[@"{NAME}"] = quoted(name);
        if (FORM(Scheme) != NULL) {
            // Only a URL has a scheme; without one the text does not change.
            if (url != nil && [url scheme] != nil) {
                values[@"{SCHEME}"] = [url scheme];
                chosen = FORM(Scheme);
            }
        } else if (volume != nil && FORM(Volume) != NULL) {
            values[@"{VOLUME}"] = quoted(volume);
            chosen = FORM(Volume);
        } else if (folder != nil && FORM(Folder) != NULL) {
            values[@"{FOLDER}"] = quoted(folder);
            chosen = FORM(Folder);
        } else if (FORM(Name) != NULL) {
            chosen = FORM(Name);
        }
    }
#undef FORM
    if (which != 2) {
        for (size_t i = 0; i < sizeof cocoaErrorVariants / sizeof cocoaErrorVariants[0]; i++) {
            const CocoaErrorVariant *v = &cocoaErrorVariants[i];
            if (v->code != e->code || !hasVariant(userInfo, v->variant))
                continue;
            if (which == 1 && v->reason != NULL)
                chosen = v->reason;
            else if (which == 0 && values[@"{NAME}"] != nil && v->descName != NULL)
                chosen = v->descName;
            else if (which == 0 && values[@"{NAME}"] == nil && v->desc != NULL)
                chosen = v->desc;
        }
    }
    return fill(chosen, values);
}

// The callback of NSCocoaErrorDomain; returns a retained string, or NULL.
static CFTypeRef cocoaErrorUserInfoValue(CFErrorRef error, CFStringRef key) {
    int which;
    if (CFEqual(key, CFSTR("NSLocalizedDescription")))
        which = 0;
    else if (CFEqual(key, CFSTR("NSLocalizedFailureReason")))
        which = 1;
    else if (CFEqual(key, CFSTR("NSLocalizedRecoverySuggestion")))
        which = 2;
    else
        return NULL;
    const CocoaErrorEntry *entry = entryForCode((NSInteger) CFErrorGetCode(error));
    if (entry == NULL)
        return NULL;
    CFDictionaryRef userInfo = CFErrorCopyUserInfo(error);
    NSString *text = textFor(which, entry, (NSDictionary *) userInfo);
    if (userInfo != NULL)
        CFRelease(userInfo);
    return text != nil ? CFRetain((CFTypeRef) text) : NULL;
}

__attribute__((constructor)) static void registerCocoaErrorDescriptions(void) {
    CFErrorSetCallBackForDomain(kCFErrorDomainCocoa, cocoaErrorUserInfoValue);
}
