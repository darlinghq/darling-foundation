#!/bin/bash
# Copyright (C) 2026 Lubos Dolezel
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs inside the Darling guest: an NSXPC client of one architecture talks to a service of the other one
# (default: i386 client, x86_64 service). The service is started as a launchd job that owns its Mach service name.
# Usage: nsxpc-cross-arch.sh <service-binary> <client-binary>
set -u
service=$1; client=$2
label=org.darlinghq.test.nsxpc-cross-arch
dir=$(mktemp -d "${TMPDIR:-/tmp}/xarch.XXXXXX")
plist=$dir/$label.plist
cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$label</string>
<key>ProgramArguments</key><array><string>$service</string></array>
<key>MachServices</key><dict><key>$label</key><true/></dict>
</dict></plist>
EOF
launchctl remove $label >/dev/null 2>&1
launchctl load "$plist" || { echo "FAIL: cannot load the service job"; exit 1; }
"$client"; rc=$?
launchctl remove $label >/dev/null 2>&1
exit $rc
