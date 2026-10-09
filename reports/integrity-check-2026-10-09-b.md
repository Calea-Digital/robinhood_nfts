# Integrity check — 2026-10-09 (second, before the PR)

**Scope:** the spec, the board, the code and the docs.
- **NFT:** `feat/contracts` at `bc89abb`, the same as `origin/feat/contracts`; 0 commits behind
  `origin/release/1.1` (`0813f8b`) before the fetch of job 2.
- **Here:** `main` at `52eb604` (3 ahead of origin).
- **Method:** read-only, except the HANDOVER fixes listed at the end. Nothing was written to
  YouTrack.
- **Precedent:** `reports/integrity-check-2026-10-09.md`. Its IC numbers are written "9 Oct IC-n"
  below.

## Automated checks

| Check | Result |
|---|---|
| `openspec validate --specs` | 6 passed, 0 failed |
| `lint_spec.py` | OK: 60 active requirements, 24 decisions |
| `render_calea_prose.py --check` | SPECIFICATION.md and OPEN-QUESTIONS.md current |
| `build_client_doc.py --check` | §10's open items match the register |
| `board.sh --dry` | 0 would be created, 0 refreshed; every Task CURRENT; WL-1 and WL-5 tracked but excluded (informative) |
| bridge `validate.py --check-issues` (with `overrides/mnt.json`) | OK: no traceability problems (89 requirements, 24 decisions) |
| `check_scenario_quotes.py` | 40 quoting, 0 not quoting |
| Tree → test names (by hand) | every test a tree names exists in `forge test --list`, including all of RAF-19's acceptance map in `MysteryBox.tree.md` |
| RAF-17 reads against the ABIs | `forge inspect` view functions of `MysteryBox` (16) and `PrizeDraw` (20) equal the note's list exactly; no read is missing and none is extra |
| Spec names against the code | every backticked identifier in `mystery-box/spec.md` exists in `src/`; `InsufficientGas` is in RAF-29's note and in `PrizeDraw` |

## Spec ↔ board

- **Tranche-2 `tasks.md` against the board.** Lines 1.1–3.5 are ticked, and their Tasks are Done:
  MNT-136, 41, 42, 51, 43, 44, 157, 137, 138, 57, 58, 60, 158. Lines 4.1 (RAF-14, MNT-55) and
  4.2 (RAF-18, MNT-59) are unticked and Open.
- **Decisions.** States match the register: CQ-1, 2, 12, 17 and 20 are In Progress
  (follow-up), and CQ-22 and 23 are Open. The `depends on` links match `Blocks` (the bridge's
  check 5).
- **MNT-158 is shaped like tranche-1 lines 6.2 and 6.3.** It is a Defect with Spec Ref DEL-6,
  under MNT-6, relating to MNT-69, and named on line 3.5. It has its accept comment and logged
  time.

## Findings, most severe first

### Medium

- **IC-1: decisions overdue or due on Monday** (9 Oct IC-4, still standing).
  - **Overdue:** CQ-12 (MNT-83, due 2 Oct: the admin to confirm, and the worker) and CQ-20
    (MNT-91, due 5 Oct: the 222 ids). CQ-20 has no default: the first cycle can't be scheduled
    without the ids.
  - **Due 12 Oct:** CQ-17 (the VRF holder), CQ-22 (push or request), CQ-23 (the worker's
    operator).
  - **Then:** CQ-2 (the $MNTD addresses; testnet now, mainnet by 20 Oct) and CQ-1 (dates, by
    29 Oct).
  - **Route:** job 4's document, for the meeting on 12 October. After it, record the answers in
    `decisions.md` and run `/mnt:board`.

- **IC-2: NFT's docs don't describe the mystery box** (9 Oct IC-7 and IC-13, still standing).
  This PR puts them in front of MINT's developers.
  - `packages/contracts/README.md`:
    - :25 says "`MysteryBox` and `PrizeDraw` are still to come";
    - the contracts table has no rows for them;
    - :43 says the CSV `compare` is "still to be built", though it was built in WL-4;
    - :50 says "CI-tested".
  - `docs/DESIGN.md` has no box or draw section. Its `locked-ether` line (:55–58) omits
    `PrizeDraw`, and nothing covers `reentrancy-no-eth` on `resolve`'s request.
  - `docs/RUNBOOK.md` has no mystery-box section: exclusions, the first cycle, the draw's terms,
    `applyOutcomes`/`InsufficientGas`, pausing the box before the draw.
  - `contracts-client/README.md` has its "The mystery box" section (from MNT-158); only :67
    "They run in CI" is stale.
  - **The trees:** retired WL-3/WL-7 are cited with no note; `Verify.tree.md:3` says "run in CI".
  - **Route:** one `NONE` Task, branch `docs/mystery-box` off `feat/contracts`:
    - README rows and wording;
    - DESIGN sections for the box and the draw;
    - a RUNBOOK stub naming the order and the two points above (the full section comes with the
      deploy entry points, OPS-5);
    - the CI wording; the tree notes.
    It merges on your word. If you want it in this PR, it merges before job 3; otherwise the PR
    goes as is and the docs follow it.

- **IC-3: CLAUDE.md is stale** (9 Oct IC-6, still standing).
  - :39 gives the active change as `openspec/changes/tranche-1/`; it is tranche-2.
  - The architecture table (:45–57) has no `MysteryBox`, `PrizeDraw` or
    `IVRFCoordinatorV2Plus` rows. The client row doesn't mention the mystery-box calls (the play
    page, the admin page on both chains, the worker, `draw: {…}`).
  - The mystery-box paragraph (:69) predates RAF-8's review:
    - it says `PLAYABLE` is `PrizeDraw`'s constructor argument by following from the box (the
      draw takes its own `playable_` and `firstOpenIndex`);
    - it omits the store-only callback, `applyOutcomes`/`InsufficientGas`, `CycleStarted`,
      `MAX_CYCLE_LENGTH`, the worker role and the pause.
  - **Route:** on your word, as before. Rows for the two contracts and the client, the paragraph
    cut to the load-bearing rules, with a pointer to NFT's `docs/DESIGN.md` once IC-2 has
    written it.

### Low

- **IC-4: MINT's two Tasks on our board, MNT-145 ("Revisar contrato MM Mint") and MNT-146
  ("Crear multisig de Mint").** Both were opened by MINT's team on 6 October, with no
  description, no Spec Ref and no link.
  - MNT-146 implies a multisig, but CQ-12 records the admin `0x1530…6141` as an EOA owning every
    contract. HANDOVER's accepted risks rest on that, and so does unknown 6 ("moot while MINT's
    admin is an EOA").
  - **Route:** a question in job 4's document: is a Safe coming, on which chains, and does it
    replace `0x1530…6141` as the admin? MNT-145 is noted only.

- **IC-5: MNT-154 (`NONE`, the move into NFT) has been In Progress since 7 October with no
  claim comment** (9 Oct IC-9, still standing). Its last step is PR B, which waits on Lorenzo.
  `feat/contracts-client-workspace` is now further behind `feat/contracts`.
  - **Route:** put PR B's timing to MINT in the document. Then you close MNT-154 with PR B as a
    follow-up, or it stays open until PR B merges.

- **IC-6: WL-1 and WL-5 Tasks are Done though the requirements are informative** (9 Oct IC-8,
  still standing). These are MNT-20, MNT-24, MNT-109 and MNT-110; MNT-24 still depends on CQ-1.
  The read-back passes now, through the overrides, so nothing fails.
  - **Route:** yours: confirm Done, or cancel.

- **IC-7: nothing checks that the tests a tree names exist.** The hand check passes today.
  - **Route (proposed, not built):** `docs/tools/check_tree_tests.py` beside
    `check_scenario_quotes.py`. It would read `--code-root` (default `../NFT/packages`), take every
    `test_…`/`testFork_…` token from `contracts/test/*.tree.md`, compare them with the function
    names in `contracts/test/**/*.t.sol` (a regex, so no forge run), and fail listing the missing
    ones. It would run in `/mnt:done`'s gates beside the quote check.

- **IC-8: HANDOVER was stale** (fixed in this commit):
  - the test counts were 315/141 (now 328/180);
  - the gates' date;
  - "`bc89abb` … not pushed";
  - the client's admin and worker calls were still listed as to do;
  - "join it in tranche 2".

### Info

- **IC-9: the client document v2.6 is dated** (9 Oct IC-17, still standing). Its "Where the work
  stands" is as of 29 September. `decisions.md:486` keeps the superseded "`shotsLeft` gives the
  8/10".
  - **Route:** rides with the next client document. Monday's questions document doesn't replace
    it.
- **IC-10: housekeeping** (9 Oct IC-18, partly standing):
  - **Here:** the untracked `lib/` (53 MB) is still there; the local branch named `origin` is
    gone; `.memsearch/` changes; `main` is 3 commits ahead of origin.
  - **NFT:** 8 local branches whose upstream is gone (down from 10).
  - **The hook:** the `.git/board-synced-tree` marker is still absent.
  - **Route:** you decide on deletions and the push here. One `/mnt:board` write creates the
    marker.

## Found consistent

- Spec, board and register (all automated checks above).
- RAF-17's "no other public read exists" against both ABIs and both interface pins.
- Every spec-named error, event and function on the mystery-box contracts. `InsufficientGas` is
  in RAF-29.
- Every Scenario quoted (40/0), and every test a tree names exists.
- MNT-158's shape and evidence.
- The client README's mystery-box section.

## Fixed here

- **IC-8:** HANDOVER corrected (this commit).
