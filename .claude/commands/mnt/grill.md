---
name: "MNT: Grill"
description: "Grill a raw requirement to a shared understanding, then write it as an OpenSpec change: settled answers become requirements with Scenarios, open questions become decisions"
allowed-tools: Bash(openspec:*), Bash(git:*), Bash(docs/tools/board.sh:*), Bash(python3:*), Bash(/usr/bin/python3:*), Skill
---

Turn the requirement in `$ARGUMENTS` (or the next one the person describes) into a spec change
for the MNT board. Two phases, with the person's confirmation between them. This
command plans only: it never edits project code and never writes to the board.

**Before the first round, read** `openspec/config.yaml` (engagement, the family prefix map in
`rules.specs`, the decision prefix), every `openspec/specs/*/spec.md` the requirement could
touch (including their `## Retired Requirements`), `openspec/decisions.md`, and the
acceptance-standard requirements, which become every Task's Gates. A question the spec or the
code already answers is a fact, not a question: look it up and do not ask it.

**Phase 1: grill.** Call the Skill tool with `grilling` and follow it exactly: a design tree,
rounds over the frontier, numbered questions each with a recommended answer, and facts
dispatched to a sub-agent rather than asked. Keep the tree in the shape the spec will need,
so that every leaf ends as one of the following:
- **a requirement**: one behaviour, testable, with a Kind (work-item / acceptance-standard /
  commercial / informative) and a single Given/When/Then that is its definition of done;
- **a decision**: a question only a person can answer that is not answered yet. It needs what
  it gates, a `Needed by` date if one exists, and a default the work proceeds on meanwhile;
- **out of scope**: recorded, so it is not re-asked.
Ask about the family (an existing prefix or a new one), the boundary with the requirements
that sit beside it, and production impact (migration, rollback, what users see during a
deploy) whenever the change touches something live. Do not call `domain-modeling`: this
stack's register is `openspec/decisions.md`, not ADRs.

The phase ends when the frontier is empty **and** the person confirms the understanding. Close
it by listing every leaf as a proposed requirement, decision or out-of-scope item, with ids,
and wait for a yes.

**Phase 2: write the change.** Call the Skill tool with `openspec-propose`, naming the change
after the requirement (kebab-case). The artifacts follow the calea-house schema, as follows.
- **Specs delta:** each settled requirement goes under `## ADDED Requirements` (or
  `## MODIFIED Requirements`, which repeats the `**Kind:**` line) as
  `### Requirement: <FAMILY-n> — <Name>`, using the next free number in the family after
  counting active and retired ids alike. Body: the `**Kind:**` line, a plain statement, an
  optional `*Technical note.*` paragraph carrying the names, files and routes, then exactly
  one `#### Scenario:` with `- **GIVEN**` / `- **WHEN**` / `- **THEN**` bullets. A requirement
  waiting on a decision carries `(→ <D-n>)` in its statement.
- **Decisions delta:** each open question goes under `## ADDED Decisions` as `### <D-n> — <title>`,
  using the next free id in the register. Fields: `Statement`, `State: open`, `Blocks`,
  `Needed by` (an ISO date first, when there is one), and `Default if deferred` only if
  `engagement: client`. Then the record: the question as put, with the options weighed.
- **proposal.md:** why the change is needed and what it covers, and a `## Grilling record`
  section with each round's questions and the answers given, verbatim and short. This is the
  provenance a later session reads instead of re-asking.
- **tasks.md** of this change: the spec work only (write the delta, then lint), because it is
  archived together with the change. The implementation pick order lives in the **tranche
  change** (manual 02 W3: `skip_specs: true`, e.g. `openspec/changes/tranche-1/`). Append the
  new work-item ids there, one per line in pick order, creating that change if none is active.
  That is the file `/mnt:next` reads.

Then run `docs/tools/board.sh --dry` and fix every finding. Show the person the change and the
board's `--check-existing` preview (NEW / DRIFTED), and stop there. Archiving
(`/opsx:archive`), `docs/tools/spec_tools/fold_archive.py openspec/changes/archive/<the change> --write`, the commit and
`/mnt:board` happen only once the person says so.
