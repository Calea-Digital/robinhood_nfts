#!/usr/bin/env python3
"""Lint a project's OpenSpec content for the mistakes the CLI does not catch.

    python3 lint_spec.py --root <project root>

1. Every `### Requirement:` under `## ADDED Requirements` / `## MODIFIED
   Requirements` in an active change (`openspec/changes/*/specs/**/*.md`,
   archive excluded) carries a valid `**Kind:**` line and a `#### Scenario:`.
   `openspec validate` checks the Scenario but not Kind, and `openspec archive`
   copies a MODIFIED block as written — a delta without Kind silently strips it
   from the main spec, after which the bridge refuses the whole spec. A prose
   rule in config.yaml is not a gate; this is.
2. Narrative that cites a decision as open must agree with the register: a
   line beginning `**O<n> — … (CQ-n)**` in docs/SPECIFICATION.md whose decision
   is resolved or deferred is stale.
3. Decision ids never collide with requirement ids (one namespace).
4. Every decision `Blocks` id resolves to a requirement or decision.

Exit 1 on any finding.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
for candidate in (HERE, HERE.parent / "youtrack-bridge"):
    if (candidate / "spec_model.py").exists():
        sys.path.insert(0, str(candidate))
        break

from parser_openspec import DELTA_SECTION, KIND_FIELD, REQUIREMENT_HEADING, SCENARIO_HEADING, parse_openspec  # noqa: E402
from spec_model import OPEN_DECISION_STATES, VALID_KINDS  # noqa: E402

OPEN_ITEM = re.compile(r"^\*\*O\d+\s+—\s+.*?\(([A-Z]{1,6}-\d+)\)\.\*\*", re.MULTILINE)
BLOCK_END = re.compile(r"^#{1,3}\s", re.MULTILINE)


def lint_change_deltas(root: Path) -> list[str]:
    problems = []
    changes = root / "openspec" / "changes"
    if not changes.exists():
        return problems
    for path in sorted(changes.glob("*/specs/**/*.md")):
        if "archive" in path.relative_to(changes).parts[:1]:
            continue
        text = path.read_text(encoding="utf-8")
        for h in REQUIREMENT_HEADING.finditer(text):
            section = None
            for s in DELTA_SECTION.finditer(text, 0, h.start()):
                section = s.group(1)
            if section not in ("ADDED", "MODIFIED"):
                continue
            nxt = BLOCK_END.search(text, h.end())
            body = text[h.end():nxt.start() if nxt else len(text)]
            rid = f"{h.group(1)}-{h.group(2)}"
            kind = KIND_FIELD.search(body)
            where = f"{path.relative_to(root)}:{text.count(chr(10), 0, h.start()) + 1}"
            if not kind or kind.group(1) not in VALID_KINDS:
                problems.append(f"{where}: {section} {rid} has no valid **Kind:** line — archive would strip Kind from the main spec")
            if not SCENARIO_HEADING.search(body):
                problems.append(f"{where}: {section} {rid} has no #### Scenario: block")
    return problems


def lint_open_items(root: Path, parsed) -> list[str]:
    problems = []
    spec = root / "docs" / "SPECIFICATION.md"
    if not spec.exists():
        return problems
    by_id = {d.id: d for d in parsed.decisions}
    for m in OPEN_ITEM.finditer(spec.read_text(encoding="utf-8")):
        d = by_id.get(m.group(1))
        if d is None:
            problems.append(f"docs/SPECIFICATION.md: open item cites {m.group(1)}, which is not in the register")
        elif d.state not in OPEN_DECISION_STATES:
            problems.append(f"docs/SPECIFICATION.md: open item cites {d.id} as open, but the register has it {d.state} — rewrite the item")
    return problems


def lint_ids(parsed) -> list[str]:
    problems = []
    req_ids = {r.id for r in parsed.requirements}
    known = req_ids | {d.id for d in parsed.decisions}
    for d in parsed.decisions:
        if d.id in req_ids:
            problems.append(f"{d.id} is both a decision and a requirement id")
        for b in d.blocks:
            if b not in known:
                problems.append(f"{d.id} blocks {b}, which is neither a requirement nor a decision")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", type=Path, default=HERE.parents[2] if len(HERE.parents) > 2 else Path.cwd())
    args = ap.parse_args()
    root = args.root.resolve()
    openspec = root / "openspec"
    parsed = parse_openspec(openspec / "specs", openspec / "decisions.md", openspec / "config.yaml", root)
    problems = lint_change_deltas(root) + lint_open_items(root, parsed) + lint_ids(parsed)
    if problems:
        print(f"{len(problems)} lint finding(s):")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"lint OK — {sum(1 for r in parsed.requirements if r.status == 'active')} active requirement(s), {len(parsed.decisions)} decision(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
