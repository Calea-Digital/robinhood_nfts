"""Parser for the calea-house OpenSpec schema's native format.

Reads a project's main specs (`openspec/specs/**/spec.md`) and its persistent
decision register (`openspec/decisions.md`). The same code reads a change's
delta files, since a delta uses the same headings under ADDED / MODIFIED /
REMOVED sections.

Main-spec shape (validated against the real OpenSpec CLI, Session 6):

    # <Title> Specification
    ## Purpose
    <prose — the family's lead-in; the Milestone's body>
    ## Requirements
    ### Requirement: COL-3 — Transfer counter
    **Kind:** work-item
    <statement>
    #### Scenario: <name>
    - **GIVEN** …   - **WHEN** …   - **THEN** …   - **AND** …
    ## Retired Requirements
    - RAF-1 (a single raffle chain) → RAF-24, RAF-26

Register shape:

    ### CQ-2 — <optional longer title>
    - **Statement:** <short text>
    - **State:** open | follow-up | resolved | deferred
    - **Status label:** Closed          (optional — overrides the state's default word)
    - **Status note:** call, 21 Sep 2026 (optional — provenance)
    - **Section:** ACT                   (optional)
    - **Needed by:** 2026-10-20 — before … (optional; a leading ISO date projects as Due Date)
    - **Resolution:** …                  (optional)
    - **Rationale:** …                   (optional)
    - **Blocks:** ACT-7, ACT-2           (optional)
    - **Default if deferred:** …         (optional)

    <detail — everything after the first blank line, verbatim>

Fields are read only from the contiguous bullet block right after the
heading, so a `- **Needed by:**` bullet inside the detail prose is prose.
The decision id prefix is whatever the project uses (`D` by default; a
project keeps the prefix its history already carries, e.g. `CQ`) — the rule
is one namespace for life, not the letter.
"""
from __future__ import annotations

import re
from pathlib import Path

from spec_model import (
    DECISION_STATES,
    Decision,
    ParsedSpec,
    Requirement,
    Scenario,
    SpecParseError,
    VALID_KINDS,
    read_config_value,
)

# Horizontal whitespace only ([ \t]) inside a heading: `\s` would cross the
# newline and let an optional title swallow the first bullet of the body.
REQUIREMENT_HEADING = re.compile(
    r"^###[ \t]+Requirement:[ \t]*([A-Z]{2,6})-(\d+)[ \t]*(?:—|-)[ \t]*(.+?)[ \t]*$", re.MULTILINE
)
# A requirement's body ends at the next heading of level 1–3 (the next
# requirement, the next section, the next file's title) — never at a `####`
# scenario heading, which belongs to the requirement.
BLOCK_END = re.compile(r"^#{1,3}\s", re.MULTILINE)
SCENARIO_HEADING = re.compile(r"^####[ \t]+Scenario:[ \t]*(.*?)[ \t]*$", re.MULTILINE)
SCENARIO_STEP = re.compile(r"^-\s+\*\*(GIVEN|WHEN|THEN|AND|BUT)\*\*:?\s*(.*?)\s*$", re.IGNORECASE)
DELTA_SECTION = re.compile(r"^##\s+(ADDED|MODIFIED|REMOVED|RENAMED) Requirements", re.MULTILINE)
REMOVED_REASON = re.compile(r"\*\*Reason:\*\*\s*(.+)")
REMOVED_MIGRATION = re.compile(r"\*\*Migration:\*\*\s*(.+)")
KIND_FIELD = re.compile(r"^\*\*Kind:\*\*\s*(\S+)\s*$", re.MULTILINE)
REQ_ID_TOKEN = re.compile(r"\b[A-Z]{1,6}-\d+\b")
# `(→ CQ-18)` inside a statement: the spec's own pointer from a requirement to
# the decision it waits on. Any prefix is captured here; parse_openspec keeps
# only the ones that are decision ids, so a pointer at a requirement is not a
# gate.
POINTER = re.compile(r"(?:→|->)\s*([A-Z]{1,6}-\d+)")

H1 = re.compile(r"^#[ \t]+(.+?)[ \t]*$", re.MULTILINE)
SECTION_H2 = re.compile(r"^##[ \t]+(.+?)[ \t]*$", re.MULTILINE)
RETIRED_SECTION_TITLE = "Retired Requirements"
PURPOSE_TITLE = "Purpose"
# `- RAF-1 (a single raffle chain) → RAF-24, RAF-26` — the same clause grammar
# the legacy `**Retired identifiers.**` paragraph uses, so a rendered prose
# view round-trips through the legacy parser unchanged.
RETIRED_CLAUSE = re.compile(r"([A-Z]{2,6}-\d+)\s*\(([^)]*)\)\s*(?:→|->)\s*([^;\n]+)")

DECISION_HEADING = re.compile(r"^###[ \t]+([A-Z]{1,6}-\d+)(?:[ \t]+(?:—|-)[ \t]+(.+?))?[ \t]*$", re.MULTILINE)
FIELD_LINE = re.compile(r"^-\s+\*\*([A-Za-z][A-Za-z ]*?):\*\*\s*(.*?)\s*$")


def _line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def _delta_section_for_offset(text: str, offset: int) -> str | None:
    section = None
    for m in DELTA_SECTION.finditer(text, 0, offset):
        section = m.group(1)
    return section


def _h2_sections(text: str) -> list[tuple[str, int, int]]:
    """(title, body_start, body_end) for every `## ` section in the file."""
    heads = list(SECTION_H2.finditer(text))
    out = []
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        out.append((h.group(1).strip(), h.end(), end))
    return out


def parse_scenarios(body: str, path: str, line: int, req_id: str) -> list[Scenario]:
    scenarios: list[Scenario] = []
    heads = list(SCENARIO_HEADING.finditer(body))
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(body)
        block = body[h.end():end]
        steps: list[tuple[str, str]] = []
        for raw in block.splitlines():
            m = SCENARIO_STEP.match(raw.strip())
            if m:
                steps.append((m.group(1).upper(), m.group(2)))
            elif steps and raw.startswith("  ") and raw.strip():
                keyword, text = steps[-1]
                steps[-1] = (keyword, f"{text} {raw.strip()}")
        if not any(k in ("WHEN", "THEN") for k, _ in steps):
            raise SpecParseError(
                path, line,
                f"scenario {h.group(1)!r} under {req_id} to carry at least a WHEN and a THEN step",
                block.strip()[:120] or "empty scenario",
            )
        scenarios.append(Scenario(name=h.group(1).strip() or "Scenario", steps=steps))
    return scenarios


def parse_openspec_spec_file(path: Path) -> list[Requirement]:
    text = path.read_text(encoding="utf-8")
    headings = list(REQUIREMENT_HEADING.finditer(text))
    requirements: list[Requirement] = []

    for i, h in enumerate(headings):
        family, number_s, name = h.group(1), h.group(2), h.group(3).strip()
        line = _line_number(text, h.start())
        next_block = BLOCK_END.search(text, h.end())
        end = next_block.start() if next_block else len(text)
        body = text[h.end():end]
        section = _delta_section_for_offset(text, h.start())

        if section == "REMOVED":
            reason_m = REMOVED_REASON.search(body)
            migration_m = REMOVED_MIGRATION.search(body)
            if not reason_m or not migration_m:
                raise SpecParseError(
                    str(path), line,
                    "a REMOVED requirement to carry both **Reason:** and **Migration:**",
                    body.strip()[:120],
                )
            pointer = REQ_ID_TOKEN.findall(migration_m.group(1))
            requirements.append(
                Requirement(
                    family=family, number=int(number_s), name=name, statement="",
                    status="retired", retired_reason=reason_m.group(1).strip(),
                    retired_pointer=pointer, source_file=str(path), source_line=line,
                )
            )
            continue

        if not SCENARIO_HEADING.search(body):
            raise SpecParseError(
                str(path), line,
                f"at least one '#### Scenario:' block under requirement {family}-{number_s}",
                "no scenario heading found before the next requirement",
            )

        # Kind is mandatory on every active requirement — no default, never
        # guessed. A requirement without it is a hard parse error, same
        # treatment as a missing Scenario: the bridge must never have to guess
        # whether something is projectable work. (OpenSpec's own archive drops
        # the line when a MODIFIED delta omits it; this is where that is caught.)
        kind_m = KIND_FIELD.search(body)
        if not kind_m or kind_m.group(1) not in VALID_KINDS:
            raise SpecParseError(
                str(path), line,
                f"a '**Kind:**' field on {family}-{number_s} with one of {sorted(VALID_KINDS)}",
                kind_m.group(1) if kind_m else "no **Kind:** field found",
            )
        kind = kind_m.group(1)

        first_scenario = SCENARIO_HEADING.search(body)
        statement = KIND_FIELD.sub("", body[:first_scenario.start()]).strip()
        if not statement:
            raise SpecParseError(
                str(path), line, f"a non-empty statement for {family}-{number_s}", "empty",
            )
        scenarios = parse_scenarios(body[first_scenario.start():], str(path), line, f"{family}-{number_s}")

        gated_by: list[str] = []
        for token in POINTER.findall(statement):
            if token not in gated_by:
                gated_by.append(token)

        requirements.append(
            Requirement(
                family=family, number=int(number_s), name=name, statement=statement,
                status="active", kind=kind, gated_by=gated_by, scenarios=scenarios,
                source_file=str(path), source_line=line,
            )
        )

    # `## Retired Requirements`: one clause per bullet. Retirement, not
    # deletion — the id stays in the document with its pointer, so a tracked
    # issue or a client's reference to it still resolves to a reason.
    for title, start, end in _h2_sections(text):
        if title != RETIRED_SECTION_TITLE:
            continue
        for raw in text[start:end].splitlines():
            stripped = raw.strip().lstrip("-*").strip()
            if not stripped:
                continue
            m = RETIRED_CLAUSE.search(stripped)
            line = _line_number(text, start) + text[start:end].splitlines().index(raw)
            if not m:
                raise SpecParseError(
                    str(path), line,
                    "a retirement clause 'OLDID (reason) → NEWID[, NEWID]' under ## Retired Requirements",
                    stripped[:120],
                )
            old_id, reason, pointer_text = m.group(1), m.group(2).strip(), m.group(3)
            pointers = REQ_ID_TOKEN.findall(pointer_text)
            if not pointers:
                raise SpecParseError(
                    str(path), line, f"at least one replacement requirement id for retired {old_id}", pointer_text.strip(),
                )
            if any(r.id == old_id for r in requirements):
                raise SpecParseError(
                    str(path), line,
                    f"{old_id} to appear either as a live requirement or under Retired Requirements, not both",
                    f"{old_id} has both",
                )
            fam, num_s = old_id.split("-", 1)
            requirements.append(
                Requirement(
                    family=fam, number=int(num_s), name="(retired)", statement="",
                    status="retired", retired_reason=reason, retired_pointer=pointers,
                    source_file=str(path), source_line=line,
                )
            )

    return requirements


def parse_spec_file_facts(path: Path) -> tuple[str | None, str | None]:
    """(title, purpose) of a main spec file: the H1 with a trailing
    ' Specification' stripped, and the `## Purpose` prose."""
    text = path.read_text(encoding="utf-8")
    title = None
    h1 = H1.search(text)
    if h1:
        title = re.sub(r"\s+Specification$", "", h1.group(1).strip())
    purpose = None
    for section_title, start, end in _h2_sections(text):
        if section_title == PURPOSE_TITLE:
            purpose = text[start:end].strip() or None
            break
    return title, purpose


def _split_fields_and_detail(body: str) -> tuple[dict[str, str], str]:
    """Fields from the contiguous bullet block at the top of a decision's
    body; everything after the first blank line that follows it is detail."""
    lines = body.splitlines()
    i = 0
    while i < len(lines) and not lines[i].strip():
        i += 1
    fields: dict[str, str] = {}
    last_key: str | None = None
    while i < len(lines):
        raw = lines[i]
        if not raw.strip():
            break
        m = FIELD_LINE.match(raw.strip())
        if m:
            last_key = m.group(1).strip().lower()
            fields[last_key] = m.group(2).strip()
        elif last_key is not None and raw.startswith("  "):
            fields[last_key] = (fields[last_key] + " " + raw.strip()).strip()
        else:
            break
        i += 1
    detail = "\n".join(lines[i:]).strip()
    return fields, detail


def parse_openspec_decisions_file(path: Path) -> list[Decision]:
    text = path.read_text(encoding="utf-8")
    headings = list(DECISION_HEADING.finditer(text))
    decisions: list[Decision] = []
    seen: set[str] = set()
    for i, h in enumerate(headings):
        decision_id = h.group(1)
        title = h.group(2).strip() if h.group(2) else None
        line = _line_number(text, h.start())
        if decision_id in seen:
            raise SpecParseError(str(path), line, f"{decision_id} to be defined once", f"{decision_id} defined again")
        seen.add(decision_id)
        next_block = BLOCK_END.search(text, h.end())
        end = next_block.start() if next_block else len(text)
        body = text[h.end():end]
        fields, detail = _split_fields_and_detail(body)

        statement = fields.get("statement")
        state = (fields.get("state") or "").lower()
        if not statement or state not in DECISION_STATES:
            raise SpecParseError(
                str(path), line,
                f"{decision_id} to carry a Statement field and a State of {'/'.join(DECISION_STATES)}",
                body.strip()[:120],
            )
        blocks = [b.strip() for b in fields.get("blocks", "").split(",") if b.strip()]

        def opt(key: str) -> str | None:
            value = fields.get(key, "").strip()
            return value if value and value not in ("—", "-") else None

        decisions.append(
            Decision(
                id=decision_id, statement=statement, state=state,
                rationale=opt("rationale"), blocks=blocks,
                needed_by=opt("needed by"),
                default_if_deferred=opt("default if deferred"),
                status_label=opt("status label"), status_note=opt("status note"),
                title=title or opt("title"), section=opt("section"), resolution=opt("resolution"),
                detail=detail or None,
                source_file=str(path), source_line=line,
            )
        )
    return decisions


def parse_openspec(
    specs_dir: Path,
    decisions_file: Path | None,
    config_path: Path | None = None,
    base_dir: Path | None = None,
) -> ParsedSpec:
    """The whole project: every `spec.md` under `specs_dir` (one logical
    document, ids globally unique), the register, and the document-level
    facts the issue footers cite. `config_path` is `openspec/config.yaml`
    (for `spec_version`); `base_dir` is the project root footers are relative
    to — both default from a conventional `openspec/` layout."""
    specs_dir = Path(specs_dir)
    if base_dir is None and specs_dir.name == "specs" and specs_dir.parent.name == "openspec":
        base_dir = specs_dir.parent.parent
    if config_path is None and specs_dir.parent.name == "openspec":
        config_path = specs_dir.parent / "config.yaml"

    parsed = ParsedSpec()
    parsed.source_name = specs_dir.name
    parsed.base_dir = str(base_dir) if base_dir else None
    if config_path is not None:
        parsed.version = read_config_value(Path(config_path), "spec_version")

    for spec_file in sorted(specs_dir.rglob("spec.md")):
        reqs = parse_openspec_spec_file(spec_file)
        parsed.requirements.extend(reqs)
        title, purpose = parse_spec_file_facts(spec_file)
        families = []
        for r in reqs:
            if r.status == "active" and r.family not in families:
                families.append(r.family)
        for fam in families:
            parsed.family_files.setdefault(fam, str(spec_file))
            if title:
                parsed.family_titles.setdefault(fam, title)
            if purpose:
                parsed.family_intros.setdefault(fam, purpose)

    seen: dict[str, str] = {}
    for r in parsed.requirements:
        if r.id in seen:
            raise SpecParseError(
                r.source_file, r.source_line,
                f"{r.id} to be defined once across the spec",
                f"{r.id} also defined at {seen[r.id]}",
            )
        seen[r.id] = f"{r.source_file}:{r.source_line}"

    if decisions_file is not None and Path(decisions_file).exists():
        parsed.decisions_source_name = Path(decisions_file).name
        parsed.decisions = parse_openspec_decisions_file(Path(decisions_file))
        parsed.decisions_source_name = str(decisions_file)
        # A requirement that points at a decision (`→ CQ-n`) is gated by it:
        # union into the decision's own `blocks`, never duplicated. Pointers at
        # ids that are not decisions are dropped from `gated_by` — a pointer at
        # a requirement is a cross-reference, not a gate.
        by_id = {d.id: d for d in parsed.decisions}
        prefixes = {d.id.split("-", 1)[0] for d in parsed.decisions}
        for r in parsed.requirements:
            if r.status != "active":
                continue
            r.gated_by = [t for t in r.gated_by if t.split("-", 1)[0] in prefixes]
            for token in r.gated_by:
                d = by_id.get(token)
                if d is not None and r.id not in d.blocks:
                    d.blocks.append(r.id)
    return parsed
