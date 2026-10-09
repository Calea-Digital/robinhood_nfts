# Integrity check — 2026-10-09

**Scope:** the spec, the board, the code and the docs.
- **NFT:** `feat/contracts` at `7064fb7` (6 commits ahead of `origin/feat/contracts` at `e3a1cb7`).
- **Here:** `main` at `6419c2f` (3 ahead of origin).
- **Method:** read-only. Nothing was written to YouTrack, and no file was edited except this report.
- **Precedent:** the 24 September check (`tranche-1-review-log.md`, "Integrity check").

## Automated checks

| Check | Result |
|---|---|
| `openspec validate --specs` | 6 passed, 0 failed; only the style warning that requirements lack SHALL/MUST |
| `lint_spec.py` | OK: 60 active requirements, 24 decisions |
| `render_calea_prose.py --check` | SPECIFICATION.md and OPEN-QUESTIONS.md current |
| `build_client_doc.py --check` | §10's open items match the register |
| `board.sh --dry` | 78 CURRENT, 0 DRIFTED, 0 NEW; WL-1 and WL-5 tracked but excluded (informative); 0 would be created or refreshed |
| bridge `validate.py --check-issues` | OK: no traceability problems (89 requirements, 24 decisions) |
| NFT gates at `7064fb7` | fmt clean, 0 warnings, 315 tests, coverage 100/100, Slither 51 (no High or Critical), `verify.sh` dry run and test ✓, client 141 |
| `check_scenario_quotes.py` | 37 quoting, 0 not quoting |
| Trees | the INV/Fork line is identical in all 7 contract trees; INV-1…29 and Fork-1…4 are each defined once |
| Board vs `tasks.md` | every ticked tranche-2 line is Done, with an accepted comment and a merge on `feat/contracts`; all 31 NFT and 17 workspace shas named in comments exist |

`/mnt:board` keeps the spec and the board aligned, and that alignment is clean. Every finding
below is in a part `/mnt:board` does not look at.

## Findings, most severe first

### Medium

- **IC-1: the next three Tasks can't fully meet their Scenarios until RAF-33 is built.** RAF-33
  is hard-gated on CQ-22.
  - RAF-17 lists `payoutOf(openIndex)` among "every listed read".
  - RAF-19 lists "a win is recorded as paid once, and a loss cannot be".
  - RAF-14's Scenario has a non-worker call `recordPayout`.
  - None of these exist (`forge inspect` on both ABIs).
  - HANDOVER (the O3 row) says "`recordPayout` is built either way". Its shape — `NotAWin`,
    `AlreadyPaid`, `PrizePaid` — doesn't depend on push or request delivery; only who sends the
    transfer does.
  - **Proposed route:** a spec amendment (`/opsx:propose`, `/mnt:grill` if needed) that moves
    the CQ-22 gate from RAF-33's record to the delivery clause, then `/mnt:board`. RAF-33 then
    goes first and RAF-17, RAF-19 and RAF-14's `recordPayout` half follow.
  - **Alternative:** do RAF-17 and RAF-19 now, minus the payout parts, as RAF-16 did.

- **IC-2: `tasks.md` line 3.5 (DEL-6) points at MNT-69, which is Done** (closed 25 September,
  tranche 1).
  - `/mnt:next` claims only Open Tasks, so it cannot pick the line up.
  - The work it names isn't built: the client's mystery-box calls.
  - **Route:** a new Task with Spec Ref DEL-6 (a Defect, or a `NONE` Task under the integration
    milestone), named on the line as tranche-1 lines 6.2 and 6.3 do. Or the person reopens
    MNT-69.

- **IC-3: line 2.4 (MNT-157) is ticked, but still promises "the runbook gives `applyOutcomes`
  an explicit gas limit".**
  - That item was dropped in the claim, and the code made it unnecessary.
  - The line also says "nothing could be applied", which is looser than the code and INV-29
    ("fewer than `maxCount`").
  - **Route:** reword the line here (my slip).

- **IC-4: decisions overdue or due soon.**
  - **Overdue:** CQ-12 (MNT-83, due 2 October) and CQ-20 (MNT-91, due 5 October, "before
    tranche 2 starts").
  - **Due 12 October:** CQ-22 (MNT-139, Open, gates RAF-33), CQ-23 (MNT-140, Open, gates
    RAF-14, RAF-18, OPS-5, OPS-1) and CQ-17 (MNT-88).
  - The board matches the register.
  - **Route:** the person chases MINT, or moves "Needed by" in `decisions.md`, then runs
    `/mnt:board`.

- **IC-5: HANDOVER is stale** (`docs/HANDOVER.md`).
  - :174–194, :297–299: `e3a1cb7` "not pushed" (it is on origin), 310 tests, quotes 36/0, and
    "next RAF-16"; RAF-16 and MNT-157 are missing from Done.
  - :128, :130, :401: the test counts are 235/127; Slither's accepted Mediums omit
    `MysteryBox`/`PrizeDraw` `locked-ether` and `PrizeDraw._requestWord` `reentrancy-no-eth`.
  - :51, :509: the pick order points to tranche-1.
  - :491, :513: ACT-11 is cited, but it is retired (ACT-15).
  - :96, :247: `recordPayout` is described as built.
  - :3, :222: the dates.
  - **Route:** a direct commit here.

- **IC-6: CLAUDE.md is stale.**
  - :39: the active change is given as tranche-1.
  - :43–57: the "today" table has no `MysteryBox`, `PrizeDraw` or `IVRFCoordinatorV2Plus` rows.
  - :69, the mystery-box paragraph:
    - it calls `recordPayout` built;
    - it implies `PLAYABLE` follows from the box (the box takes `EXPECTED_PLAYABLE`; the draw
      takes its own `playable_`);
    - it omits the draw's `cycleId`/`start`, `CycleStarted`, store-only callback,
      `applyOutcomes`/`InsufficientGas`, `firstOpenIndex`, `MAX_CYCLE_LENGTH`, worker and pause.
  - :54, :149: "CI", though NFT has no CI.
  - The handover's open item was to point to NFT's DESIGN.md rather than restate it.
  - **Route:** a direct commit here. CLAUDE.md is the person's file, so it goes on their word.

- **IC-7: NFT's docs have no mystery box.**
  - `packages/contracts/README.md:14–25` says `MysteryBox` and `PrizeDraw` are "still to come";
    :43 says the CSV `compare` is "still to be built"; :40 is about deploy order; :50 says
    "CI-tested".
  - `docs/DESIGN.md` has no box or draw sections, and its locked-ether line omits `PrizeDraw`.
  - `docs/RUNBOOK.md` has no mystery-box section.
  - `contracts-client/README.md:66` says "They run in CI".
  - **Route:** one `NONE` Task in NFT (README, DESIGN), on a branch through review. The RUNBOOK
    section belongs with RAF-18/OPS-5 and the deploy entry points; until then, a stub naming
    `applyOutcomes`/`InsufficientGas` and "pause the box before the draw".

- **IC-8: WL-1 and WL-5 are informative in spec v2.6, but their Tasks are Done.** These are
  MNT-20, MNT-24 and their Defects MNT-109 and MNT-110.
  - MNT-24 still depends on CQ-1.
  - MNT-154 recorded that the bridge read-back trips on these.
  - **Route:** the person cancels them or confirms Done, and decides the CQ-1 link.

### Low

- **IC-9: MNT-154 (PR B) is In Progress and tagged `MNT Claude`, with no Claim comment.** Its
  last activity was 7 October. Its branch `feat/contracts-client-workspace` sits on the pre-move
  import (`89c08f6`) and is 69 commits behind `feat/contracts`.
  - **Route:** a claim comment, or hand it to the person. Rebase or merge PR B when Lorenzo
    agrees.
- **IC-10: Defect "relates to" links are missing.**
  - MNT-141 and MNT-155 → MNT-23 (WL-4).
  - MNT-142 → MNT-37 (ACT-12).
  - MNT-156 → MNT-69 (DEL-6).
  - **Route:** Claude adds the links.
- **IC-11: the `MNT Claude` tag is missing** on MNT-30 (ACT-5) and MNT-63 (OPS-3), both of
  which have Claude claims.
  - **Route:** Claude adds the tag.
- **IC-12: the times written in "Reviewed — accepted" comments don't match the merge commit
  times.** Affected: MNT-136, 41, 43, 44, 138, 155; MNT-41's accept time is earlier than its
  "Changes made" comment.
  - **Route:** `/mnt:review` takes the time from `git log -1 --format=%cI <merge>`. A command
    tweak here; the past comments are left as they are.
- **IC-13: the trees cite retired WL-3/WL-7 with no note saying so.**
  - Affected: `WhitelistClaim.tree.md`, `WhitelistImport.tree.md`, `Deploy.tree.md:16`,
    `Verify.tree.md:17`, `WhitelistExport.tree.md:92`.
  - `WhitelistImport.tree.md:9` says "MINT deploys one of the two".
  - `Verify.tree.md:3` says "run in CI".
  - **Route:** fold into IC-7's NFT Task.
- **IC-14: the memory is stale.**
  - `MEMORY.md:3` and `mintabear-build-decisions.md` give `e3a1cb7`, next RAF-16, and tranche-1
    as the pick order; CQ-14 is described as "open again".
  - `mintabear-spec-precedence.md` gives v2.0 and VRF on Base.
  - `mintabear-whitelist-help-pending.md` lists built items as pending.
  - `mintabear-branch-case-collision.md` says the branches are "in robinhood_nfts".
  - **Route:** Claude updates the memory.
- **IC-15: RAF-29's technical note doesn't mention `InsufficientGas`, and RAF-17's read list
  omits public reads.**
  - The omitted reads: `worker`, `paused`, `lastCycleResolved`, `openingOfRequest`,
    `excludedCount` and the VRF constants.
  - Errors not named anywhere: `NotWorker`, `OnlyCoordinator`, `InvalidConfig`, `InvalidRange`,
    `InvalidExpectedPlayable`, `ZeroAddress` — accepted as guard errors, as A-6 did in tranche 1.
  - **Route:** settle at RAF-17 (the ACT-14 precedent names every read). The `InsufficientGas`
    sentence rides with the next spec change.
- **IC-16: the leftover `CQ-n` `depends on` links don't match the register's Blocks.** These
  are ACT-2 → CQ-2, WL-3 → CQ-12 and RAF-24 → CQ-20.
  - They are harmless: the Tasks are Done or Canceled.
  - **Route:** leave them.

### Info

- **IC-17: the client document v2.6's "Where the work stands" (as of 29 September) and its
  calendar are dated.**
  - `decisions.md` still has the superseded line "`shotsLeft` gives the 8/10" (rendered at
    OPEN-QUESTIONS.md:484).
  - **Route:** ride with the next client document, by agreement.
- **IC-18: housekeeping.**
  - **Here:** an untracked `lib/` (53 MB of forge libraries left from before the move); a local
    branch literally named `origin`, which makes `origin/…` ambiguous; `.memsearch/` changes.
  - **NFT:** ten local branches whose remotes are gone.
  - **Board-reminder hook:** `.git/board-synced-tree` is absent, so the hook warns after any
    `openspec/` commit even when the board is current.
  - **Route:** the person decides on deletions. Running `/mnt:board` once writes the marker.
- **IC-19: three human Tasks have an empty Spec Ref instead of `NONE`.** These are MNT-133, 145
  and 146. Noted only.

## Found consistent

- OPEN-QUESTIONS narrative; SPECIFICATION narrative against the mystery-box spec.
- `spec_version` 2.6.
- NFT is free of private references: no MNT ids in commits since `release/1.1`, nor in
  `packages/`.
- The decision States match the register.
- No open Task is hard-gated by a resolved decision.
- Tranche-1 `tasks.md` against the board.
- Every `mnt/*` branch is merged.

## Done on the person's word (2026-10-09)

- **IC-3:** line 2.4 is reworded to what was built (`c704122`).
- **IC-5:** HANDOVER is current to `7064fb7`:
  - 315 / 141 tests, quotes 37/0;
  - RAF-16 and MNT-157 listed as Done;
  - the next steps, with IC-1 and IC-2;
  - Slither's six accepted Mediums, with `reentrancy-no-eth` added to the accepted risks;
  - the pick order points to tranche-2;
  - ACT-11 → ACT-15;
  - `recordPayout` marked as not built (`c704122`).
- **IC-12:** `/mnt:review` reads the accept time from the merge commit (`c704122`). The
  ai-stack template `templates/work-loop/review.md` doesn't have the change.
- **IC-10:** "relates to" links added: MNT-141 and MNT-155 → MNT-23; MNT-142 → MNT-37;
  MNT-156 → MNT-69.
- **IC-11:** `MNT Claude` tag added to MNT-30 and MNT-63.
- **IC-14:** memory updated:
  - the build-decisions pointer and its index line;
  - the CQ-14 paragraph marked superseded;
  - the pick order;
  - spec precedence (v2.6, O1–O7, VRF on Arbitrum);
  - the whitelist items now built;
  - the branch location.
- **Left for the person:** IC-1, IC-2, IC-4, IC-6, IC-7 and IC-13 (an NFT Task through
  review), IC-8, IC-9, IC-15, IC-16 and IC-18.
- **IC-1, done:** change `raf-33-record-ungated` (`53ee2c8`).
  - RAF-33's payout record is ungated and first in the pick order (line 2.5).
  - CQ-22 now gates RAF-18's step 6.
  - The bridge (ai-stack `49d235e`) now removes a gating link an open decision's spec no longer
    asks for, and the dry run previews link changes.
  - Board write (manifest `MNT-20261009T114907Z-23959cb5`): 3 refreshed; CQ-22 → RAF-18 linked;
    CQ-22 → RAF-33 unlinked. Read-back OK.
- **IC-16, done** in the same write: the leftover links CQ-2 → ACT-2, CQ-12 → WL-3 and
  CQ-20 → RAF-24 were removed.
