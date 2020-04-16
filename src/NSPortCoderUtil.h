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

#import <objc/runtime.h>
#import <string.h>

static inline BOOL hasQualifier(const char *t1, const char *t2, char q) {
    for (const char *t = t1; t < t2; t++) {
        if (*t == q) return YES;
    }
    return NO;
}

// Check if the given pointer type points to void or to an
// unknown type or an incomplete structure.
static inline BOOL isUnknownPointer(const char *type) {
    if (type[0] != _C_PTR) return NO;
    switch (type[1]) {
    case _C_VOID:
    case _C_UNDEF:
        return YES;
    case _C_STRUCT_B:
        // We still get the name for an empty struct,
        // e.g. {foo=}
        return strchr(type, '=')[1] == _C_STRUCT_E;
    default:
        return NO;
    }
}
