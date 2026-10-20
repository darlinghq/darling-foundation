/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#import <Foundation/NSAppleScript.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

NSString *const NSAppleScriptErrorMessage = @"NSAppleScriptErrorMessage";
NSString *const NSAppleScriptErrorNumber = @"NSAppleScriptErrorNumber";
NSString *const NSAppleScriptErrorAppName = @"NSAppleScriptErrorAppName";
NSString *const NSAppleScriptErrorBriefMessage = @"NSAppleScriptErrorBriefMessage";
NSString *const NSAppleScriptErrorRange = @"NSAppleScriptErrorRange";

@implementation NSAppleScript

- (instancetype)initWithSource:(NSString *)source {
    self = [super init];
    if (self) {
        _source = [source copy];
    }
    return self;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSDictionary **)errorInfo {
    self = [super init];
    if (self) {
        if (url == nil) {
            if (errorInfo != NULL) {
                *errorInfo = [NSDictionary dictionaryWithObject: @"Invalid URL" forKey: NSAppleScriptErrorMessage];
            }
            [self release];
            return nil;
        }
        _url = [url copy];
    }
    return self;
}

- (void)dealloc {
    [_source release];
    [_url release];
    [super dealloc];
}

- (NSString *)source {
    return _source;
}

- (BOOL)isCompiled {
    return _compiled;
}

- (BOOL)compileAndReturnError:(NSDictionary **)errorInfo {
    // STUB: AppleScript compilation is not supported on Linux
    if (errorInfo != NULL) {
        *errorInfo = [NSDictionary dictionaryWithObject: @"AppleScript compilation is not supported on this platform"
                                                 forKey: NSAppleScriptErrorMessage];
    }
    return NO;
}

- (NSAppleEventDescriptor *)executeAndReturnError:(NSDictionary **)errorInfo {
    if (errorInfo != NULL) {
        *errorInfo = [NSDictionary dictionaryWithObject: @"AppleScript execution is not supported on this platform"
                                                 forKey: NSAppleScriptErrorMessage];
    }
    return nil;
}

- (NSAppleEventDescriptor *)executeAppleEvent:(NSAppleEventDescriptor *)event error:(NSDictionary **)errorInfo {
    if (errorInfo != NULL) {
        *errorInfo = [NSDictionary dictionaryWithObject: @"AppleScript execution is not supported on this platform"
                                                 forKey: NSAppleScriptErrorMessage];
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone {
    // STUB: returns self; true copy unsupported on this platform
    return [self retain];
}

@end
