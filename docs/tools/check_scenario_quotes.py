#!/usr/bin/env python3
"""Check that every test block carrying a requirement id quotes that requirement's Scenario.

A test whose `/* Scenario:` block opens `Scenario: <ID> — <title>` must repeat the Scenario's title
and every GIVEN / WHEN / THEN / AND line of `<ID>` in `openspec/specs/*/spec.md` (whitespace,
backticks and emphasis ignored), in the code repository's Solidity tests (`contracts/test/`) and the
client library's TypeScript tests (`contracts-client/test/` and `examples/`); every other test opens
a bare `Scenario:` (CLAUDE.md, "Test conventions"). Prints the count of quoting blocks and every
block that does not quote, and exits 1 if there is one.

Usage (from this repository's root):
    python3 docs/tools/check_scenario_quotes.py [--code-root ../NFT/packages]
"""
import argparse
import collections
import glob
import os
import re
import sys

ap = argparse.ArgumentParser()
ap.add_argument("--code-root", default="../NFT/packages", help="the code repository's packages/ directory")
code = ap.parse_args().code_root
if not os.path.isdir(os.path.join(code, "contracts", "test")):
    sys.exit(f"no contracts/test under {code}: pass --code-root")


def norm(s: str) -> str:
    return re.sub(r"[`*]", "", re.sub(r"\s+", " ", s)).strip().lower()


spec = {}
for path in glob.glob("openspec/specs/*/spec.md"):
    text = open(path).read()
    for m in re.finditer(
        r"### Requirement: (\S+) — [^\n]*\n(?:(?!### Requirement).)*?#### Scenario: ([^\n]*)\n((?:- [^\n]*\n?(?:  [^\n]*\n?)*)+)",
        text,
        re.S,
    ):
        lines = [norm(re.sub(r"^- \*\*(\w+)\*\*", r"\1", line.strip())) for line in re.split(r"\n(?=- )", m.group(3).strip())]
        spec[m.group(1)] = (m.group(2).strip(), lines)

bad = collections.defaultdict(list)
good = collections.Counter()
tests = os.path.join(code, "contracts", "test")
paths = [p for p in glob.glob(f"{tests}/**/*.sol", recursive=True) if not p.startswith(os.path.join(tests, "fixtures"))]
for sub in ("test", "examples"):  # the client library (DEL-6)
    paths += glob.glob(os.path.join(code, "contracts-client", sub, "**", "*.ts"), recursive=True)
for path in paths:
    text = open(path).read()
    for m in re.finditer(r"/\* Scenario: ([A-Z]+-\d+) — (.*?)\n(.*?)\*/", text, re.S):
        rid, line = m.group(1), text[: m.start()].count("\n") + 1
        if rid not in spec:
            bad[rid].append(f"{path}:{line} (no such requirement)")
            continue
        title, lines = spec[rid]
        body = norm(m.group(3))
        if norm(m.group(2)) == norm(title) and all(item in body for item in lines):
            good[rid] += 1
        else:
            bad[rid].append(f"{path}:{line}")

print(f"quoting: {sum(good.values())}  not quoting: {sum(len(v) for v in bad.values())}")
for rid in sorted(bad):
    print(rid, ", ".join(bad[rid]))
sys.exit(1 if bad else 0)
