# Tasks

This change carries the spec work only; the implementation pick order is in
`openspec/changes/tranche-2/tasks.md`.

## 1. Spec

- [x] 1.1 Write the deltas: `specs/mystery-box` (RAF-35, RAF-36, RAF-37 added; RAF-32, RAF-33,
  RAF-14, RAF-34, RAF-16, RAF-17, RAF-18 modified), `specs/operations` (OPS-2, OPS-3, OPS-7),
  `specs/deliverables` (DEL-6, DEL-8); `decisions.md` (CQ-22 resolved, folded by hand). Verify:
  every block has its Kind and one Scenario.
- [ ] 1.2 Lint and validate: `openspec validate raf-prize-vault-claims --strict` and
  `docs/tools/board.sh --dry` with no finding. Verify: both exit clean.
- [ ] 1.3 On the person's word: `/opsx:archive`, fold CQ-22 into `openspec/decisions.md`, render
  the prose, commit, `/mnt:board`. Verify: the board's read-back passes.
