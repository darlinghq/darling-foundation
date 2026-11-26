//
//  NSErrorConstants.m
//  Foundation
//
//  Copyright (C) 2026 Lubos Dolezel
//

#import <Foundation/NSError.h>

// The error domains and userInfo keys declared in NSError.h are Foundation's own symbols:
// binaries built for macOS import them from Foundation. (CoreFoundation's NSError
// implementation keeps private copies; kCFErrorDomain* and kCFError*Key are separate objects
// there, as on macOS.)
NSString *const NSCocoaErrorDomain = @"NSCocoaErrorDomain";
NSString *const NSPOSIXErrorDomain = @"NSPOSIXErrorDomain";
NSString *const NSOSStatusErrorDomain = @"NSOSStatusErrorDomain";
NSString *const NSMachErrorDomain = @"NSMachErrorDomain";

NSString *const NSUnderlyingErrorKey = @"NSUnderlyingError";
NSString *const NSLocalizedDescriptionKey = @"NSLocalizedDescription";
NSString *const NSLocalizedFailureReasonErrorKey = @"NSLocalizedFailureReason";
NSString *const NSLocalizedRecoverySuggestionErrorKey = @"NSLocalizedRecoverySuggestion";
NSString *const NSLocalizedRecoveryOptionsErrorKey = @"NSLocalizedRecoveryOptions";
NSString *const NSRecoveryAttempterErrorKey = @"NSRecoveryAttempter";
NSString *const NSHelpAnchorErrorKey = @"NSHelpAnchor";
NSString *const NSStringEncodingErrorKey = @"NSStringEncoding";
NSString *const NSURLErrorKey = @"NSURL";
NSString *const NSFilePathErrorKey = @"NSFilePath";
NSString *const NSDebugDescriptionErrorKey = @"NSDebugDescription";
NSString *const NSLocalizedFailureErrorKey = @"NSLocalizedFailure";
NSString *const NSMultipleUnderlyingErrorsKey = @"NSMultipleUnderlyingErrorsKey";
