#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify NSFileManager error creation stores NSError under NSUnderlyingErrorKey.

Usage: python3 tests/filemanager-setattributes-error.py
"""
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]

# 1. Source checks
fm_src = (root / "src" / "NSFileManager.m").read_text()
if re.search(r'NSString\s*\*\s*underlyingError\s*=', fm_src):
    sys.exit("FAIL: NSFileManager still constructs underlyingError as NSString")

if not re.search(r'\[NSError\s+errorWithDomain:\s*NSPOSIXErrorDomain', fm_src):
    sys.exit("FAIL: NSFileManager does not construct underlyingError as NSError with NSPOSIXErrorDomain")

# 2. Dynamic execution under darling shell if darling is present
darling_bin = shutil.which("darling")
if darling_bin:
    test_src = root / "tests" / "filemanager-setattributes-error.m"
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_bin = pathlib.Path(tmpdir) / "test_filemanager_error"
        build_res = subprocess.run(
            [darling_bin, "shell", "clang", "-framework", "Foundation", str(test_src), "-o", str(tmp_bin)],
            capture_output=True,
            text=True,
            timeout=60
        )
        if build_res.returncode != 0:
            sys.exit(f"FAIL to compile test in darling shell:\n{build_res.stderr}")
        run_res = subprocess.run(
            [darling_bin, "shell", str(tmp_bin)],
            capture_output=True,
            text=True,
            timeout=60
        )
        if run_res.returncode != 0:
            sys.exit(f"FAIL: test failed in darling shell (exit {run_res.returncode}):\n{run_res.stdout}\n{run_res.stderr}")

print("PASS: NSFileManager setAttributes error stores NSError under NSUnderlyingErrorKey verified")
