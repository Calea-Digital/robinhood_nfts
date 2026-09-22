#!/usr/bin/env python3
"""Render a project's native spec (`openspec/`) into the Calea prose view.

The prose documents (`docs/SPECIFICATION.md`, `docs/OPEN-QUESTIONS.md`) keep
their narrative — scope, system overview, calendar, decisions of a call,
sign-off — and carry marker pairs where generated content goes:

    <!-- openspec:begin family COL -->   the family's Purpose, then every active
                                          requirement as `**COL-3 Name.** statement`
                                          plus, for a work-item, `*Acceptance.* …`
    <!-- openspec:begin retired -->      the `**Retired identifiers.**` paragraph
    <!-- openspec:begin version -->      the block is kept; `Version X` tokens read
                                          config.yaml's spec_version
    <!-- openspec:begin register -->     the decisions table
    <!-- openspec:begin questions -->    one `### CQ-n — Title` section per decision
    <!-- openspec:end -->

Only the text between markers is rewritten; the narrative is edited where it
lives. `--check` renders in memory and exits 1 when a file would change (the
CI gate); `--write` rewrites. The client-document builder consumes the result
unchanged — the generated blocks are exactly the prose shape it already reads.

Installed into a project as `docs/tools/spec_tools/render_calea_prose.py`
beside copies of `spec_model.py` and `parser_openspec.py` (see install.sh), so
the project's own CI can run the gate without this repository.
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

from parser_openspec import parse_openspec  # noqa: E402
from spec_model import KIND_WORK_ITEM, ParsedSpec, read_config_value  # noqa: E402

MARKER = re.compile(
    r"^(?P<indent>[ \t]*)<!-- openspec:begin (?P<what>[^>]+?) -->[ \t]*\n(?P<body>.*?)^[ \t]*<!-- openspec:end -->[ \t]*$",
    re.MULTILINE | re.DOTALL,
)
VERSION_TOKEN = re.compile(r"(\*\*Version\*\*\s+|\bVersion\s+)(\d+\.\d+[\w.-]*)")
GENERATED_NOTICE = (
    "<!-- GENERATED sections between openspec markers are written by docs/tools/spec_tools/render_calea_prose.py "
    "from openspec/. Edit openspec/ and the narrative here, then run docs/tools/board.sh. -->"
)


def render_family(parsed: ParsedSpec, family: str) -> str:
    parts: list[str] = []
    intro = parsed.family_intros.get(family)
    if intro and not intro.startswith("TODO"):
        parts.append(intro.strip())
    for r in parsed.requirements:
        if r.family != family or r.status != "active":
            continue
        block = f"**{r.id} {r.name}.** {r.statement.strip()}"
        if r.kind == KIND_WORK_ITEM and r.scenarios:
            # A migration stub (`#### Scenario: TODO`) is not acceptance text yet.
            sentences = " ".join(s.as_sentence() for s in r.scenarios if s.as_sentence() and s.name != "TODO")
            if sentences:
                block += f"\n\n*Acceptance.* {sentences}"
        parts.append(block)
    return "\n\n".join(parts)


def render_retired(parsed: ParsedSpec) -> str:
    retired = [r for r in parsed.requirements if r.status == "retired"]
    if not retired:
        return ""
    clauses = [f"{r.id} ({r.retired_reason}) → {' and '.join(r.retired_pointer) if len(r.retired_pointer) <= 2 else ', '.join(r.retired_pointer)}" for r in retired]
    return "**Retired identifiers.** " + "; ".join(clauses) + "."


def render_version(parsed: ParsedSpec, body: str) -> str:
    if not parsed.version:
        return body.strip("\n")
    return VERSION_TOKEN.sub(lambda m: f"{m.group(1)}{parsed.version}", body).strip("\n")


def cell(text: str | None) -> str:
    return (text or "—").replace("|", "\\|").replace("\n", " ").strip()


def render_register(parsed: ParsedSpec) -> str:
    rows = ["| ID | Section | Question | Resolution / default | Needed by | Status |", "|---|---|---|---|---|---|"]
    for d in parsed.decisions:
        rows.append(f"| {d.id} | {cell(d.section)} | {cell(d.statement)} | {cell(d.resolution or d.default_if_deferred)} | {cell(d.needed_by)} | {d.label} |")
    return "\n".join(rows)


def render_questions(parsed: ParsedSpec) -> str:
    sections: list[str] = []
    for d in parsed.decisions:
        lines = [f"### {d.id} — {d.heading_title}"]
        if d.section:
            lines.append(f"- **Section:** {d.section}")
        lines.append(f"- **Needed by:** {d.needed_by or '—'}")
        lines.append(f"- **Status:** {d.label_with_note}")
        if d.resolution:
            lines.append(f"- **Resolution:** {d.resolution}")
        if d.default_if_deferred and not d.resolution:
            lines.append(f"- **Default if unanswered:** {d.default_if_deferred}")
        if d.detail:
            lines += ["", d.detail.strip()]
        sections.append("\n".join(lines))
    return "\n\n".join(sections)


def render_block(parsed: ParsedSpec, what: str, body: str) -> str:
    kind, _, arg = what.strip().partition(" ")
    if kind == "family":
        return render_family(parsed, arg.strip())
    if kind == "retired":
        return render_retired(parsed)
    if kind == "version":
        return render_version(parsed, body)
    if kind == "register":
        return render_register(parsed)
    if kind == "questions":
        return render_questions(parsed)
    raise SystemExit(f"unknown marker: openspec:begin {what}")


def render_document(parsed: ParsedSpec, text: str) -> str:
    def sub(m: re.Match) -> str:
        rendered = render_block(parsed, m.group("what"), m.group("body"))
        return f"<!-- openspec:begin {m.group('what')} -->\n{rendered}\n<!-- openspec:end -->"

    out = MARKER.sub(sub, text)
    if GENERATED_NOTICE not in out and "<!-- openspec:begin" in out:
        out = GENERATED_NOTICE + "\n" + out
    return out


def documents_with_markers(root: Path) -> list[Path]:
    return sorted(p for p in (root / "docs").glob("*.md") if "<!-- openspec:begin" in p.read_text(encoding="utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", type=Path, default=HERE.parents[2] if len(HERE.parents) > 2 else Path.cwd(),
                    help="Project root holding openspec/ and docs/ (default: two levels above docs/tools/)")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check", action="store_true", help="Exit 1 if any generated block is out of date")
    mode.add_argument("--write", action="store_true", help="Rewrite the generated blocks in place")
    args = ap.parse_args()

    root = args.root.resolve()
    openspec = root / "openspec"
    parsed = parse_openspec(openspec / "specs", openspec / "decisions.md", openspec / "config.yaml", root)
    if parsed.version is None:
        parsed.version = read_config_value(openspec / "config.yaml", "spec_version")

    stale = 0
    for doc in documents_with_markers(root):
        current = doc.read_text(encoding="utf-8")
        rendered = render_document(parsed, current)
        if rendered == current:
            print(f"current  {doc.relative_to(root)}")
            continue
        stale += 1
        if args.write:
            doc.write_text(rendered, encoding="utf-8")
            print(f"rendered {doc.relative_to(root)}")
        else:
            print(f"STALE    {doc.relative_to(root)} — generated blocks differ from openspec/:")
            diff = difflib.unified_diff(current.splitlines(), rendered.splitlines(), lineterm="", n=1)
            for i, line in enumerate(diff):
                if i > 40:
                    print("   …")
                    break
                print("   " + line)
    if args.check and stale:
        print(f"\n{stale} document(s) stale — run render_calea_prose.py --write and commit.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
