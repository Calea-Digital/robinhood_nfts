#!/usr/bin/env python3
"""Check that every test a branching tree names exists.

Reads every `test_…`, `testFork_…` and `testFuzz_…` name in the code repository's
`contracts/test/*.tree.md` and every test function declared in `contracts/test/**/*.sol`, prints
the count of names checked and each name no test declares, with the tree and line that cite it,
and exits 1 if there is one. A renamed or deleted test then fails here instead of leaving a tree
leaf, or RAF-19's acceptance map, pointing at nothing.

Usage (from this repository's root):
    python3 docs/tools/check_tree_tests.py [--code-root ../NFT/packages]
"""
import argparse
import glob
import os
import re
import sys

ap = argparse.ArgumentParser()
ap.add_argument("--code-root", default="../NFT/packages", help="the code repository's packages/ directory")
code = ap.parse_args().code_root
test_dir = os.path.join(code, "contracts", "test")
if not os.path.isdir(test_dir):
    sys.exit(f"no contracts/test under {code}: pass --code-root")

NAME = re.compile(r"\b(test(?:Fork|Fuzz)?_[A-Za-z0-9_]+)")

declared = set()
for path in glob.glob(os.path.join(test_dir, "**", "*.sol"), recursive=True):
    if not os.path.isfile(path):
        continue
    declared.update(re.findall(r"\bfunction\s+(test(?:Fork|Fuzz)?_[A-Za-z0-9_]+)\s*\(", open(path).read()))

named = 0
missing = []
for path in sorted(glob.glob(os.path.join(test_dir, "*.tree.md"))):
    for n, line in enumerate(open(path), 1):
        for name in NAME.findall(line):
            named += 1
            if name not in declared:
                missing.append(f"{os.path.relpath(path, code)}:{n}: {name}")

print(f"named: {named}  missing: {len(missing)}")
for m in missing:
    print(f"  {m}")
sys.exit(1 if missing else 0)
