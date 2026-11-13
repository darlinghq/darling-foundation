/*
 Copyright (C) 2026 Lubos Dolezel

 Licensed under the MIT license, the same as the rest of this project.
*/
// The NSURL resource keys, file resource types and ubiquitous item values that
// the public header declares are exported, typed, and have the string values
// the documentation gives (each value is the constant's own name).
#import <Foundation/Foundation.h>
#include <stdio.h>

static int failures;

#define CHECK_CONST(c) do { \
    BOOL ok = [(c) isEqualToString: @#c]; \
    printf("%s %s\n", ok ? "PASS" : "FAIL", #c); \
    failures += !ok; \
} while (0)

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSURLResourceKey key = NSURLTagNamesKey;
    NSURLFileResourceType type = NSURLFileResourceTypeRegular;
    NSURLUbiquitousItemDownloadingStatus status = NSURLUbiquitousItemDownloadingStatusCurrent;
    NSURLUbiquitousSharedItemRole role = NSURLUbiquitousSharedItemRoleOwner;
    NSURLUbiquitousSharedItemPermissions permissions = NSURLUbiquitousSharedItemPermissionsReadOnly;
    (void)key; (void)type; (void)status; (void)role; (void)permissions;

    CHECK_CONST(NSURLAddedToDirectoryDateKey);
    CHECK_CONST(NSURLTagNamesKey);
    CHECK_CONST(NSURLCanonicalPathKey);
    CHECK_CONST(NSURLGenerationIdentifierKey);
    CHECK_CONST(NSURLDocumentIdentifierKey);
    CHECK_CONST(NSURLQuarantinePropertiesKey);
    CHECK_CONST(NSURLIsApplicationKey);
    CHECK_CONST(NSURLApplicationIsScriptableKey);
    CHECK_CONST(NSURLIsPurgeableKey);
    CHECK_CONST(NSURLIsSparseKey);
    CHECK_CONST(NSURLMayHaveExtendedAttributesKey);
    CHECK_CONST(NSURLMayShareFileContentKey);
    CHECK_CONST(NSURLDirectoryEntryCountKey);
    CHECK_CONST(NSURLFileIdentifierKey);
    CHECK_CONST(NSURLFileContentIdentifierKey);
    CHECK_CONST(NSURLFileProtectionKey);
    CHECK_CONST(NSURLThumbnailDictionaryKey);
    CHECK_CONST(NSURLThumbnailKey);
    CHECK_CONST(NSURLVolumeIsEncryptedKey);
    CHECK_CONST(NSURLVolumeIsRootFileSystemKey);
    CHECK_CONST(NSURLVolumeAvailableCapacityForImportantUsageKey);
    CHECK_CONST(NSURLVolumeAvailableCapacityForOpportunisticUsageKey);
    CHECK_CONST(NSURLVolumeTypeNameKey);
    CHECK_CONST(NSURLVolumeSubtypeKey);
    CHECK_CONST(NSURLVolumeMountFromLocationKey);
    CHECK_CONST(NSURLUbiquitousItemDownloadingStatusKey);
    CHECK_CONST(NSURLUbiquitousItemDownloadingErrorKey);
    CHECK_CONST(NSURLUbiquitousItemUploadingErrorKey);
    CHECK_CONST(NSURLUbiquitousItemDownloadRequestedKey);
    CHECK_CONST(NSURLUbiquitousItemContainerDisplayNameKey);
    CHECK_CONST(NSURLUbiquitousItemIsSharedKey);
    CHECK_CONST(NSURLUbiquitousItemIsExcludedFromSyncKey);
    CHECK_CONST(NSURLUbiquitousItemIsSyncPausedKey);
    CHECK_CONST(NSURLUbiquitousItemSupportedSyncControlsKey);
    CHECK_CONST(NSURLUbiquitousSharedItemCurrentUserRoleKey);
    CHECK_CONST(NSURLUbiquitousSharedItemCurrentUserPermissionsKey);
    CHECK_CONST(NSURLUbiquitousSharedItemOwnerNameComponentsKey);
    CHECK_CONST(NSURLUbiquitousSharedItemMostRecentEditorNameComponentsKey);
    CHECK_CONST(NSURLFileResourceTypeNamedPipe);
    CHECK_CONST(NSURLFileResourceTypeCharacterSpecial);
    CHECK_CONST(NSURLFileResourceTypeDirectory);
    CHECK_CONST(NSURLFileResourceTypeBlockSpecial);
    CHECK_CONST(NSURLFileResourceTypeRegular);
    CHECK_CONST(NSURLFileResourceTypeSymbolicLink);
    CHECK_CONST(NSURLFileResourceTypeSocket);
    CHECK_CONST(NSURLFileResourceTypeUnknown);
    CHECK_CONST(NSURLUbiquitousItemDownloadingStatusNotDownloaded);
    CHECK_CONST(NSURLUbiquitousItemDownloadingStatusDownloaded);
    CHECK_CONST(NSURLUbiquitousItemDownloadingStatusCurrent);
    CHECK_CONST(NSURLUbiquitousSharedItemRoleOwner);
    CHECK_CONST(NSURLUbiquitousSharedItemRoleParticipant);
    CHECK_CONST(NSURLUbiquitousSharedItemPermissionsReadOnly);
    CHECK_CONST(NSURLUbiquitousSharedItemPermissionsReadWrite);
    // already declared before, but only exported from CoreFoundation through the list this change completes
    CHECK_CONST(NSURLVolumeTotalCapacityKey);
    CHECK_CONST(NSURLVolumeAvailableCapacityKey);
    CHECK_CONST(NSURLIsReadableKey);
    CHECK_CONST(NSURLContentTypeKey);

    [pool drain];
    return failures ? 1 : 0;
}
