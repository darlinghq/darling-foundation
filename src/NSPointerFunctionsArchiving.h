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
#import <Foundation/NSCoder.h>
#import <Foundation/NSKeyedArchiver.h>

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

// QUIRK: weak slots of an NSPointerArray are archived as a separate "$null"
// string object; they cannot be restored, so a decoded weak array holds NULL
// slots. Evidence: black-box observation on macOS 26.7.3 (tier 2), MC26.13,
// probe vd-upstream/mac-probes/v398-pending.m.
// Test: test_quirk_weak_members_are_not_archived in tests/secure-coding-conformance.m
#define NSPointerFunctionsWeakMemberPlaceholder @"$null"

// QUIRK: a weak member of an NSMapTable or NSHashTable in a keyed archive is
// encoded conditionally: it is archived as the object itself when that object is
// also encoded unconditionally somewhere in the same archive (before or after
// the table), and as a separate "$null" string object otherwise. The table's
// member count stays in NS.count and decoding reads that many entries, dropping
// those whose key, value or member came back nil. Evidence: black-box
// observation on macOS 26.7.3 and 10.14.4 (tier 2; archives of weak, strong and
// copy tables with and without the members encoded elsewhere), and the nib of an
// NSStackView archived on macOS 26.7.3, whose weak object-pointer tables are keyed by the views.
// NSPointerArray keeps writing a "$null" string for every weak slot (MC26.13,
// probe vd-upstream/mac-probes/v398-pending.m).
// Test: test_quirk_weak_table_members_are_conditional in
// tests/maptable-archive-fixtures.m
static inline void NSPointerFunctionsEncodeMember(NSCoder *coder, id member, BOOL weak)
{
    if (!weak)
    {
        [coder encodeObject: member];
    }
    else if ([coder allowsKeyedCoding])
    {
        [coder encodeConditionalObject: member];
    }
    else
    {
        // Without keys the entries are read up to a nil, so a weak member is written
        // as the placeholder, which is not restored.
        [coder encodeObject: NSPointerFunctionsWeakMemberPlaceholder];
    }
}

// Whether the archive still holds the value written without a key at position `position` of the
// object being decoded ($0, $1, ...). Decoding reads at most the entries that are there, so an
// archive that claims an enormous NS.count does not keep the decoder busy. Other keyed decoders
// (nibs) are asked nothing: their keys are not addressable this way.
static inline BOOL NSPointerFunctionsArchiveHasValue(NSCoder *coder, int position)
{
    if (![coder isKindOfClass: [NSKeyedUnarchiver class]])
    {
        return YES;
    }
    // A key that starts with $ is looked up without that first character.
    return [coder containsValueForKey: [NSString stringWithFormat: @"$$%d", position]];
}
