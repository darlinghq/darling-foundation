/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free softwareyou can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http//www.gnu.org/licenses/>.
*/

#import <Foundation/NSScriptCommand.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>

@implementation NSScriptCommand

+ (NSScriptCommand *)currentCommand {
    // The documented value is the command being executed on this thread by Apple event dispatch, nil otherwise.
    // Nothing in this Foundation executes an NSScriptCommand (no -executeCommand, no event-to-command dispatch), so
    // no command is ever being executed and nil is the correct answer. Track a per-thread command here when
    // execution is implemented.
    return nil;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes: "v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	NSLog(@"[NSScriptCommand initWithCoder:]");
	return [self init];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	NSLog(@"[NSScriptCommand encodeWithCoder:");
}

@end
