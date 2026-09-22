"""Parser for Calea's established (pre-OpenSpec) prose spec convention.

This is NOT the calea-house OpenSpec schema's native delta format
(`### Requirement: FAMILY-n — Name`, see parser_openspec.py). It is the
format MintABear's actual SPECIFICATION.md and OPEN-QUESTIONS.md are
written in today — the evidence calea-house was extracted FROM. The bridge
supports both because the real spec it has to run against (Phase 6) has not
been migrated into the OpenSpec artifact layout, and requiring that
migration first was never part of this session's scope.

Requirement convention: `**FAMILY-n Short name.** statement text...`, one
per bold-lead-in paragraph, statement running until the next requirement
marker or the next `##`/`###` heading. A trailing `**Retired identifiers.**`
paragraph maps old IDs to their replacement(s): `OLDID (reason) -> NEWID`.

Open-question convention: the register table at the top of OPEN-QUESTIONS.md
(`| CQ-n | Section | Question | Resolution/default | Needed by | Status |`),
enriched with `**Recorded as.**` lines from the detailed `### CQ-n` sections
below it, when present, for requirement-id `blocks` links. The whole detail
section is kept too — it is the body of the decision's tracker issue.

Document-level facts the issue bodies cite: the `**Version**` line, and the
family section headings `## n. Title (FAMILY)`, which give each Milestone its
title and each requirement its section number. The prose between a family
heading and its first requirement marker is the Milestone's own body.

Gating: a requirement whose statement points at a decision with `→ CQ-n`
(the spec's own convention) is gated by that decision; the parser adds the
requirement to that decision's `blocks`, alongside whatever the register's
`Recorded as.` line names. Both are the spec's words, not an inference.
"""
from __future__ import annotations

import re
from pathlib import Path

from spec_model import Decision, ParsedSpec, Requirement, SpecParseError

REQUIREMENT_MARKER = re.compile(
    r"\*\*([A-Z]{2,6})-(\d+)\s+([^*]+?)\.\*\*", re.MULTILINE
)
HEADING = re.compile(r"^#{1,6}\s", re.MULTILINE)
RETIRED_PARA_MARKER = re.compile(r"\*\*Retired identifiers\.\*\*")
RETIRED_CLAUSE = re.compile(
    r"([A-Z]{2,6}-\d+)\s*\(([^)]*)\)\s*(?:→|->)\s*([^;]+)"
)
REQ_ID_TOKEN = re.compile(r"\b[A-Z]{2,6}-\d+\b")

REGISTER_ROW = re.compile(
    r"^\|\s*(CQ-\d+)\s*\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|\s*([^|]*)\|\s*$",
    re.MULTILINE,
)
STATUS_TO_STATE = {
    "open": "open",
    "follow-up": "open",
    "answered": "resolved",
    "closed": "resolved",
}
CQ_DETAIL_HEADING = re.compile(r"^###\s+(CQ-\d+)\b.*$", re.MULTILINE)
RECORDED_AS_LINE = re.compile(r"\*\*Recorded as\.\*\*\s*(.+)")
DEFAULT_LINE = re.compile(r"\*\*Default if unanswered:\*\*\s*(.+)")
# A detail section ends at the next `###` (the next question) or `##` (the
# register's closing sections) — not only at the next question, or the last
# question would swallow whatever follows it.
H2_OR_H3 = re.compile(r"^#{2,3}\s", re.MULTILINE)

# `## 3. Collection contract — MintABear (COL)` — the family's section number,
# its human title, and the family code the requirement ids under it carry.
FAMILY_HEADING = re.compile(r"^##\s+(\d+)\.\s+(.+?)\s+\(([A-Z]{2,6})\)\s*$", re.MULTILINE)
SECTION_HEADING = re.compile(r"^##\s+(\d+)\.\s", re.MULTILINE)
VERSION_LINE = re.compile(r"^\*\*Version\*\*\s*([0-9][^\s·|]*)", re.MULTILINE)
# `(→ CQ-18)` inside a requirement's statement: the spec's own pointer from a
# requirement to the decision it waits on.
GATED_BY = re.compile(r"(?:→|->)\s*(CQ-\d+)")


def _line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def parse_legacy_prose_spec(path: Path) -> list[Requirement]:
    text = path.read_text(encoding="utf-8")
    requirements: list[Requirement] = []

    retired_para_match = RETIRED_PARA_MARKER.search(text)
    retired_para_start = retired_para_match.start() if retired_para_match else None

    markers = list(REQUIREMENT_MARKER.finditer(text))
    if not markers:
        raise SpecParseError(
            str(path), 1,
            "at least one requirement marker matching **FAMILY-n Name.**",
            "none found in file",
        )

    section_starts = [(h.start(), h.group(1)) for h in SECTION_HEADING.finditer(text)]

    def section_at(offset: int) -> str | None:
        current = None
        for start, number in section_starts:
            if start > offset:
                break
            current = number
        return current

    for i, m in enumerate(markers):
        family, number_s, name = m.group(1), m.group(2), m.group(3).strip()
        line = _line_number(text, m.start())

        if not number_s.isdigit():
            raise SpecParseError(str(path), line, "a numeric requirement id after the family code", m.group(0))

        # Statement runs from just after this marker to whichever comes first:
        # the next requirement marker, the next heading line, the retired-block,
        # or end of file.
        body_start = m.end()
        candidates = [len(text)]
        if i + 1 < len(markers):
            candidates.append(markers[i + 1].start())
        next_heading = HEADING.search(text, body_start)
        if next_heading:
            candidates.append(next_heading.start())
        if retired_para_start is not None and retired_para_start > body_start:
            candidates.append(retired_para_start)
        body_end = min(candidates)

        statement = text[body_start:body_end].strip()
        if not statement:
            raise SpecParseError(
                str(path), line,
                f"a non-empty statement body for {family}-{number_s}",
                "empty (marker immediately followed by another marker or heading)",
            )

        gated_by: list[str] = []
        for cq in GATED_BY.findall(statement):
            if cq not in gated_by:
                gated_by.append(cq)

        requirements.append(
            Requirement(
                family=family,
                number=int(number_s),
                name=name,
                statement=statement,
                status="active",
                section=section_at(m.start()),
                gated_by=gated_by,
                source_file=str(path),
                source_line=line,
            )
        )

    # Retirements: only from the "Retired identifiers." paragraph, applied
    # on top of whatever active requirements were already parsed (a retired
    # id normally has no marker of its own — it only ever appears here).
    if retired_para_match:
        para_end_candidates = [len(text)]
        next_heading_after = HEADING.search(text, retired_para_match.end())
        if next_heading_after:
            para_end_candidates.append(next_heading_after.start())
        para_text = text[retired_para_match.end(): min(para_end_candidates)]
        line = _line_number(text, retired_para_match.start())

        clauses = list(RETIRED_CLAUSE.finditer(para_text))
        if not clauses:
            raise SpecParseError(
                str(path), line,
                "at least one retirement clause 'OLDID (reason) -> NEWID' after **Retired identifiers.**",
                para_text.strip()[:120],
            )

        for c in clauses:
            old_id, reason, pointer_text = c.group(1), c.group(2).strip(), c.group(3)
            pointers = REQ_ID_TOKEN.findall(pointer_text)
            if not pointers:
                raise SpecParseError(
                    str(path), line,
                    f"at least one replacement requirement id for retired {old_id}",
                    pointer_text.strip(),
                )
            fam, num_s = old_id.split("-", 1)
            existing = next((r for r in requirements if r.id == old_id), None)
            if existing is not None:
                raise SpecParseError(
                    str(path), line,
                    f"{old_id} to appear only in the Retired identifiers. clause, not also as a live requirement marker",
                    f"{old_id} has both a live marker and a retirement clause",
                )
            requirements.append(
                Requirement(
                    family=fam,
                    number=int(num_s),
                    name="(retired)",
                    statement="",
                    status="retired",
                    retired_reason=reason,
                    retired_pointer=pointers,
                    source_file=str(path),
                    source_line=line,
                )
            )

    return requirements


def parse_legacy_document(path: Path) -> ParsedSpec:
    """The requirements plus the document-level facts every issue body cites:
    the version line and, per family, its section number, title and intro
    prose. Titles come from the spec's own `## n. Title (FAMILY)` headings, so
    a Milestone reads as the spec's chapter does, not as "COL — requirement
    family"; `--overrides` may still retitle one.
    """
    text = path.read_text(encoding="utf-8")
    parsed = ParsedSpec()
    parsed.source_name = path.name
    parsed.requirements = parse_legacy_prose_spec(path)

    version_m = VERSION_LINE.search(text)
    parsed.version = version_m.group(1).strip() if version_m else None

    marker_starts = [m.start() for m in REQUIREMENT_MARKER.finditer(text)]
    for h in FAMILY_HEADING.finditer(text):
        number, title, family = h.group(1), h.group(2).strip(), h.group(3)
        parsed.family_titles[family] = title
        parsed.family_sections[family] = number
        # Intro: from the heading to the first requirement marker in the
        # section, or to the next `##`/`###` heading if a sub-heading comes
        # first. Empty when the first requirement follows the heading directly.
        end_candidates = [len(text)]
        next_heading = H2_OR_H3.search(text, h.end())
        if next_heading:
            end_candidates.append(next_heading.start())
        first_marker = next((s for s in marker_starts if s >= h.end()), None)
        if first_marker is not None:
            end_candidates.append(first_marker)
        intro = text[h.end():min(end_candidates)].strip()
        if intro:
            parsed.family_intros[family] = intro
    return parsed


def parse_legacy_open_questions(path: Path) -> list[Decision]:
    text = path.read_text(encoding="utf-8")
    rows = list(REGISTER_ROW.finditer(text))
    if not rows:
        raise SpecParseError(
            str(path), 1,
            "a register table with rows '| CQ-n | Section | Question | Resolution/default | Needed by | Status |'",
            "no matching table rows found",
        )

    # The detail sections below the table: the "Recorded as." line enriches
    # `blocks`; the whole section is the decision's tracker body. A section
    # ends at the next `###` or `##` heading, whichever comes first.
    recorded_as: dict[str, str] = {}
    details: dict[str, str] = {}
    detail_headings = list(CQ_DETAIL_HEADING.finditer(text))
    for h in detail_headings:
        cq_id = h.group(1)
        next_heading = H2_OR_H3.search(text, h.end())
        end = next_heading.start() if next_heading else len(text)
        section_text = text[h.end():end].strip()
        if section_text:
            details[cq_id] = section_text
        m = RECORDED_AS_LINE.search(section_text)
        if m:
            recorded_as[cq_id] = m.group(1)

    decisions: list[Decision] = []
    seen_ids: set[str] = set()
    for row in rows:
        cq_id = row.group(1)
        line = _line_number(text, row.start())
        if cq_id in seen_ids:
            raise SpecParseError(
                str(path), line,
                f"{cq_id} to appear once in the register table",
                f"{cq_id} appears a second time",
            )
        seen_ids.add(cq_id)

        section = row.group(2).strip()
        resolution = row.group(4).strip()
        needed_by = row.group(5).strip()
        status_label = row.group(6).strip()
        status_raw = status_label.lower()
        state = STATUS_TO_STATE.get(status_raw)
        if state is None:
            raise SpecParseError(
                str(path), line,
                "a Status column value of Open / Follow-up / Answered / Closed",
                row.group(6).strip(),
            )

        blocks = REQ_ID_TOKEN.findall(recorded_as.get(cq_id, ""))
        detail = details.get(cq_id)
        default_m = DEFAULT_LINE.search(detail) if detail else None

        decisions.append(
            Decision(
                id=cq_id,
                statement=row.group(3).strip(),
                state=state,
                rationale=recorded_as.get(cq_id),
                blocks=blocks,
                needed_by=needed_by or None,
                default_if_deferred=default_m.group(1).strip() if default_m else None,
                status_label=status_label,
                section=section or None,
                resolution=resolution or None,
                detail=detail,
                source_file=str(path),
                source_line=line,
            )
        )

    return decisions


def parse_legacy(spec_path: Path, open_questions_path: Path | None) -> ParsedSpec:
    parsed = parse_legacy_document(spec_path)
    if open_questions_path is not None and open_questions_path.exists():
        parsed.decisions_source_name = open_questions_path.name
        parsed.decisions = parse_legacy_open_questions(open_questions_path)
        # A requirement that points at a decision (`→ CQ-n`) is gated by it.
        # Union with the register's own "Recorded as." derivation, in spec
        # order; never duplicated. A pointer at an id the register does not
        # carry is left on the requirement for the validator to report.
        by_id = {d.id: d for d in parsed.decisions}
        for r in parsed.requirements:
            if r.status != "active":
                continue
            for cq in r.gated_by:
                d = by_id.get(cq)
                if d is not None and r.id not in d.blocks:
                    d.blocks.append(r.id)
    return parsed
