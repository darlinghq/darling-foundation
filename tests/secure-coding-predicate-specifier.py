#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify NSSecureCoding conformance and class methods in Foundation.

Usage: python3 tests/secure-coding-predicate-specifier.py
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]

# 1. Source checks
pred_header = (root / "include" / "Foundation" / "NSPredicate.h").read_text()
if not re.search(r"@interface\s+NSPredicate\s*:\s*NSObject\s*<[^>]*NSSecureCoding[^>]*>", pred_header):
    sys.exit("FAIL: NSPredicate does not declare conformance to NSSecureCoding")

block_src = (root / "src" / "NSBlockPredicate.m").read_text()
if re.search(r"-\s*\(\s*BOOL\s*\)\s*supportsSecureCoding", block_src):
    sys.exit("FAIL: NSBlockPredicate still implements -supportsSecureCoding as an instance method")
if not re.search(r"\+\s*\(\s*BOOL\s*\)\s*supportsSecureCoding", block_src):
    sys.exit("FAIL: NSBlockPredicate does not implement +supportsSecureCoding class method")

spec_header = (root / "include" / "Foundation" / "NSScriptObjectSpecifiers.h").read_text()
if not re.search(r"@interface\s+NSScriptObjectSpecifier\s*:\s*NSObject\s*<[^>]*NSSecureCoding[^>]*>", spec_header):
    sys.exit("FAIL: NSScriptObjectSpecifier does not declare conformance to NSSecureCoding")

spec_src = (root / "src" / "NSScriptObjectSpecifiers.m").read_text()
if re.search(r"-\s*\(\s*BOOL\s*\)\s*supportsSecureCoding", spec_src):
    sys.exit("FAIL: NSScriptObjectSpecifier still implements -supportsSecureCoding as an instance method")
if not re.search(r"\+\s*\(\s*BOOL\s*\)\s*supportsSecureCoding", spec_src):
    sys.exit("FAIL: NSScriptObjectSpecifier does not implement +supportsSecureCoding class method")

# 2. Dynamic execution under darling shell if darling is present
darling_bin = shutil.which("darling")
if darling_bin:
    test_src = root / "tests" / "secure-coding-predicate-specifier.m"
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_bin = pathlib.Path(tmpdir) / "test_secure_coding"
        build_res = subprocess.run(
            [darling_bin, "shell", "clang", "-framework", "Foundation", str(test_src), "-o", str(tmp_bin)],
            capture_output=True,
            text=True
        )
        if build_res.returncode != 0:
            sys.exit(f"FAIL to compile test in darling shell:\n{build_res.stderr}")
        run_res = subprocess.run(
            [darling_bin, "shell", str(tmp_bin)],
            capture_output=True,
            text=True
        )
        if run_res.returncode != 0:
            sys.exit(f"FAIL: test failed in darling shell (exit {run_res.returncode}):\n{run_res.stdout}\n{run_res.stderr}")

print("PASS: supportsSecureCoding class methods and NSSecureCoding conformance verified")
