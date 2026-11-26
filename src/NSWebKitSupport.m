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

// Private methods that macOS's Foundation has for WebKit. Their behaviour was
// observed on macOS 26.7.3 (tests/nsstring-web-looks-like-ip-address.m and
// tests/nserror-web-localized-description.m).

#import <Foundation/NSError.h>
#import <Foundation/NSString.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>

// Four parts of one or more ASCII digits each, separated by dots; any number
// of leading zeros, and a value of at most 255.
static bool isIPv4Address(const char *start, const char *end)
{
    int parts = 0;
    const char *p = start;
    while (true) {
        unsigned value = 0;
        const char *digits = p;
        while (p < end && *p >= '0' && *p <= '9') {
            value = value * 10 + (*p - '0');
            if (value > 255)
                return false;
            p++;
        }
        if (p == digits)
            return false;
        parts++;
        if (p == end)
            return parts == 4;
        if (*p != '.' || parts == 4)
            return false;
        p++;
    }
}

static int hexDigitValue(char c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

// Groups of hex digits (any number of leading zeros, a value of at most
// 0xFFFF) separated by colons, with at most one "::" standing for one or more
// zero groups, and optionally an IPv4 address as the last two groups.
static bool isIPv6Address(const char *start, const char *end)
{
    int groups = 0;
    bool compressed = false;
    const char *p = start;

    if (p < end && *p == ':') {
        if (end - p < 2 || p[1] != ':')
            return false;
        compressed = true;
        p += 2;
        if (p == end)
            return true;
    }

    while (true) {
        const char *group = p;
        unsigned value = 0;
        while (p < end && hexDigitValue(*p) >= 0) {
            value = (value << 4) | (unsigned) hexDigitValue(*p);
            if (value > 0xFFFF)
                break;
            p++;
        }
        if (p < end && *p == '.') {
            // The rest is an IPv4 address, in place of two groups.
            if (!isIPv4Address(group, end))
                return false;
            groups += 2;
            break;
        }
        if (p == group || value > 0xFFFF)
            return false;
        groups++;
        if (p == end)
            break;
        if (*p != ':')
            return false;
        p++;
        if (p < end && *p == ':') {
            if (compressed)
                return false;
            compressed = true;
            p++;
            if (p == end)
                break;
        } else if (p == end) {
            return false;
        }
    }

    return compressed ? groups < 8 : groups == 8;
}

@implementation NSString (NSWebKitSupport)

// Whether the string is a numeric IPv4 address, or an IPv6 address with an
// optional zone after a single "%".
- (BOOL) _web_looksLikeIPAddress
{
    const char *string = [self UTF8String];
    if (string == NULL)
        return NO;
    const char *end = string + strlen(string);

    const char *percent = strchr(string, '%');
    if (percent != NULL) {
        if (strchr(percent + 1, '%') != NULL)
            return NO;
        return isIPv6Address(string, percent);
    }
    return isIPv4Address(string, end) || isIPv6Address(string, end);
}

@end

@implementation NSError (NSWebKitSupport)

// On macOS, URL loading errors give the system's description of their code
// here whatever their user info says. Darling has no such descriptions, so
// this is the error's localized description for every domain.
- (NSString *) _web_localizedDescription
{
    return [self localizedDescription];
}

@end
