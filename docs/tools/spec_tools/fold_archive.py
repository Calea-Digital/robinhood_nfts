#!/usr/bin/env python3
"""Fold an archived change into the two files `openspec archive` leaves alone.

    python3 fold_archive.py --root <project root> [<change dir>] [--write]

`openspec archive` merges a change's specs delta and nothing else, so two hand
steps follow every archive (schema.yaml, `decisions` and `specs`):

1. Every `### <ID>` block under a `## … Decisions` heading of the change's
   `decisions.md` goes into `openspec/decisions.md`: a block whose id the
   register already carries replaces that block whole; a new id is appended.
2. Every `### Requirement: <ID> — <Name>` under `## REMOVED Requirements` in the
   change's spec deltas becomes a clause in its family's main spec under
   `## Retired Requirements` (created if missing):
   `- <ID> (<name>) → <ids named in **Migration:**>`.
   A REMOVED block whose Migration names no requirement id cannot be written in
   the clause form the parser accepts, so it is reported and left to a human.

`<change dir>` defaults to the newest directory under `openspec/changes/archive/`; when
several share the newest date, it refuses and lists them, since their names do not say which
was archived last.
Dry run by default: prints what it would do, as a diff — read it, because
replaying an old archive over a register that has moved on since would revert
the newer record (REPLACED). `--write` applies, then re-parses the
whole spec through the bridge parser so a malformed result fails here rather than
on the board. Re-running is harmless: an identical block or an existing clause is
reported as current.
"""
from __future__ import annotations

import argparse
import difflib
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
for candidate in (HERE, HERE.parent / "youtrack-bridge"):
    if (candidate / "spec_model.py").exists():
        sys.path.insert(0, str(candidate))
        break

from parser_openspec import (  # noqa: E402
    BLOCK_END, DECISION_HEADING, REMOVED_MIGRATION, REQ_ID_TOKEN, REQUIREMENT_HEADING,
    RETIRED_CLAUSE, RETIRED_SECTION_TITLE, parse_openspec,
)
from spec_model import SpecParseError  # noqa: E402

DECISIONS_H2 = re.compile(r"^##[ \t]+.*\bDecisions\b.*$", re.MULTILINE)
REMOVED_H2 = re.compile(r"^##[ \t]+REMOVED Requirements[ \t]*$", re.MULTILINE)
ANY_H2 = re.compile(r"^##[ \t]", re.MULTILINE)


def _h2_span(text: str, start: int) -> int:
    nxt = ANY_H2.search(text, start)
    return nxt.start() if nxt else len(text)


def decision_blocks(text: str) -> dict[str, str]:
    """`{id: block}` for every `### ID` block inside a `## … Decisions` section."""
    blocks: dict[str, str] = {}
    for sec in DECISIONS_H2.finditer(text):
        end_of_section = _h2_span(text, sec.end())
        for h in DECISION_HEADING.finditer(text, sec.end(), end_of_section):
            nxt = BLOCK_END.search(text, h.end())
            end = min(nxt.start() if nxt else len(text), end_of_section)
            blocks[h.group(1)] = text[h.start():end].rstrip() + "\n"
    return blocks


def fold_decisions(register: str, delta: str) -> tuple[str, list[str]]:
    report: list[str] = []
    for did, block in decision_blocks(delta).items():
        existing = decision_blocks(register).get(did)
        if existing is None:
            register = register.rstrip() + "\n\n" + block
            report.append(f"ADDED     {did}")
        elif existing.strip() == block.strip():
            report.append(f"CURRENT   {did}")
        else:
            register = register.replace(existing.rstrip(), block.rstrip(), 1)
            report.append(f"REPLACED  {did}")
    return register, report


def removed_requirements(delta: str) -> list[tuple[str, str, list[str]]]:
    """`(id, name, pointer ids)` for every block under `## REMOVED Requirements`."""
    out = []
    for sec in REMOVED_H2.finditer(delta):
        end_of_section = _h2_span(delta, sec.end())
        for h in REQUIREMENT_HEADING.finditer(delta, sec.end(), end_of_section):
            nxt = BLOCK_END.search(delta, h.end())
            body = delta[h.end():min(nxt.start() if nxt else len(delta), end_of_section)]
            rid = REQ_ID_TOKEN.search(h.group(0)).group(0)
            name = re.sub(r"^.*?—\s*", "", h.group(0).split(":", 1)[1].strip()).replace("(", "").replace(")", "")
            mig = REMOVED_MIGRATION.search(body)
            pointers = REQ_ID_TOKEN.findall(mig.group(1)) if mig else []
            out.append((rid, name.strip(), [p for p in pointers if p != rid]))
    return out


def fold_retired(spec: str, removed: list[tuple[str, str, list[str]]]) -> tuple[str, list[str]]:
    report: list[str] = []
    present = {m.group(1) for m in RETIRED_CLAUSE.finditer(spec)}
    heading = f"## {RETIRED_SECTION_TITLE}"
    for rid, name, pointers in removed:
        if rid in present:
            report.append(f"CURRENT   {rid} already retired")
            continue
        if not pointers:
            report.append(f"MANUAL    {rid}: its Migration names no requirement id — write the clause by hand")
            continue
        clause = f"- {rid} ({name}) → {', '.join(pointers)}"
        if heading not in spec:
            spec = spec.rstrip() + f"\n\n{heading}\n\n{clause}\n"
        else:
            start = spec.index(heading) + len(heading)
            end = _h2_span(spec, start)
            section = spec[start:end].rstrip()
            rest = spec[end:]
            spec = spec[:start] + section + ("\n" if section.strip() else "\n\n") + clause + "\n" + ("\n" + rest if rest else "")
        present.add(rid)
        report.append(f"RETIRED   {clause[2:]}")
    return spec, report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", type=Path, default=HERE.parents[2] if len(HERE.parents) > 2 else Path.cwd())
    ap.add_argument("change", type=Path, nargs="?", help="the change directory (default: newest under openspec/changes/archive/)")
    ap.add_argument("--write", action="store_true", help="apply (default: dry run)")
    args = ap.parse_args()
    openspec = args.root.resolve() / "openspec"
    change = args.change
    if change is None:
        archived = sorted(p for p in (openspec / "changes" / "archive").glob("*") if p.is_dir())
        if not archived:
            print("no archived change found", file=sys.stderr)
            return 2
        # Archive names are `<YYYY-MM-DD>-<change>`: the date orders days, but two changes
        # archived the same day sort by name, not by when they were archived. Guessing would
        # fold the wrong change, so a tie on the newest date has to be named.
        newest_day = archived[-1].name[:10]
        same_day = [p for p in archived if p.name[:10] == newest_day]
        if len(same_day) > 1:
            print(f"several changes were archived on {newest_day}; name the one to fold:", file=sys.stderr)
            for p in same_day:
                print(f"  {p.relative_to(openspec.parent)}", file=sys.stderr)
            return 2
        change = archived[-1]
    change = change.resolve()
    print(f"change: {change.relative_to(openspec.parent) if change.is_relative_to(openspec.parent) else change}")

    writes: dict[Path, str] = {}
    report: list[str] = []

    delta = change / "decisions.md"
    register_path = openspec / "decisions.md"
    if delta.exists():
        register = register_path.read_text(encoding="utf-8") if register_path.exists() else "# Decisions\n"
        folded, r = fold_decisions(register, delta.read_text(encoding="utf-8"))
        report += r or ["decisions.md delta carries no ### <ID> block — nothing to fold"]
        if folded != register:
            writes[register_path] = folded
    else:
        report.append("no decisions.md delta")

    for spec_delta in sorted((change / "specs").rglob("spec.md")) if (change / "specs").exists() else []:
        removed = removed_requirements(spec_delta.read_text(encoding="utf-8"))
        if not removed:
            continue
        main_spec = openspec / "specs" / spec_delta.relative_to(change / "specs")
        if not main_spec.exists():
            report.append(f"MANUAL    {main_spec}: main spec missing for REMOVED {', '.join(r[0] for r in removed)}")
            continue
        text = writes.get(main_spec, main_spec.read_text(encoding="utf-8"))
        folded, r = fold_retired(text, removed)
        report += r
        if folded != text:
            writes[main_spec] = folded

    for line in report:
        print(f"  {line}")
    manual = any(line.startswith("MANUAL") for line in report)
    if not writes:
        print("nothing to write")
        return 1 if manual else 0
    if not args.write:
        for p, text in writes.items():
            old = p.read_text(encoding="utf-8").splitlines(keepends=True) if p.exists() else []
            rel = str(p.relative_to(openspec.parent))
            sys.stdout.writelines(difflib.unified_diff(old, text.splitlines(keepends=True), rel, rel + " (folded)"))
        print(f"dry run — would write {', '.join(str(p.relative_to(openspec.parent)) for p in writes)}; re-run with --write")
        return 1 if manual else 0
    originals = {p: (p.read_text(encoding="utf-8") if p.exists() else None) for p in writes}
    for p, text in writes.items():
        p.write_text(text, encoding="utf-8")
    try:
        parse_openspec(openspec / "specs", register_path, openspec / "config.yaml", openspec.parent)
    except SpecParseError as e:
        for p, text in originals.items():
            if text is None:
                p.unlink()
            else:
                p.write_text(text, encoding="utf-8")
        print(f"REFUSED: the folded spec does not parse, nothing written — {e}", file=sys.stderr)
        return 2
    print(f"wrote {', '.join(str(p.relative_to(openspec.parent)) for p in writes)}; the spec parses")
    return 1 if manual else 0


if __name__ == "__main__":
    sys.exit(main())
