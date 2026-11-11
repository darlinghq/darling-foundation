#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Usage: tests/atomic-write-cleanup-host.sh [OBJC_PREFIX]   (a GNUstep-ABI libobjc2 with include/ and lib/).
# Runs _NSWriteBytesToFile() from src/_NSFileIO.m on the host against mock NSString/NSData/NSError classes; see
# atomic-write-cleanup-host.m. Environment: CC (default cc), OBJC_RUNTIME (default gnustep-1.9), OBJC_LIBS (default
# "-lobjc -lpthread"), NSFILEIO_M (another copy of _NSFileIO.m, to check the test fails there).
# On aarch64 a libobjc2 without objc_msgSend needs OBJC_RUNTIME=gnustep-1.8.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${NSFILEIO_M:-$root/src/_NSFileIO.m}
prefix_flags=()
[ $# -ge 1 ] && prefix_flags=(-I"$1/include" -L"$1/lib")
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

awk '/^BOOL _NSWriteBytesToFile\(/ {on=1; found=1} on {print} on && /^}/ {on=0} END {exit !found}' "$src" >"$temp/methods.inc" ||
    { echo "FAIL: no _NSWriteBytesToFile in $src; update $0" >&2; exit 1; }

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.9}" -fno-objc-arc \
    -Wall -Wno-objc-root-class -DMETHODS_INC="\"$temp/methods.inc\"" \
    "${prefix_flags[@]}" "$root/tests/atomic-write-cleanup-host.m" ${OBJC_LIBS:--lobjc -lpthread} -o "$temp/atomic-write"
"$temp/atomic-write"
