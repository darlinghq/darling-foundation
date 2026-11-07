#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs the body of -[NSProcessInfo physicalMemory] from src/NSProcessInfo.m on the host against a sysctlbyname()
# that answers like Darling's libsystem_kernel emulation (xnu darling/.../sysctl_hw.c): hw.memsize is a 64-bit byte
# count and hw.physmem does not exist. The method must report the hw.memsize value, also above 4 GiB.
# Usage: tests/processinfo-physical-memory.sh
#   Environment: CC (default cc), NSPROCESSINFO_M (another copy of NSProcessInfo.m, to check the test fails there).
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
src=${NSPROCESSINFO_M:-$root/src/NSProcessInfo.m}
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT

awk '/^- \(unsigned long long\)physicalMemory$/ {on=1; found=1; next} on {print} on && /^}/ {on=0} END {exit !found}' \
    "$src" >"$temp/body.inc" ||
    { echo "FAIL: no -physicalMemory in $src; update $0" >&2; exit 1; }

cat >"$temp/test.c" <<'EOF'
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static uint64_t memsize;
static int sysctlbyname(const char *name, void *old, size_t *oldlen, void *new, size_t newlen)
{
    (void)new; (void)newlen;
    if (strcmp(name, "hw.memsize") == 0 && *oldlen >= sizeof(uint64_t)) {
        memcpy(old, &memsize, sizeof(memsize));
        *oldlen = sizeof(memsize);
        return 0;
    }
    errno = ENOENT;
    return -1;
}

static unsigned long long physicalMemory(void)
#include "body.inc"

int main(void)
{
    static const uint64_t sizes[] = { 2ULL << 30, 16ULL << 30, 96ULL << 30 };
    int fails = 0;
    for (unsigned i = 0; i < sizeof(sizes) / sizeof(sizes[0]); i++) {
        memsize = sizes[i];
        unsigned long long got = physicalMemory();
        if (got != memsize) {
            printf("FAIL: hw.memsize %llu, physicalMemory returned %llu\n", (unsigned long long)memsize, got);
            fails++;
        }
    }
    printf("%s: %u checks, %d failed\n", fails ? "FAIL" : "PASS", (unsigned)(sizeof(sizes) / sizeof(sizes[0])), fails);
    return fails != 0;
}
EOF
${CC:-cc} -std=c11 -Wall -Werror -I"$temp" "$temp/test.c" -o "$temp/physical-memory"
"$temp/physical-memory"
