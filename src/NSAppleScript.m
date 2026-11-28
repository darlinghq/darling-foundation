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
#import <Foundation/NSAppleEventDescriptor.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSPipe.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSTask.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSValue.h>

enum {
    NSAppleScriptErrorCannotOpenComponent = -1753, /* NSAppleScriptErrorCannotOpenComponent */
};

NSString *const NSAppleScriptErrorMessage = @"NSAppleScriptErrorMessage";
NSString *const NSAppleScriptErrorNumber = @"NSAppleScriptErrorNumber";
NSString *const NSAppleScriptErrorAppName = @"NSAppleScriptErrorAppName";
NSString *const NSAppleScriptErrorBriefMessage = @"NSAppleScriptErrorBriefMessage";
NSString *const NSAppleScriptErrorRange = @"NSAppleScriptErrorRange";

static void setScriptError(NSDictionary **errorInfo, NSString *message, NSInteger number)
{
    if (errorInfo == NULL)
        return;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:message ?: @"AppleScript error" forKey:NSAppleScriptErrorMessage];
    [dict setObject:[NSNumber numberWithInteger:number] forKey:NSAppleScriptErrorNumber];
    [dict setObject:message ?: @"AppleScript error" forKey:NSAppleScriptErrorBriefMessage];
    *errorInfo = dict;
}

static NSString *findOSAScript(void)
{
    static NSString *cached;
    static BOOL checked = NO;
    if (checked)
        return cached;
    checked = YES;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *candidates = @[
        @"/usr/bin/osascript",
        @"/bin/osascript",
    ];
    for (NSString *path in candidates) {
        if ([fm isExecutableFileAtPath:path]) {
            cached = [path copy];
            return cached;
        }
    }
    return nil;
}

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
    if (self == nil)
        return nil;

    if (url == nil) {
        setScriptError(errorInfo, @"Invalid URL", -1);
        [self release];
        return nil;
    }

    _url = [url copy];
    NSError *readError = nil;
    NSString *source = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&readError];
    if (source == nil) {
        NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&readError];
        if (data != nil)
            source = [[[NSString alloc] initWithData:data encoding:NSUnicodeStringEncoding] autorelease];
    }
    if (source == nil) {
        NSString *msg = [readError localizedDescription] ?: @"Could not read script";
        setScriptError(errorInfo, msg, [readError code]);
        [self release];
        return nil;
    }

    _source = [source copy];
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
    if (_source == nil) {
        setScriptError(errorInfo, @"No source", -1);
        return NO;
    }

    NSString *osascript = findOSAScript();
    if (osascript == nil) {
        // No engine available; keep source-only behavior.
        setScriptError(errorInfo, @"AppleScript compilation is not supported on this platform", NSAppleScriptErrorCannotOpenComponent);
        return NO;
    }

    // Use osacompile if available, otherwise treat source as runnable.
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *osacompile = @"/usr/bin/osacompile";
    if (![fm isExecutableFileAtPath:osacompile])
        osacompile = nil;

    if (osacompile == nil) {
        _compiled = YES;
        return YES;
    }

    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
    NSString *scriptPath = [tmp stringByAppendingPathExtension:@"applescript"];
    NSString *outPath = [tmp stringByAppendingPathExtension:@"scpt"];
    if (![_source writeToFile:scriptPath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
        setScriptError(errorInfo, @"Could not write temporary script", -1);
        return NO;
    }

    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:osacompile];
    [task setArguments:@[ @"-o", outPath, scriptPath ]];
    NSPipe *errPipe = [NSPipe pipe];
    [task setStandardError:errPipe];
    [task setStandardOutput:[NSPipe pipe]];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (id e) {
        [fm removeItemAtPath:scriptPath error:nil];
        setScriptError(errorInfo, @"Failed to launch osacompile", -1);
        return NO;
    }

    NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
    [fm removeItemAtPath:scriptPath error:nil];
    [fm removeItemAtPath:outPath error:nil];

    if ([task terminationStatus] != 0) {
        NSString *errMsg = [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] autorelease];
        if ([errMsg length] == 0)
            errMsg = @"AppleScript compilation failed";
        setScriptError(errorInfo, errMsg, [task terminationStatus]);
        return NO;
    }

    _compiled = YES;
    return YES;
}

- (NSAppleEventDescriptor *)executeAndReturnError:(NSDictionary **)errorInfo {
    if (_source == nil) {
        setScriptError(errorInfo, @"No source", -1);
        return nil;
    }

    NSString *osascript = findOSAScript();
    if (osascript == nil) {
        setScriptError(errorInfo, @"AppleScript execution is not supported on this platform", NSAppleScriptErrorCannotOpenComponent);
        return nil;
    }

    NSTask *task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:osascript];
    [task setArguments:@[ @"-e", _source ]];

    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    [task setStandardOutput:outPipe];
    [task setStandardError:errPipe];

    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (id e) {
        setScriptError(errorInfo, @"Failed to launch osascript", -1);
        return nil;
    }

    NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
    NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];

    if ([task terminationStatus] != 0) {
        NSString *errMsg = [[[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] autorelease];
        if ([errMsg length] == 0)
            errMsg = @"AppleScript execution failed";
        setScriptError(errorInfo, errMsg, [task terminationStatus]);
        return nil;
    }

    NSString *outStr = [[[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] autorelease];
    if (outStr == nil)
        outStr = @"";
    // osascript appends a trailing newline
    if ([outStr hasSuffix:@"\n"])
        outStr = [outStr substringToIndex:[outStr length] - 1];

    if ([outStr length] == 0)
        return [NSAppleEventDescriptor nullDescriptor];

    return [NSAppleEventDescriptor descriptorWithString:outStr];
}

- (NSAppleEventDescriptor *)executeAppleEvent:(NSAppleEventDescriptor *)event error:(NSDictionary **)errorInfo {
    // Executing arbitrary Apple events requires a real OSA component.
    setScriptError(errorInfo, @"AppleScript event execution is not supported on this platform", NSAppleScriptErrorCannotOpenComponent);
    return nil;
}

- (id)copyWithZone:(NSZone *)zone {
    NSAppleScript *copy = [[[self class] allocWithZone:zone] initWithSource:_source];
    copy->_url = [_url copy];
    copy->_compiled = _compiled;
    return copy;
}

@end
