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


#import <NSDistributedNotificationCenter.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSIndexSet.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFPriv.h>

NSDistributedNotificationCenterType const NSLocalNotificationCenterType = @"_NSLocalNotificationCenter";

// One registration of an observer: the CF center calls back with the registration, which knows the observer and
// the selector. The observer is not retained, as with NSNotificationCenter.
@interface _NSDistributedNotificationRegistration : NSObject {
@public
	id observer;
	SEL selector;
	NSString *name;
	NSString *object;
}
@end

@implementation _NSDistributedNotificationRegistration
- (void)dealloc
{
	[name release];
	[object release];
	[super dealloc];
}
@end

static void deliverToObserver(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	_NSDistributedNotificationRegistration *registration = observer;
	NSNotification *notification = [NSNotification notificationWithName:(NSString *) name object:(id) object userInfo:(NSDictionary *) userInfo];
	[registration->observer performSelector:registration->selector withObject:notification];
}

@implementation NSDistributedNotificationCenter

+ (NSDistributedNotificationCenter *)notificationCenterForType:(NSDistributedNotificationCenterType)notificationCenterType
{
	if (![notificationCenterType isEqual:NSLocalNotificationCenterType])
		return nil;
	return [self defaultCenter];
}

+ (NSDistributedNotificationCenter *)defaultCenter
{
	static NSDistributedNotificationCenter *center;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		center = [[NSDistributedNotificationCenter alloc] init];
	});
	return center;
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
		_registrations = [[NSMutableArray alloc] init];
	return self;
}

- (CFNotificationCenterRef)_center
{
	return CFNotificationCenterGetDistributedCenter();
}

- (BOOL)suspended
{
	return CFNotificationCenterIsSuspended([self _center]);
}

- (void)setSuspended:(BOOL)suspended
{
	CFNotificationCenterSetSuspended([self _center], suspended);
}

- (void)addObserver:(id)observer
	selector:(SEL)selector
	name:(NSNotificationName)name
	object:(NSString *)object
	suspensionBehavior:(NSNotificationSuspensionBehavior)suspensionBehavior
{
	if (observer == nil || selector == NULL)
		return;
	_NSDistributedNotificationRegistration *registration = [[_NSDistributedNotificationRegistration alloc] init];
	registration->observer = observer;
	registration->selector = selector;
	registration->name = [name copy];
	registration->object = [object copy];
	@synchronized (self) {
		[_registrations addObject:registration];
	}
	CFNotificationCenterAddObserver([self _center], registration, deliverToObserver, (CFStringRef) name, (const void *) object,
		(CFNotificationSuspensionBehavior) suspensionBehavior);
	[registration release];
}

- (void)addObserver:(id)observer selector:(SEL)aSelector name:(NSNotificationName)aName object:(NSString *)anObject
{
	[self addObserver:observer selector:aSelector name:aName object:anObject suspensionBehavior:NSNotificationSuspensionBehaviorCoalesce];
}

- (void)removeObserver:(id)observer name:(NSNotificationName)aName object:(NSString *)anObject
{
	NSArray *matching;
	@synchronized (self) {
		NSIndexSet *indexes = [_registrations indexesOfObjectsPassingTest:^BOOL(_NSDistributedNotificationRegistration *r, NSUInteger i, BOOL *stop) {
			return r->observer == observer && (aName == nil || [r->name isEqual:aName]) && (anObject == nil || [r->object isEqual:anObject]);
		}];
		matching = [[_registrations objectsAtIndexes:indexes] retain];
		[_registrations removeObjectsAtIndexes:indexes];
	}
	for (_NSDistributedNotificationRegistration *r in matching)
		CFNotificationCenterRemoveObserver([self _center], r, NULL, NULL);
	[matching release];
}

- (void)removeObserver:(id)observer
{
	[self removeObserver:observer name:nil object:nil];
}

// The object of a distributed notification is a string; anything else is not accepted.
static NSString *checkedObject(id object)
{
	if (object != nil && ![object isKindOfClass:[NSString class]])
		[NSException raise:NSInvalidArgumentException format:@"The object of a distributed notification must be a string, not %@", [object class]];
	return object;
}

- (void)postNotificationName:(NSNotificationName)name
	object:(NSString *)object
	userInfo:(NSDictionary *)userInfo
	options:(NSDistributedNotificationOptions)options
{
	NSString *string = checkedObject(object);
	CFNotificationCenterPostNotificationWithOptions([self _center], (CFStringRef) name, (const void *) string, (CFDictionaryRef) userInfo, options);
}

- (void)postNotificationName:(NSNotificationName)name
	object:(NSString *)object
	userInfo:(NSDictionary *)userInfo
	deliverImmediately:(BOOL)deliverImmediately
{
	[self postNotificationName:name object:object userInfo:userInfo options:deliverImmediately ? NSDistributedNotificationDeliverImmediately : 0];
}

- (void)postNotificationName:(NSNotificationName)aName object:(NSString *)anObject userInfo:(NSDictionary *)aUserInfo
{
	[self postNotificationName:aName object:anObject userInfo:aUserInfo options:0];
}

- (void)postNotificationName:(NSNotificationName)aName object:(NSString *)anObject
{
	[self postNotificationName:aName object:anObject userInfo:nil options:0];
}

- (void)postNotification:(NSNotification *)notification
{
	[self postNotificationName:[notification name] object:[notification object] userInfo:[notification userInfo] options:0];
}

- (void)dealloc
{
	[_registrations release];
	[super dealloc];
}

@end
