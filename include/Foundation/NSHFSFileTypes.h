#import <CoreFoundation/CFBase.h>
#import <Foundation/NSObjCRuntime.h>

@class NSString;

FOUNDATION_EXPORT NSString* NSFileTypeForHFSTypeCode(OSType hfsFileTypeCode);
FOUNDATION_EXPORT OSType NSHFSTypeCodeFromFileType(NSString* fileType);
FOUNDATION_EXPORT NSString* NSHFSTypeOfFile(NSString* filePath);

