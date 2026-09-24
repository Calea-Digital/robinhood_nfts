# Tasks

## 1. Specification

- [ ] 1.1 Archive this change into `openspec/specs/activation/spec.md`; verify ACT-9 keeps its `**Kind:** work-item` line and its Scenario with the spec lint
- [ ] 1.2 Fold CQ-21 from this change's `decisions.md` into `openspec/decisions.md` under `## ADDED Decisions`; verify the lint counts 21 decisions
- [ ] 1.3 `docs/SPECIFICATION.md` §10 "Open after the call": add O9 for CQ-21 with Calea's recommendation; re-render; verify the generated-prose check passes
- [ ] 1.4 Commit, then `docs/tools/board.sh --dry` (expect CQ-21 to create and ACT-9 to refresh), then `docs/tools/board.sh`; verify the CQ-21 Task is Open with Due Date 2026-10-29 and a gating link to MNT-34

## 2. Code

- [ ] 2.1 None: `Activation` is unchanged by any answer to CQ-21; verify `forge test` unchanged
