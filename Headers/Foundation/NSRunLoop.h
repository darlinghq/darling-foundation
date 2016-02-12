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

#ifndef __NSRunLoop_h_
#define __NSRunLoop_h_
#import	<GNUstepBase/GSVersionMacros.h>
#import <Foundation/NSString.h>
#include <CoreFoundation/CFRunLoop.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSTimer, NSDate, NSPort;

GS_EXPORT NSString * const NSDefaultRunLoopMode;
GS_EXPORT NSString * const NSRunLoopCommonModes;

@interface NSRunLoop : NSObject
{
	CFRunLoopRef _runLoop;
}

+ (NSRunLoop*) currentRunLoop;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST)
+ (NSRunLoop*) mainRunLoop;
#endif

- (CFRunLoopRef) getCFRunLoop;

- (void) acceptInputForMode: (NSString*)mode
                 beforeDate: (NSDate*)limit_date;

- (void) addTimer: (NSTimer*)timer
	  forMode: (NSString*)mode;

- (NSString*) currentMode;

- (NSDate*) limitDateForMode: (NSString*)mode;

- (void) run;


- (BOOL) runMode: (NSString*)mode
      beforeDate: (NSDate*)date;

- (void) runUntilDate: (NSDate*)date;

- (void) addPort: (NSPort*)port
         forMode: (NSString*)mode;

- (void) cancelPerformSelectorsWithTarget: (id)target;

- (void) cancelPerformSelector: (SEL)aSelector
			target: (id)target
		      argument: (id)argument;

- (void) configureAsServer;

- (void) performSelector: (SEL)aSelector
		  target: (id)target
		argument: (id)argument
		   order: (NSUInteger)order
		   modes: (NSArray*)modes;

- (void) removePort: (NSPort*)port
            forMode: (NSString*)mode;

@end

#if	defined(__cplusplus)
}
#endif

#endif /*__NSRunLoop_h_GNUSTEP_BASE_INCLUDE */
