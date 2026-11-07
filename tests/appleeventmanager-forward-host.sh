#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs NSAppleEventManager's forwarding stub from src/NSAppleEventManager.m on the host against a minimal mock root
# class, NSMethodSignature and NSInvocation; see appleeventmanager-forward-host.m.
# Usage: tests/appleeventmanager-forward-host.sh [OBJC_PREFIX]
#   OBJC_PREFIX holds include/objc/runtime.h and lib/libobjc for a GNUstep-ABI runtime (libobjc2); without it the
#   compiler's default search paths are used. Environment: CC (default cc), OBJC_RUNTIME (default gnustep-1.7),
#   OBJC_LIBS (default "-lobjc -lpthread"), FOUNDATION_DIR (another checkout with include/ and src/, to check the
#   test fails there).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tree=${FOUNDATION_DIR:-$root}
prefix_flags=()
[ $# -ge 1 ] && prefix_flags=(-I"$1/include" -L"$1/lib")
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

grep -v -E '^#(include|import)' "$tree/include/Foundation/NSAppleEventManager.h" >"$temp/header.inc"
grep -v -E '^#(include|import)' "$tree/src/NSAppleEventManager.m" >"$temp/implementation.inc"
grep -q '^@implementation NSAppleEventManager' "$temp/implementation.inc" ||
    { echo "FAIL: no @implementation NSAppleEventManager in $tree/src; update $0" >&2; exit 1; }

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fno-objc-arc \
    -Wall -Wno-objc-root-class -Wno-unused-function -Wno-incomplete-implementation \
    -DHEADER_INC="\"$temp/header.inc\"" -DIMPLEMENTATION_INC="\"$temp/implementation.inc\"" \
    "${prefix_flags[@]}" "$root/tests/appleeventmanager-forward-host.m" ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/appleeventmanager-forward"
"$temp/appleeventmanager-forward"
