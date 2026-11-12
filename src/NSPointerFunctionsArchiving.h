/*
 This file is part of Darling.

 Copyright (C) 2026 Lubos Dolezel

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

// Shared by the keyed coding of NSHashTable, NSMapTable and NSPointerArray,
// which all archive their NSPointerFunctionsOptions and their members.
#import <Foundation/NSPointerFunctions.h>

// QUIRK: only tables and arrays of objects can be archived: strong or weak
// memory, object or object-pointer personality, optionally with copy-in. Any
// other combination (opaque, malloc'd or mapped memory; opaque, C string,
// struct or integer personality) fails the archiving with an exception.
// Not documented. Evidence: black-box observation on macOS 27 (tier 2),
// probe vd-upstream/mac-probes/v398-collections-layout.m.
// Test: test_quirk_collection_options_must_be_object_options in
// tests/secure-coding-conformance.m
static inline BOOL NSPointerFunctionsOptionsAreArchivable(NSPointerFunctionsOptions options)
{
    NSPointerFunctionsOptions memory = options & 0xff;
    NSPointerFunctionsOptions personality = options & 0xff00;
    NSPointerFunctionsOptions other = options & ~(NSPointerFunctionsOptions)(0xffff);
    BOOL memoryOK = memory == NSPointerFunctionsStrongMemory || memory == NSPointerFunctionsWeakMemory || memory == NSPointerFunctionsZeroingWeakMemory;
    BOOL personalityOK = personality == NSPointerFunctionsObjectPersonality || personality == NSPointerFunctionsObjectPointerPersonality;
    return memoryOK && personalityOK && (other & ~(NSPointerFunctionsOptions)NSPointerFunctionsCopyIn) == 0;
}

static inline BOOL NSPointerFunctionsOptionsAreWeak(NSPointerFunctionsOptions options)
{
    NSPointerFunctionsOptions memory = options & 0xff;
    return memory == NSPointerFunctionsWeakMemory || memory == NSPointerFunctionsZeroingWeakMemory;
}

// QUIRK: weak members are archived as a reference to one separate string object
// "$null" (not the archive's nil entry, which is kept for the nil terminator and
// for NULL slots); the table's member count stays in NS.count. They cannot be
// restored, so a decoded weak table holds nothing and a weak array holds NULL
// slots. Evidence: black-box observation on macOS 26.7.3 (tier 2), MC26.13,
// probe vd-upstream/mac-probes/v398-pending.m (earlier observation on macOS 27:
// probe v398-collections-layout.m, which saw the nil entry).
// Test: test_quirk_weak_members_are_not_archived in tests/secure-coding-conformance.m
#define NSPointerFunctionsWeakMemberPlaceholder @"$null"
