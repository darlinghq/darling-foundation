#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs -[NSProcessInfo operatingSystemVersionString] and -operatingSystemVersion from src/NSProcessInfo.m on the host
# against a minimal mock root class and a mock _CFCopySystemVersionDictionary(); see processinfo-version-host.m.
# Usage: tests/processinfo-version-host.sh [OBJC_PREFIX]
#   OBJC_PREFIX holds include/objc/runtime.h and lib/libobjc for a GNUstep-ABI runtime (libobjc2); without it the
#   compiler's default search paths are used. Environment: CC (default cc), OBJC_RUNTIME (default gnustep-1.7),
#   OBJC_LIBS (default "-lobjc -lpthread"), NSPROCESSINFO_M (another copy of NSProcessInfo.m, to check the test
#   fails there).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${NSPROCESSINFO_M:-$root/src/NSProcessInfo.m}
prefix_flags=()
[ $# -ge 1 ] && prefix_flags=(-I"$1/include" -L"$1/lib")
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

for method in '(NSString *)operatingSystemVersionString' '(NSOperatingSystemVersion)operatingSystemVersion'; do
    head="- $method" awk '$0 == ENVIRON["head"] {on=1; found=1} on {print} on && /^}/ {on=0} END {exit !found}' "$src" ||
        { echo "FAIL: no -$method in $src; update $0" >&2; exit 1; }
done >"$temp/methods.inc"

# shellcheck disable=SC2086
${CC:-cc} -x objective-c -fobjc-runtime="${OBJC_RUNTIME:-gnustep-1.7}" -fno-objc-arc \
    -Wall -Wno-objc-root-class -Wno-macro-redefined -DMETHODS_INC="\"$temp/methods.inc\"" \
    "${prefix_flags[@]}" "$root/tests/processinfo-version-host.m" ${OBJC_LIBS:--lobjc -lpthread} \
    -o "$temp/processinfo-version"
"$temp/processinfo-version"
