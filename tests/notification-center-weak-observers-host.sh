#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs src/NSNotificationCenter.m on the host with mocks; see notification-center-weak-observers-host.m.
# Usage: tests/notification-center-weak-observers-host.sh [OBJC_PREFIX]   (OBJC_PREFIX: a GNUstep-ABI libobjc2 with
#   include/ and lib/). Environment: CC (default cc), OBJC_RUNTIME (default gnustep-1.7), OBJC_LIBS (default
#   "-lobjc -lpthread"), NSNOTIFICATIONCENTER_M (another NSNotificationCenter.m, to check the test fails there).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${NSNOTIFICATIONCENTER_M:-$root/src/NSNotificationCenter.m}
prefix_flags=()
[ $# -ge 1 ] && prefix_flags=(-I"$1/include" -L"$1/lib")
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

grep -v -E '^#(include|import)' "$src" >"$temp/source.inc"
grep -q '^@implementation NSNotificationCenter$' "$temp/source.inc" ||
    { echo "FAIL: no @implementation NSNotificationCenter in $src; update $0" >&2; exit 1; }

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fblocks -fno-objc-arc \
    -Wall -Wno-objc-root-class -Wno-unused-function -Wno-#warnings -Wno-incomplete-implementation \
    -DSOURCE_INC="\"$temp/source.inc\"" \
    "${prefix_flags[@]}" "$root/tests/notification-center-weak-observers-host.m" ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/notification-center"
"$temp/notification-center"
