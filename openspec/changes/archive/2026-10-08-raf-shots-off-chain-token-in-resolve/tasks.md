# Tasks

## 1. Spec

- [x] 1.1 Lint the delta; archive; fold CQ-9's record line into `openspec/decisions.md`; render the prose; commit; board (verify: `board.sh` read-back passes and MNT-42, MNT-43, MNT-44, MNT-57, MNT-58 and MNT-60 carry the new text)
- [x] 1.2 `docs/HANDOVER.md`: the reads line names the client's shots-left count; the worker's accepted risk names the `tokenId`, the three refusals and what stays visible (verify: no `shotsLeft(` left outside the archive)
- [x] 1.3 `openspec/changes/tranche-2/tasks.md`: line 1.3 (RAF-28) without `shotsLeft`; line 2.2 (RAF-29) with `tokenId`, `InvalidTokenId`, `AlreadyResolved`, `CycleExhausted`; a DEL-6 line for the client's mystery-box reads and the shots-left count (verify: lint passes)

## 2. Code (through the work loop, not this change)

- RAF-28 (MNT-42): the RAF-28 Scenario test on `MysteryBox`; no `shotsLeft`.
- RAF-29 (MNT-43): `resolve` with `tokenId` and the three refusals, when `PrizeDraw` is written.
