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

#import <Foundation/NSObject.h>

@interface NSScriptObjectSpecifier : NSObject <NSCoding>
@end

@interface NSObject (NSScriptObjectSpecifiers)
@end

@interface NSIndexSpecifier : NSScriptObjectSpecifier
@end

@interface NSMiddleSpecifier : NSScriptObjectSpecifier
@end

@interface NSNameSpecifier : NSScriptObjectSpecifier
@end

@interface NSPositionalSpecifier : NSObject
@end

@interface NSPropertySpecifier : NSScriptObjectSpecifier
@end

@interface NSRandomSpecifier : NSScriptObjectSpecifier
@end

@interface NSRangeSpecifier : NSScriptObjectSpecifier
@end

@interface NSRelativeSpecifier : NSScriptObjectSpecifier
@end

@interface NSUniqueIDSpecifier : NSScriptObjectSpecifier
@end

@interface NSWhoseSpecifier : NSScriptObjectSpecifier
@end
