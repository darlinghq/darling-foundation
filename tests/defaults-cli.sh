#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Lubos Dolezel
#
# Black-box test of the defaults(1) command-line tool. Runs a fixed list of
# defaults commands against a scratch domain and prints a transcript of each
# command's stdout, stderr and exit status. The same script was run against
# /usr/bin/defaults on macOS 27.0.1 to produce defaults-cli.expected; in
# Darling the transcripts must match.
#
# Usage: tests/defaults-cli.sh [expected-file]
#   Without an argument the transcript goes to stdout. With one, the
#   transcript is compared against it and the script exits 0 on a match.
#   Environment: DEFAULTS (default "defaults").
#
# Only the domain org.darlinghq.defaultstest (also its -currentHost
# variant) and files under a temporary directory are written; all are
# removed at the end.

DEFAULTS=${DEFAULTS:-defaults}
D=org.darlinghq.defaultstest
# Never written, so it does not exist.
M=org.darlinghq.defaultstest.missing
T=$(mktemp -d "${TMPDIR:-/tmp}/defaults-cli.XXXXXX") || exit 2
TR=$(cd "$T" && pwd -P)

cleanup() {
	"$DEFAULTS" delete "$D" >/dev/null 2>&1
	"$DEFAULTS" -currentHost delete "$D" >/dev/null 2>&1
	rm -rf "$T"
}

# Hide the scratch directory and $HOME from the transcript.
scrub() {
	sed -e "s#$TR#<TMP>#g" -e "s#$T#<TMP>#g" -e "s#$HOME#<HOME>#g"
}

# show ARGS...: print the command line.
show() {
	{
		printf '$ defaults'
		for a in "$@"; do printf ' [%s]' "$a"; done
	} | scrub
}

# result EXIT: print what the last command wrote and its exit status. The
# help text is replaced by a marker: the test checks when it is printed, not
# its wording. The reason after "due to" in a property list parse error is
# CoreFoundation's error description and is left out too.
result() {
	echo "--- stdout"
	if grep -q -e '-dict-add' "$T/out" && grep -q -e 'read-type' "$T/out"; then
		echo "<usage>"
	else
		scrub <"$T/out"
	fi
	echo "--- stderr"
	sed -e 's/ due to .*/ due to <reason>/' "$T/err" | scrub
	echo "--- exit $1"
}

# run ARGS...: run defaults with ARGS and record its output and exit status.
run() {
	show "$@"
	printf '\n'
	"$DEFAULTS" "$@" >"$T/out" 2>"$T/err" </dev/null
	result $?
}

# run_in FILE ARGS...: like run, with FILE on stdin.
run_in() {
	f=$1; shift
	show "$@"
	printf ' < %s\n' "$(basename "$f")"
	"$DEFAULTS" "$@" >"$T/out" 2>"$T/err" <"$f"
	result $?
}

note() {
	echo "### $*"
}

transcript() {
	"$DEFAULTS" delete "$D" >/dev/null 2>&1
	"$DEFAULTS" -currentHost delete "$D" >/dev/null 2>&1

	note "missing domain"
	run read "$M"
	run read "$M" k
	run read-type "$M" k
	run delete "$M"
	run delete "$M" k
	run rename "$M" a b
	run export "$M" -

	note "missing key"
	run write "$D" s -string x
	run read "$D" k
	run read-type "$D" k
	run delete "$D" k

	note "strings"
	run write "$D" s -string "hello world"
	run read "$D" s
	run read-type "$D" s
	run write "$D" s0 -string ""
	run read "$D" s0
	run write "$D" s1 -string word
	run write "$D" s2 -string 'quote " backslash \ end'
	run read "$D" s2
	run write "$D" s3 -string 'line1
line2'
	run read "$D" s3
	run write "$D" s4 -string 'tab	x'
	run write "$D" s5 -string 'é ü 日本'
	run read "$D" s5
	run write "$D" s6 -string 'a_b.c/d-e:f$g'
	run write "$D" s7 -string 123
	run read-type "$D" s7
	run write "$D" s8 -string -int
	run read "$D" s8
	run write "$D" s9 -string "$(printf 'bell\a bs\b ff\f vt\v')"
	run write "$D" s10 -string "$(printf '\360\237\230\200')"
	run write "$D" s11 -string 'x@y'
	run write "$D" s12 -string 1abc

	note "integers"
	run write "$D" i1 -int 42
	run read "$D" i1
	run read-type "$D" i1
	run write "$D" i2 -integer -7
	run read "$D" i2
	run write "$D" i3 -int 9223372036854775807
	run read "$D" i3
	run write "$D" i4 -int 0x10
	run read "$D" i4
	run write "$D" i5 -int 1.9
	run read "$D" i5
	run write "$D" i6 -int abc
	run read "$D" i6
	run write "$D" i7 -int " 12"
	run read "$D" i7
	run write "$D" i8 -int 99999999999999999999
	run read "$D" i8
	run write "$D" i9 -int -99999999999999999999
	run read "$D" i9
	run write "$D" i10 -int +5
	run read "$D" i10

	note "floats"
	run write "$D" f1 -float 1.5
	run read "$D" f1
	run read-type "$D" f1
	run write "$D" f2 -float -2.25
	run read "$D" f2
	run write "$D" f3 -float 3
	run read "$D" f3
	run read-type "$D" f3
	run write "$D" f4 -float 65536.5
	run read "$D" f4
	run write "$D" f5 -float " 0.375e1x"
	run read "$D" f5
	run write "$D" f6 -float 2.5e3
	run read "$D" f6
	run write "$D" f7 -float abc
	run read "$D" f7
	run write "$D" f8 -float 0x10
	run read "$D" f8

	note "booleans"
	run write "$D" b1 -bool YES
	run read "$D" b1
	run read-type "$D" b1
	run write "$D" b2 -bool NO
	run read "$D" b2
	run write "$D" b3 -boolean TRUE
	run read "$D" b3
	run write "$D" b4 -bool false
	run read "$D" b4
	run write "$D" b5 -bool 1
	run read "$D" b5
	run write "$D" b6 -bool 0
	run read "$D" b6
	run write "$D" b7 -bool yes
	run read "$D" b7
	run write "$D" b8 -bool maybe
	run read "$D" b8
	run write "$D" b9 -bool tRuE
	run read "$D" b9

	note "dates"
	run write "$D" d1 -date "2024-01-02 03:04:05 +0000"
	run read "$D" d1
	run read-type "$D" d1
	run write "$D" d2 -date "2024-01-02T03:04:05Z"
	run read "$D" d2
	run write "$D" d3 -date "1999-12-31 23:59:59 +0130"
	run read "$D" d3
	run write "$D" d4 -date garbage
	run read "$D" d4
	run write "$D" d5 -date "2024-01-02 03:04:05"
	run read "$D" d5
	run write "$D" d6 -date "2024-01-02 03:04:05 -0800"
	run read "$D" d6
	run write "$D" d7 -date "2024-01-02 03:04:05 GMT"
	run read "$D" d7
	run write "$D" d8 -date "Tue, 02 Jan 2024 03:04:05 +0000"
	run read "$D" d8
	run write "$D" d9 -date 1704164645
	run read "$D" d9

	note "data"
	run write "$D" x1 -data 0a0Bff
	run read "$D" x1
	run read-type "$D" x1
	run write "$D" x2 -data ""
	run read "$D" x2
	run write "$D" x3 -data 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f
	run read "$D" x3
	run write "$D" x4 -data zz
	run write "$D" x5 -data abc
	run read "$D" x5
	run write "$D" x6 -data "01 02"
	run write "$D" x7 -data 000102030405060708090a0b0c0d0e0f1011121314151617
	run read "$D" x7
	run write "$D" x8 -data 000102030405060708090a0b0c0d0e0f101112131415161718
	run read "$D" x8

	note "arrays"
	run write "$D" a1 -array a "b c" 1
	run read "$D" a1
	run read-type "$D" a1
	run write "$D" a1 -array-add d "(e, f)"
	run read "$D" a1
	run write "$D" a2 -array-add new
	run read "$D" a2
	run write "$D" a3 -array
	run read "$D" a3
	run write "$D" a4 -array -int 1 -bool YES -string x
	run read "$D" a4
	run write "$D" a5 -array x -array y
	run read "$D" a5
	run write "$D" a6 -array-add -int 3
	run write "$D" a6 -array-add -bool NO
	run read "$D" a6
	run write "$D" s1 -array-add z
	run read "$D" s1

	note "dictionaries"
	run write "$D" c1 -dict k1 v1 "k 2" "v 2"
	run read "$D" c1
	run read-type "$D" c1
	run write "$D" c1 -dict-add k3 v3 k1 replaced
	run read "$D" c1
	run write "$D" c2 -dict-add only one
	run read "$D" c2
	run write "$D" c3 -dict odd
	run read "$D" c3
	run write "$D" c4 -dict
	run read "$D" c4
	run write "$D" c5 -dict n "{ x = (1, 2); }" -int 3
	run read "$D" c5
	run write "$D" c6 -dict k1 -int 5 k2 -bool YES k3 '(a)' -string k4 v
	run read "$D" c6
	run write "$D" c7 -dict k -dict a b
	run write "$D" s1 -dict-add z y
	run read "$D" s1

	note "plain values"
	run write "$D" p1 123
	run read-type "$D" p1
	run write "$D" p2 '(a, "b c")'
	run read "$D" p2
	run read-type "$D" p2
	run write "$D" p3 '{x = y; n = (1,2); "q r" = <0102>;}'
	run read "$D" p3
	run write "$D" p4 '<0102>'
	run read-type "$D" p4
	run write "$D" p5 'hello world'
	run read "$D" p5
	run write "$D" p6 '"quoted"'
	run read "$D" p6
	run write "$D" p7 '(unterminated'
	run read "$D" p7
	run read-type "$D" p7
	run write "$D" p8 ''
	run read-type "$D" p8
	run write "$D" p9 '()'
	run read-type "$D" p9
	run write "$D" p10 'a = b;'
	run read "$D" p10
	run write "$D" p11 '/* c */ x'
	run read "$D" p11
	run write "$D" p12 'x)'
	run write "$D" p13 '(a) b'
	run write "$D" p14 '"a\nb"'
	run read "$D" p14
	run write "$D" p15 '"\U00e9"'
	run read "$D" p15
	run write "$D" p16 "it's"
	run read "$D" p16
	run write "$D" p17 '[a]'
	run write "$D" p18 ' (a,)'
	run read "$D" p18

	note "argument errors"
	run write "$D" k
	run write "$D" k -int
	run write "$D" k -string
	run write "$D" k -string a b
	run write "$D" k -nosuchtype 1
	run read "$D" k extra
	run read-type "$D"
	run rename "$D" onlyone
	run import "$D"
	run export "$D"
	run find
	run frobnicate
	run -bogus read "$D"
	run write "$D"

	note "whole domain"
	run read "$D"

	note "rename and delete"
	run rename "$D" s sNew
	run read "$D" sNew
	run read "$D" s
	run rename "$D" nokey other
	run rename "$D" s1 i1
	run read "$D" i1
	run delete "$D" sNew
	run read "$D" sNew
	run delete "$D" sNew

	note "export and import"
	"$DEFAULTS" delete "$D" >/dev/null 2>&1
	run write "$D" i -int 1
	run write "$D" s -string "x y"
	run write "$D" a -array a b
	run write "$D" d -date "2024-01-02 03:04:05 +0000"
	run write "$D" r -float 2.5
	run write "$D" r32 -float 0.1
	run write "$D" t -bool YES
	run write "$D" z -data 00ff
	run export "$D" -
	run export "$D" "$T/exp.plist"
	echo "exported header: $(head -c 8 "$T/exp.plist")"
	run delete "$D"
	run read "$D"
	run read "$D" i
	run import "$D" "$T/exp.plist"
	run read "$D" i
	run read "$D" d
	cat >"$T/in.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>fromstdin</key>
	<integer>7</integer>
</dict>
</plist>
EOF
	run_in "$T/in.plist" import "$D" -
	run read "$D" fromstdin
	run read "$D" s
	printf '{ oldstyle = (1, 2); }' >"$T/old.plist"
	run import "$D" "$T/old.plist"
	run read "$D" oldstyle
	run import "$D" "$T/nosuchfile.plist"
	printf 'not a plist' >"$T/bad.plist"
	run import "$D" "$T/bad.plist"

	note "real numbers"
	cat >"$T/reals.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>r1</key>
	<real>0.1</real>
	<key>r2</key>
	<real>0.3333333333333333</real>
	<key>r3</key>
	<real>3.14159265358979</real>
	<key>r4</key>
	<real>1e100</real>
	<key>r5</key>
	<real>123456789012345678</real>
	<key>r6</key>
	<real>1.5e-07</real>
	<key>r7</key>
	<real>-0.0</real>
	<key>r8</key>
	<real>2</real>
	<key>n1</key>
	<integer>-5</integer>
	<key>n2</key>
	<integer>-9223372036854775808</integer>
	<key>b</key>
	<false/>
	<key>e</key>
	<array/>
	<key>nest</key>
	<dict>
		<key>d</key>
		<dict>
			<key>e</key>
			<array>
				<dict/>
				<data>AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGA==</data>
			</array>
		</dict>
	</dict>
</dict>
</plist>
EOF
	run write "$D" '{ placeholder = 1; }'
	run import "$D" "$T/reals.plist"
	run delete "$D" placeholder
	run read "$D"
	run read "$D" r2
	run read "$D" r5
	run read "$D" r7
	run read "$D" n2
	run read "$D" nest
	run read-type "$D" b

	note "write whole domain"
	run write "$D" '{ a = 1; b = (x, y); c = { d = e; }; }'
	run read "$D"
	run write "$D" '(not, a, dict)'
	run read "$D"

	note "key order"
	run write "$D" '{ B = 1; a = 1; "_x" = 1; Z = 1; 10 = 1; 9 = 1; "\U00e9" = 1; f = 1; dg = 1; }'
	run read "$D"

	note "find"
	run write "$D" dqzxtokenkey -string plain
	run write "$D" other -string "has DQZXtoken inside"
	run write "$D" nested -dict inner dqzxtoken
	run write "$D" num -int 4242
	run find dqzxtoken
	run find dqzxnomatchtoken
	run find 4242
	run find org.darlinghq.defaultstest

	note "domains"
	"$DEFAULTS" domains >"$T/out" 2>"$T/err"
	echo "domains exit $?"
	echo "domains lists test domain: $(tr ',' '\n' <"$T/out" | sed 's/^ *//' | grep -c "^$D\$")"
	echo "domains output lines: $(wc -l <"$T/out" | tr -d ' ')"
	echo "domains stderr bytes: $(wc -c <"$T/err" | tr -d ' ')"

	note "global domain"
	run read -g org.darlinghq.nokey
	run read NSGlobalDomain org.darlinghq.nokey
	run read -globalDomain org.darlinghq.nokey
	run read-type -g org.darlinghq.nokey

	note "app"
	run read -app DarlingNoSuchApplication k
	run read -app

	note "currentHost"
	run -currentHost write "$D" hk -int 1
	run -currentHost read "$D" hk
	run read "$D" hk
	run -currentHost read-type "$D" hk
	run -currentHost write "$D" hk2 -int 2
	run -currentHost delete "$D" hk
	run -currentHost read "$D" hk
	run -currentHost read "$D"

	note "path domains"
	run write "$T/pdom" k v
	run read "$T/pdom"
	run read "$T/pdom.plist"
	run read "$T/pdom.plist" k
	run read-type "$T/pdom" k
	echo "files: $(ls "$T" | grep pdom)"
	run write "$T/pdom.plist" k2 -int 2
	run read "$T/pdom"
	echo "files: $(ls "$T" | grep pdom)"
	run read "$T/missing"
	run delete "$T/pdom" k
	run read "$T/pdom"
	run delete "$T/pdom"
	echo "files: $(ls "$T" | grep pdom)"
	run read "$T/pdom"
	run write "$T/pdom" k3 -int 3
	run read "$T/pdom"

	note "help"
	run help
	run

	run delete "$D"
}

if [ $# -ge 1 ]; then
	transcript >"$T/transcript" 2>&1
	if diff -u "$1" "$T/transcript"; then
		echo "PASS: defaults-cli"
		cleanup
		exit 0
	fi
	cp "$T/transcript" "${TMPDIR:-/tmp}/defaults-cli.actual"
	echo "FAIL: defaults-cli (transcript in ${TMPDIR:-/tmp}/defaults-cli.actual)"
	cleanup
	exit 1
fi
transcript
cleanup
