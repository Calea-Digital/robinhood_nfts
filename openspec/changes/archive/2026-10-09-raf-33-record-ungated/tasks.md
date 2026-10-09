# Tasks

## 1. Spec

- [x] 1.1 Lint the change (`lint_spec.py`, `openspec validate raf-33-record-ungated`). Verify: no
  errors, and the delta repeats both `**Kind:**` lines.
- [x] 1.2 Archive. Fold the decisions delta into `openspec/decisions.md` (CQ-22 `Blocks:
  RAF-18`, and the "Recorded as" sentence), then render the prose. Verify: `lint_spec.py` OK,
  `render_calea_prose.py --check` current, `build_client_doc.py --check` passes, and the
  mystery-box spec's RAF-33 has no `→ CQ-22` while RAF-18 step 6 has one.
- [x] 1.3 In `openspec/changes/tranche-2/tasks.md`, move RAF-33 ahead of RAF-17, out of the
  "Gated" group (renamed "Gated (CQ-23)"). Verify: `/mnt:next`'s first unticked line is RAF-33.
- [x] 1.4 Commit. Verify: `git status --porcelain -- openspec docs` is empty.

## 2. Board

- [ ] 2.1 Bridge fix in `~/trees/ai-stack/scripts/youtrack-bridge`. When an open decision's
  `Blocks`, or a requirement's `→` pointer, no longer names a target, remove the bridge-made
  gating link, record it in the manifest, and report `UNLINKED`. Verify: the bridge's own tests
  pass, and `bridge.py --check-existing` against MNT lists only the expected link changes.
- [ ] 2.2 `board.sh --dry`, then `board.sh`. Verify:
  - MNT-137 has no link to MNT-139;
  - MNT-59 depends on MNT-139 and MNT-140;
  - MNT-137 and MNT-59 bodies are refreshed;
  - validator checks 1–10 pass.
  If 2.1 is not taken, the person removes the MNT-139 → MNT-137 link in YouTrack by hand
  before this step.

## 3. Code (through the work loop)

- RAF-33 (MNT-137) is claimed by `/mnt:next`. It builds `recordPayout`, `NotAWin`,
  `AlreadyPaid`, `PrizePaid` and `payoutOf`. Its line carries RAF-34's open clause: assert
  `recordPayout` works while the draw is paused.
