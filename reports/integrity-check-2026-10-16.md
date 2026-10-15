# Integrity check — session of 16 October 2026 (run 15 October)

**Scope:** the internal docs, YouTrack and the code, against each other (prompt
`docs/prompts/2026-10-16-integrity-then-next.md`, Part 1). Nothing was fixed.

**State of NFT:**
- `feat/contracts` `5afada1` = `origin/feat/contracts`, the head of PR #17. It is checked out in
  `~/trees/NFT-every-bear`.
- `~/trees/NFT` is on `feat/contracts-client-workspace` `7087acc` (PR B).
- `~/trees/NFT-wl-removal` is on `mnt/RAF-14` `73273fa`, which is merged.

## Checks

| Check | Result |
|---|---|
| `board.sh --dry` | 0 created, 0 refreshed; 81 CURRENT, WL-1 and WL-5 tracked but excluded; validate and lint OK (style warnings only) |
| `tasks.md` ticks against the board | every ticked line Done (MNT-136, 41, 42, 51, 43, 44, 157, 137, 138, 57, 58, 60, 158, 169, 160, 161, 163, 162/64, 55); unticked: 3.7 MNT-170 Open, 0.3 MNT-154 In Progress, 5.1–5.3 MNT-166–168 Open, 4.2 MNT-59 In Progress; 5.4–5.6 have no issue yet (Defects when picked) |
| MNT-166, 167, 168 | subtasks of MNT-4 (RAF), tag `MNT Tranche 2`, Open |
| CQ-22 (MNT-139) | Done; no links, so it gates nothing |
| MNT-164, MNT-95 | both Open; MNT-164 is a Subtask of MNT-64 |
| `check_scenario_quotes.py` (code root `NFT-every-bear`) | 41 / 0 |
| `check_tree_tests.py` | 26 / 0 |
| Gates measured by the doc agents on `5afada1` | 259 contract tests, 100% coverage, 0 warnings; client 105 |
| Merges on `feat/contracts` since `f1f9ce6` | 8; every accept comment's SHA is the merge (MNT-160 `5ef3736`, 161 `10279d5`, 162 `98aa18f`, 163 `56edbd4`, 55 `08f33ef`, 64 `3649aad`, 165 `5300d35`, 169 `5afada1`); six merge trees equal the reviewed head, and the other two (`5ef3736`, `08f33ef`) add exactly the branch's patch (`patch-id` equal; `feat/contracts` had moved on) |
| Unmerged `mnt/*` | only `mnt/RAF-18` (MNT-59, In Progress) |
| Private text in NFT since `f1f9ce6` | none in commits or diff on `feat/contracts`, PR B or `mnt/RAF-18` (the only hit is Solady's `_HANDOVER_SLOT_SEED`, quoted in the audit report) |
| PR #17 | open, `5afada1`, MERGEABLE / CLEAN, **approved by lcampanis 2026-10-15 14:14 UTC**; description matches the branch (259 tests, client 105, Slither 41) |
| PR #16 (MINT, `feat/swap`) | touches `apps/swap`, a patch, the root README, **`pnpm-lock.yaml` and `pnpm-workspace.yaml`**; none of `packages/contracts*` |
| PR B | 13 behind, 1 ahead of `feat/contracts`; merges cleanly with it and, textually, with #16 |

## Findings, sorted by what blocks the next Task first

### Blocks or affects 3.7 (MNT-170) now

**IC-1. `../NFT` is not `feat/contracts`, and the checks default to it.**
- CLAUDE.md and `/mnt:*` say `../NFT` throughout, and `check_scenario_quotes.py` defaults to
  `--code-root ../NFT/packages`. But `~/trees/NFT` is on PR B (`7087acc`, 13 behind), and
  `feat/contracts` is checked out in `~/trees/NFT-every-bear`.
- So a default-root quote check reads PR B's stale code, and `mnt/DEL-6-170` cannot be created
  as a checkout in `~/trees/NFT` without leaving PR B.
- **Proposed:** branch `mnt/DEL-6-170` in its own worktree (or switch `~/trees/NFT-wl-removal`
  to it, since its branch is merged), and pass `--code-root` to both checks until the main
  checkout is back on `feat/contracts`. **Owner:** the person decides the worktree; Calea.

**IC-2. The client gate in `/mnt:done` cannot run as written.**
- CLAUDE.md:39 gives `pnpm --filter @mint/contracts-client check`. On `feat/contracts`,
  `pnpm-workspace.yaml` still excludes `!packages/contracts-client` until PR B, so `--filter`
  reaches nothing. CLAUDE.md:102–104 says the same about the workspace.
- **Proposed:** "`pnpm run check` in `packages/contracts-client` (`--filter` after PR B)" in
  CLAUDE.md and `.claude/commands/mnt/done.md`. **Owner:** Calea.

**IC-3. `/mnt:done`'s `allowed-tools` does not list `check_tree_tests.py`.**
- The step names it (`.claude/commands/mnt/done.md:31`), but line 4 allows only
  `check_scenario_quotes.py`.
- The ai-stack template `templates/work-loop/done.md` has neither check.
- **Proposed:** add it to the local `allowed-tools`, and both checks to the template (see IC-12).
  **Owner:** Calea.

### Before 0.3 (PR B)

**IC-4. HANDOVER says PR B is local and stale; it is pushed and current.**
- HANDOVER:16 says "(local, not pushed; stale: built on PR A, so it still holds the
  registries)". `origin/feat/contracts-client-workspace` is `7087acc`, pushed 14 October, based
  on `10279d5` (after MNT-160 and 161). No PR is open for it. HANDOVER:277 and :331 agree with
  the facts; :16 does not.
- **Proposed:** restate :16. **Owner:** Calea.

**IC-5. MINT's #16 changes the same lockfile and workspace file as PR B.**
- #16 edits `pnpm-lock.yaml` and `pnpm-workspace.yaml`; PR B adds +345 lines to the first and
  drops the client's exclusion from the second.
- Git merges them without a textual conflict. But a lockfile merged by text is not a
  resolved lockfile, so whichever lands second needs a fresh `pnpm install`. Its proof must
  then be re-run: each Dockerfile's frozen install and the apps' tests.
- **Proposed:** before pushing PR B, check whether #16 has merged. If it has, merge
  `release/1.1` into PR B and regenerate the lockfile. If it has not, tell Lorenzo that #16 needs
  the same after PR B. **Owner:** Calea; Lorenzo.

### Before 5.1 (the vault): spec and register

**IC-6. Spec text the vault change did not reach** (`openspec/specs/`, through `/opsx:propose`):
- RAF-27 (`mystery-box/spec.md:45`): "The prizes are in MINT's prize wallet (RAF-33), so the list
  is MINT's commitment." This pairs with R-2, which is RAF-27's Scenario title "Opening freezes
  the odds".
- OPS-1 (`operations/spec.md:16–24`): the Prize wallet row says it "holds and pays every prize".
  The Worker row and note give `resolve` and `recordPayout` only, with no ticket signing and not
  the vaults' `signer`.
- OPS-4 (`operations/spec.md:103`): "a payout from a prize wallet on 46630 or Sepolia recorded
  with `recordPayout`". OPS-4 is Done, so the vault's testnet run lives in RAF-18's Scenario. The
  note should say that, or say that it describes the 15 October rehearsal.
- OPS-3: the spec says Arbiscan through Etherscan's API for 42161 and 421614. `verify.sh` and the
  RUNBOOK (:276) use Sourcify only, and the rehearsal verified `PrizeDraw` on Sourcify for
  421614. Either the spec accepts Sourcify on Arbitrum, or `verify.sh` gains Arbiscan. `tasks.md`
  5.5 covers only the prize chains.
- **Proposed:** one change carrying RAF-27 (statement and R-2), OPS-1, OPS-4 and OPS-3, where
  OPS-3 needs the person's choice of Sourcify or Arbiscan. **Owner:** Calea; the person for
  OPS-3.

**IC-7. Register entries that still state the wallet model as resolved** (`openspec/decisions.md`,
MINT-facing history):
- CQ-8 (:615–622): "no contract is deployed on a prize chain" and the summary "MINT's prize
  wallet; no vaults".
- CQ-20 (:363–367): "A chain needs no contract: the prize wallet is an EOA".
- CQ-11 (:785–789): "there is no vault to refuse a withdrawal".
- **Proposed:** a "Superseded (15 October 2026, CQ-22)" paragraph on each, the same way CQ-11
  already records the 28 September change. Use the same decisions delta as IC-6. **Owner:**
  Calea.

**IC-8. The quote check cannot see a missing test, and `tasks.md` 5.x does not name every vault
share.**
- Since 14 October, only RAF-18's Scenario changed among work items; RAF-35–37 are new. RAF-14,
  16, 17, 32, 33, 34, OPS-2, 3 and DEL-6 changed their statements and notes only, so their
  quoting tests still pass (41/0). The checks confirm RAF-35–37 neither quote nor fail, because
  they say nothing about a requirement with no test.
- Requirements with no quoting test: DEL-3, DEL-6, DEL-9, RAF-18, RAF-35, 36, 37, OPS-1, 3, 4
  and 5.
  - DEL-3 is the auditor's, DEL-9 is the repository, and OPS-1/3/4/5 are operational.
  - **DEL-6 has no quoting test in the client.** HANDOVER:134 says every work-item Scenario has
    a test except OPS-1, 3, 4 and 5, so it also misses DEL-3, DEL-9 and RAF-18.
- Who covers what is new since the change:
  - **5.1:** RAF-35 and its shares of RAF-14, 16, 17 and 34.
  - **5.2:** RAF-36.
  - **5.3:** RAF-37.
  - **5.4:** OPS-2.
  - **5.5:** OPS-3, for the prize chains only.
  - **5.6:** DEL-6.
  - **4.2:** RAF-18.
- **Not named by any line:**
  - RAF-32's vault clause ("each `PrizeVault` carries the cycle's start, end and full list").
    In substance this is RAF-35's `registerCycle`.
  - RAF-33's vault clauses (released once, only to the winner, within the window). In substance
    these are RAF-36's.
  - OPS-3 on Arbitrum (IC-6).
  - RAF-16's events from 5.2 and 5.3 (`PrizeClaimed`, `Released`, `Withdrawn`). 5.1 names RAF-16
    but builds only `CycleRegistered`, `SignerSet` and `PausedSet`.
  - OPS-7 and DEL-8 are informative.
- **Proposed:**
  - Add RAF-32 and RAF-33 to 5.1–5.3's "with it" lists.
  - Add RAF-16's share to 5.2 and 5.3.
  - Have `check_scenario_quotes.py` print the work-item requirements with no quoting block, as
    information and not as a failure.
  - Correct HANDOVER:134.
- **Owner:** Calea.

**IC-9. `fold_archive.py` exists in ai-stack and was never installed here.**
- `.claude/hooks/mnt-board-reminder.sh:21` and `.claude/commands/mnt/grill.md:59` name
  `docs/tools/spec_tools/fold_archive.py`. CLAUDE.md does not; it says to fold by hand.
- The script is `~/trees/ai-stack/scripts/spec-tools/fold_archive.py` (since 2 October, `e1a1563`),
  and ai-stack's `install.sh` copies it. This repository's tools were installed from `00e8e18` on
  22 September.
- The installed renderer, lint and parsers are identical to ai-stack's. The only differences are
  the missing `fold_archive.py` and `schema_drift.sh`, and in `board.sh` the step that records
  `board-synced-tree` after a write.
  - Without that step the board-reminder hook has no synced tree to compare against.
- **Proposed:**
  - Re-run `~/trees/ai-stack/scripts/spec-tools/install.sh` here. That brings fold_archive,
    schema_drift and the board.sh step.
  - Dry-run `fold_archive.py` on `2026-10-15-raf-prize-vault-claims` to confirm 15 October's
    hand fold matches; it should print no change.
  - Change CLAUDE.md's "fold … by hand" to the script.
  - Neither new building in ai-stack nor dropping the instruction is needed.
- **Owner:** Calea, on the person's word, because it rewrites `docs/tools/`.

### The vault's docs and comments in NFT (fold into 5.x Defects, or one `NONE` docs Task)

**IC-10. NFT's docs and comments describe prizes as paid from the wallet.** Each still reads as
the design:
- `packages/contracts/README.md`:
  - :7 "paid from MINT's wallet";
  - :14–15 "No contract goes on a prize chain";
  - :24 and :29–30 "paid by ordinary transfer; … records each payout";
  - :45 "(the entry points for `MysteryBox` and `PrizeDraw` are still to come)", though they
    exist (`Deploy.s.sol:141`, `:149`);
  - :45–46 Sourcify only (see IC-6, OPS-3).
- `docs/DESIGN.md:126–129`: "Prizes are paid from MINT's prize wallet by ordinary transfer; no
  contract holds one".
- `docs/RUNBOOK.md`:
  - :302–304 "records each paid prize";
  - :316–318 "every paid win a `PrizePaid`";
  - **:332–333 "a win with no `PrizePaid` is a prize still owed"**, which no longer holds after
    the window (MNT-165's forward note);
  - :282–299, cycle setup has no funding, registration or `setSigner`;
  - :276 Sourcify for 42161.
- `packages/contracts-client/README.md`:
  - :245–246 "A win is paid from MINT's prize wallet";
  - :188, generated from `src/errors.ts:285`: `INVALID_PAYOUT` "the transfer's transaction hash".
- In code comments:
  - `contracts-client/src/prizeDraw.ts:11`, `:232`;
  - `examples/10-mystery-box.test.ts:84`;
  - **`contracts/src/PrizeDraw.sol:21–23` and `:378` (NatSpec).**
- **Note:** a NatSpec edit changes `PrizeDraw`'s metadata hash, so the bytecode differs from the
  rehearsal draw verified on 421614. That is harmless before mainnet, but it should be a
  deliberate choice.
- **Proposed:**
  - README, DESIGN, RUNBOOK and the client's text with 5.1–5.6. The RUNBOOK's cycle setup goes
    with 5.4/5.6, and "still owed" with 5.3.
  - The client's comments and error text with 5.6.
  - `PrizeDraw`'s NatSpec now or with 5.2, the person's choice.
  - Before then, at least the README's :45 (entry points exist), which is plain wrong today.
- **Owner:** Calea.

**IC-11. A generator bug in the client's error table** (unrelated to the vault).
- `contracts-client/README.md:201–204`: parameterised messages render with `undefined`, for
  example `SPLIT_MISSING_BEARS` "account for undefined bears but undefined exist at block
  undefined", and likewise `SPLIT_OWNER_MISMATCH`, `SPLIT_GAS_BUDGET` and `UNKNOWN_DEPLOYMENT`.
- The cause is `scripts/error-table.ts`.
- **Proposed:** a DEL-6 Defect. It is small and can ride with MNT-170, which touches the same
  errors, if the person agrees. **Owner:** Calea.

### Tooling

**IC-12. The ai-stack `/mnt:done` template has neither spec check.**
- `templates/work-loop/done.md` has no `check_scenario_quotes.py` and no `check_tree_tests.py`.
  The tree check is project-specific (BTT trees), so the template should name it as an optional
  gate.
- HANDOVER:267 still lists it as not yet in the templates.
- **Proposed:** add both, the tree check marked "when the project keeps `*.tree.md`". **Owner:**
  Calea, in ai-stack.

### Internal docs (here)

**IC-13. CLAUDE.md.**
- :39 and :55: "tranche-1's has only OPS-4 left". `tranche-1/tasks.md` has no unticked line.
- :51: `MysteryBox` base "Solady `Ownable`, `LibBitmap`". It imports `Ownable` only, and `opened`
  is a mapping.
- :59: the box-worker row reads "In Progress until CQ-22" and "`awaitingDecision` pays and records
  nothing". CQ-22 is resolved; the payout step follows the vault (4.2).
- :55 and :148 say "checked in CI" / "run in CI", against :158 "`../NFT` has no CI". NFT's
  `foundry.toml:43` names a `.github/workflows/test.yml` that does not exist.
- :143: the forge-lint notes leave out `test/mocks/MockVRFCoordinator.sol:47,51`, and
  `Deploy.s.sol`'s notes are `mixed-case-variable`, not `-function`.
- The "Architecture" mystery-box paragraph describes the vault correctly as not built.
- **Owner:** Calea.

**IC-14. HANDOVER.md** (besides IC-4 and IC-8):
- :79 "Both contracts stay in the repository, unused": they were removed (MNT-160).
- :90–91 "`compare` is to refuse a CSV over 4,222": it is built (`OverCap`).
- :106 "RAF-33 (custody and the payout record)": custody is RAF-35–37.
- :134–135 test and gate rows cite `3649aad`, with client 104. The current state is `5afada1`,
  client 105.
- :170–176 "still to act on" lists MNT-160 and MNT-161, which are Done.
- :180–187 is a 9 October state under the heading "Next session".
- :276 and :359–360 "RAF-18 … gated by CQ-22"; :373–380 "Integration" names tranche-1 ABIs, a
  voucher backend, and mint and whitelist examples that no longer exist.
- :423–425 "Exclusions are fixed for good before the first cycle" (CQ-20: none).
- Accepted risks:
  - :455–458 leave out the vaults from what the admin key controls;
  - :462–465 "neither contract", where three contracts are named;
  - :502 "records each payout", which should be "each claim".
- :577–579 "O1–O2", "the rehearsal is ready to run", "tranche 2 waits on the excluded ids".
- :344 "CQ-2 by 19 October", where the register has 20 October.
- **Not recorded:** #17 is approved (lcampanis, 15 October 14:14 UTC).
- **Owner:** Calea.

**IC-15. `docs/SPECIFICATION.md`, narrative.**
- §10 is clean: CQ-22 resolved, O1 = CQ-2 by 20 October, matching the register.
- Outside the markers:
  - :24–34 "As of 29 September", the rehearsal "16 October", and the box "in review (#13)";
  - :39–40, the drop's fee recipient "which every mint names", though the client sends no mint;
  - :66–67 "the mint proofs built from it";
  - :70–71, §1.1 omits the vault;
  - :92, :110 and :111, MINT "holding and paying prizes", the prize wallet "holds and pays", and
    the worker with no tickets;
  - :129–136, the §2 contracts table has no `PrizeVault` row, though :121–125 and :151 name it;
  - :144, the admin row omits registering lists;
  - §8 calendar (:1088–1132): the rehearsal on 16 October, no rows for the vault's build,
    rehearsal and deploy, and rows out of date order.
- **Proposed:** edit before the next client document. That is not urgent, because `spec_version`
  stays 2.6 until then. **Owner:** Calea.

**IC-16. `tasks.md` and the board, small.**
- `tranche-2/tasks.md:33` heading "## 4. The worker (RAF-18 gated by CQ-22)" is stale.
- MNT-95's body names `WhitelistClaim` and `DirectBurnAdapter`. It is Open on purpose, for the
  4663 repeat, which MNT-164 item 4 now duplicates.
- **Proposed:** fix the heading. Comment on MNT-95 that its 4663 repeat is MNT-164's item 4, and
  leave Done or Canceled to the person. **Owner:** Calea; the person for MNT-95's state.

**IC-17. MINT's prompts** (`docs/client/MINT-prompt-*.md`), not yet sent.
- Prompt 2:
  - :108 highlights "a win with no payout record". After the window that is a carried-over prize,
    not a debt.
  - :101–103 sets the worker with `setWorker` only; the same address must be each vault's
    `signer`.
- Prompt 1 :10–11 depends on #17 still being open, so re-check it before sending.
- Prompt 3 is clean.
- **Owner:** Calea, before the person sends them.

### Worktrees

**IC-18.**
- `~/trees/NFT-wl-removal` (`mnt/RAF-14`, merged, clean, no stash): removable, or reusable
  for `mnt/DEL-6-170` (IC-1).
- `~/trees/NFT-every-bear` (`feat/contracts`): keep. Its untracked `packages/contracts/broadcast/`
  (`Deploy.s.sol/`, `RehearsalAllowList.s.sol/`) is the only record that `verify.sh 46630` and
  `421614` read.
- `~/trees/NFT` (PR B): keep.
- Stale local branches with no worktree: `feat/contracts-client-workspace-oct7` and the five
  `[gone]` `feat/*` branches.
- **Proposed:** remove nothing until the person says so. **Owner:** the person.

## Verdict

The board, the tasks list and git agree: every tick matches its Task, every accept SHA is its
merge on `feat/contracts`, and nothing private reached NFT. The disagreements are in prose:
- The vault change of 15 October did not reach RAF-27, OPS-1, OPS-4, three register entries,
  NFT's docs and comments, HANDOVER, or the SPECIFICATION narrative.
- `/mnt:done` names a client gate that cannot run.
- The main NFT checkout is not the integration branch that the commands assume.

Nothing blocks MNT-170 except choosing its worktree (IC-1) and the gate's wording (IC-2).
