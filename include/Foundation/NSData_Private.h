/*
 This file is part of Darling.

 Copyright (C) 2020 Lubos Dolezel

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

#ifndef _NSDATA_PRIVATE_H_
#define _NSDATA_PRIVATE_H_

typedef void (^NSDataDeallocator)(void *bytes, NSUInteger length);

FOUNDATION_EXPORT const NSDataDeallocator NSDataDeallocatorVM;
FOUNDATION_EXPORT const NSDataDeallocator NSDataDeallocatorUnmap;
FOUNDATION_EXPORT const NSDataDeallocator NSDataDeallocatorFree;
FOUNDATION_EXPORT const NSDataDeallocator NSDataDeallocatorNone;

// not sure what to name this category
@interface NSData (NSDataPrivateStuff)

+ (id)_newZeroingDataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length deallocator:(NSDataDeallocator)deallocator;

@end

#endif // _NSDATA_PRIVATE_H_
