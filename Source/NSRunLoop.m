/* NSRunLoop
   Copyright (C) 2016 Lubos Dolezel

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#include <Foundation/NSRunLoop.h>
#include <Foundation/NSException.h>

NSString * const NSDefaultRunLoopMode = @"kCFRunLoopDefaultMode";
NSString * const NSRunLoopCommonModes = @"kCFRunLoopCommonModes";

@implementation NSRunLoop

- (id) initWithCFRunLoop: (CFRunLoopRef) rl
{
	self->_runLoop = (CFRunLoopRef) CFRetain(rl);
}

- (void) dealloc
{
	RELEASE(_runLoop);
	[super dealloc];
}

+ (NSRunLoop*) currentRunLoop
{
	CFRunLoopRef crl = CFRunLoopGetCurrent();
	NSRunLoop* rl = [[NSRunLoop alloc] initWithCFRunLoop: crl];
	return AUTORELEASE(rl);
}

+ (NSRunLoop*) mainRunLoop
{
	CFRunLoopRef crl = CFRunLoopGetMain();
	NSRunLoop* rl = [[NSRunLoop alloc] initWithCFRunLoop: crl];
	return AUTORELEASE(rl);
}

- (CFRunLoopRef) getCFRunLoop;
{
	return _runLoop;
}

- (void) acceptInputForMode: (NSString*)mode
                 beforeDate: (NSDate*)date
{
	if (_runLoop != CFRunLoopGetCurrent())
	{
		[NSException raise: NSGenericException
					format: @"Cannot call -runMode on other than current runloop"];
	}
	
	CFRunLoopRunInMode((CFStringRef) mode, [date timeIntervalSinceNow], YES);
}

- (void) addTimer: (NSTimer*)timer
	  forMode: (NSString*)mode
{
	CFRunLoopAddTimer(_runLoop, (CFRunLoopTimerRef) timer, (CFStringRef) mode);
}

- (NSString*) currentMode
{
	NSString* mode = (NSString*) CFRunLoopCopyCurrentMode(_runLoop);
	return AUTORELEASE(mode);
}

- (NSDate*) limitDateForMode: (NSString*)mode
{
	CFAbsoluteTime at;
	
	CFRunLoopRunInMode((CFStringRef) mode, 0, NO);
	at = CFRunLoopGetNextTimerFireDate(_runLoop, (CFStringRef) mode);
	
	return [NSDate dateWithTimeIntervalSinceReferenceDate: at];
}

- (void) run
{
	if (_runLoop != CFRunLoopGetCurrent())
	{
		[NSException raise: NSGenericException
					format: @"Cannot call -run on other than current runloop"];
	}
	
	CFRunLoopRun();
}


- (BOOL) runMode: (NSString*)mode
      beforeDate: (NSDate*)date
{
	if (_runLoop != CFRunLoopGetCurrent())
	{
		[NSException raise: NSGenericException
					format: @"Cannot call -runMode on other than current runloop"];
	}
	
	return CFRunLoopRunInMode((CFStringRef) mode, [date timeIntervalSinceNow], NO)
			!= kCFRunLoopRunFinished;
}

- (void) runUntilDate: (NSDate*)date
{
	[self runMode: NSDefaultRunLoopMode
	   beforeDate: date];
}

- (void) addPort: (NSPort*)port
         forMode: (NSString*)mode
{
	
}

- (void) cancelPerformSelectorsWithTarget: (id)target
{
	// TODO: Not implemented
}

- (void) cancelPerformSelector: (SEL)aSelector
			target: (id)target
		      argument: (id)argument
{
	// TODO: Not implemented
}

- (void) configureAsServer
{
	
}

- (void) performSelector: (SEL)aSelector
		  target: (id)target
		argument: (id)argument
		   order: (NSUInteger)order
		   modes: (NSArray*)modes
{
	
}

- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode
{
	
}


@end
